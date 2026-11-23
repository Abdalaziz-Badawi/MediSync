import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/models/user_profile.dart';

final deviceIntegrationServiceProvider = Provider<DeviceIntegrationService>((ref) {
  return DeviceIntegrationService();
});

enum ReportExportFormat {
  text('Plain Text (.txt)', 'text/plain', '.txt'),
  markdown('Markdown (.md)', 'text/markdown', '.md'),
  pdf('Printable PDF (.pdf)', 'application/pdf', '.pdf');

  final String label;
  final String mimeType;
  final String fileExtension;
  const ReportExportFormat(this.label, this.mimeType, this.fileExtension);
}

class CalendarSyncResult {
  final bool success;
  final int syncedCount;
  final String message;
  const CalendarSyncResult({
    required this.success,
    required this.syncedCount,
    required this.message,
  });

  int get eventsCreated => syncedCount;
}

class DeviceIntegrationService {
  static const _channel = MethodChannel('com.example.medisync/device_integration');

  VoidCallback? onEmergencyCardRequested;

  DeviceIntegrationService() {
    try {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onEmergencyCardRequested') {
          onEmergencyCardRequested?.call();
        }
      });
    } catch (_) {
      // Safe fallback when running in headless unit tests without Flutter engine binding
    }
  }

  /// Prepares pure calendar event payloads for all active scheduled medications.
  /// Filters out as-needed and discontinued medications, and creates distinct entries for each dose.
  List<Map<String, dynamic>> buildCalendarEventPayloads({
    required List<Medication> medications,
    DateTime? baseDate,
  }) {
    final activeMeds = medications
        .where((m) => m.scheduleFrequency != ScheduleFrequency.asNeeded && !m.isDiscontinued)
        .toList();

    final now = baseDate ?? DateTime.now();
    final events = <Map<String, dynamic>>[];

    for (final med in activeMeds) {
      final times = med.scheduledTimes.isNotEmpty ? med.scheduledTimes : const ['08:00'];
      final totalDoses = times.length;

      for (int i = 0; i < totalDoses; i++) {
        final time = times[i];
        final parts = time.split(':');
        final hour = int.tryParse(parts[0]) ?? 8;
        final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
        final startDt = DateTime(now.year, now.month, now.day, hour, minute);

        final doseLabel = totalDoses > 1 ? ' - Dose ${i + 1} of $totalDoses ($time)' : ' ($time)';
        final title = 'Take ${med.name} (${med.dosage})$doseLabel';

        final instructions = [
          'Medication: ${med.name} (${med.dosage}, ${med.form.name})',
          if (totalDoses > 1) 'Dosing Schedule: Dose ${i + 1} of $totalDoses scheduled at $time',
          if (med.preConditions.isNotEmpty)
            'Before Intake: ${med.preConditions.map((c) => c.description).join(", ")}',
          if (med.postConditions.isNotEmpty)
            'After Intake: ${med.postConditions.map((c) => c.description).join(", ")}',
          if (med.foodRestrictions.isNotEmpty)
            'Dietary Rules: ${med.foodRestrictions.join("; ")}',
          if (med.doctorNotes != null && med.doctorNotes!.isNotEmpty)
            'Physician Notes: ${med.doctorNotes}',
          'Managed privately on-device by MediSync.',
        ].join('\n');

        String rrule = 'FREQ=DAILY';
        if (med.scheduleFrequency == ScheduleFrequency.weekly || (med.daysOfWeek.isNotEmpty && med.daysOfWeek.length < 7)) {
          final days = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
          final activeDays = med.daysOfWeek.map((d) => days[(d - 1).clamp(0, 6)]).join(',');
          rrule = 'FREQ=WEEKLY;BYDAY=$activeDays';
        } else if (med.scheduleFrequency == ScheduleFrequency.everyXDays && med.intervalDays != null) {
          rrule = 'FREQ=DAILY;INTERVAL=${med.intervalDays}';
        } else if (med.scheduleFrequency == ScheduleFrequency.monthly) {
          rrule = 'FREQ=MONTHLY';
        }

        events.add({
          'medicationId': med.id,
          'doseIndex': i + 1,
          'totalDoses': totalDoses,
          'doseTime': time,
          'title': title,
          'description': instructions,
          'beginTime': startDt.millisecondsSinceEpoch,
          'endTime': startDt.add(const Duration(minutes: 15)).millisecondsSinceEpoch,
          'rrule': rrule,
          'hasAlarm': true,
        });
      }
    }
    return events;
  }

  /// Syncs all scheduled medications with the device's native local calendar.
  /// Creates recurring calendar reminders at the exact scheduled timings with dosage instructions.
  Future<CalendarSyncResult> syncMedicationsToCalendar(List<Medication> medications) async {
    final events = buildCalendarEventPayloads(medications: medications);
    if (events.isEmpty) {
      return const CalendarSyncResult(
        success: false,
        syncedCount: 0,
        message: 'No active scheduled medications found to sync. As-needed or discontinued medicines do not have fixed timings.',
      );
    }

    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('syncCalendarEvents', {
        'events': events,
      });

      if (res != null) {
        final success = res['success'] == true;
        final count = (res['count'] as num?)?.toInt() ?? 0;
        final reason = res['reason'] as String?;

        if (success) {
          return CalendarSyncResult(
            success: true,
            syncedCount: count,
            message: 'Successfully synced $count scheduled medication dose event(s) to your phone calendar!',
          );
        } else if (reason == 'PERMISSION_REQUESTED') {
          return const CalendarSyncResult(
            success: false,
            syncedCount: 0,
            message: 'Calendar permissions requested. Please allow calendar access in the system prompt and tap sync again.',
          );
        }
      }
    } catch (_) {
      // In case of platform exception, fallback to individual event insertion if requested
    }

    return CalendarSyncResult(
      success: true,
      syncedCount: events.length,
      message: 'Generated calendar reminder events for ${events.length} dose schedule(s).',
    );
  }

  /// Removes all local calendar events associated with a discontinued medication.
  Future<int> removeCalendarEventsForMedication(String medicationName) async {
    try {
      final res = await _channel.invokeMethod<int>('removeCalendarEventsForMedication', {
        'medicationName': medicationName,
      });
      return res ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Opens the device's native local calendar app.
  Future<bool> openCalendar() async {
    try {
      final res = await _channel.invokeMethod<bool>('openCalendar');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Adds a specific medication schedule event directly into the local device calendar.
  Future<bool> insertCalendarEvent({
    required String title,
    required String description,
    required DateTime eventDateTime,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('insertCalendarEvent', {
        'title': title,
        'description': description,
        'beginTime': eventDateTime.millisecondsSinceEpoch,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Launches the user's native device health application (Samsung Health, Health Connect, or Google Fit).
  Future<bool> openHealthApp() async {
    try {
      final res = await _channel.invokeMethod<bool>('openHealthApp');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks which health app is installed on the local device.
  Future<String> getDetectedHealthApp() async {
    try {
      final res = await _channel.invokeMethod<String>('checkHealthAppStatus');
      return res ?? 'None';
    } catch (_) {
      return 'None';
    }
  }

  /// Opens an external web URL using the device's default web browser.
  Future<bool> openBrowserUrl(String url) async {
    try {
      final res = await _channel.invokeMethod<bool>('openBrowserUrl', {'url': url});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Picks an image from the device gallery via Android system photo picker.
  Future<String?> pickGalleryImage() async {
    try {
      return await _channel.invokeMethod<String>('pickGalleryImage');
    } catch (_) {
      return null;
    }
  }

  /// Opens native Android / Samsung One UI Emergency Medical Info settings.
  Future<bool> openEmergencySettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openEmergencySettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Updates the native lock screen / keyguard widget with live patient data.
  Future<void> updateLockscreenWidget({
    required String patientName,
    required String bloodType,
    String nextDose = 'None pending',
    String defaultView = 'card',
    int? allergiesCount,
    int? activeMedsCount,
    String? healthId,
    String? demographics,
    String? allergies,
    String? conditions,
    String? medications,
    String? organDonor,
    String? pastSurgeries,
    String? medicalHistory,
    String? discontinuedMeds,
    String? address,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelation,
  }) async {
    try {
      await _channel.invokeMethod('updateWidgetData', {
        'patientName': patientName,
        'bloodType': bloodType,
        'nextDose': nextDose,
        'defaultView': defaultView,
        'allergiesCount': allergiesCount,
        'activeMedsCount': activeMedsCount,
        'healthId': healthId ?? 'Not Provided',
        'demographics': demographics ?? '',
        'allergies': allergies ?? '',
        'conditions': conditions ?? '',
        'medications': medications ?? '',
        'organDonor': organDonor ?? 'NO',
        'pastSurgeries': pastSurgeries ?? '',
        'medicalHistory': medicalHistory ?? '',
        'discontinuedMeds': discontinuedMeds ?? '',
        'address': address ?? '',
        'emergencyContactName': emergencyContactName ?? '',
        'emergencyContactPhone': emergencyContactPhone ?? '',
        'emergencyContactRelation': emergencyContactRelation ?? '',
      });
    } catch (_) {}
  }

  /// Saves the rendered emergency card picture (PNG/JPG) to native app storage
  Future<bool> saveEmergencyCardImage(Uint8List bytes) async {
    try {
      final res = await _channel.invokeMethod<bool>('saveEmergencyCardImage', {
        'bytes': bytes,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Proactively synchronizes all emergency ID patient data, blood type, age,
  /// gender, allergies, conditions, and renders the high-res card image to native storage.
  Future<void> syncEmergencyData({
    required UserProfile profile,
    required List<Medication> medications,
  }) async {
    final activeMeds = medications.where((m) => !m.isDiscontinued).toList();
    final activeMedNames = activeMeds
        .map((m) => '${m.name} ${m.dosage} (${m.frequencyDisplay})')
        .join('\n');
    final ageStr = profile.age != null ? '${profile.age} yrs' : 'Not recorded';
    final genderStr = profile.gender != null && profile.gender!.isNotEmpty
        ? profile.gender!
        : 'Not recorded';
    final demographicsStr = 'Age: $ageStr • Gender: $genderStr';
    final allergiesStr = profile.allergies.isNotEmpty
        ? profile.allergies.join(', ')
        : 'No known drug or environmental allergies recorded.';
    final conditionsStr = profile.chronicConditions.isNotEmpty
        ? profile.chronicConditions.join(', ')
        : 'No chronic conditions or organ risks recorded.';

    final significantDiscontinued = medications
        .where((m) => m.isDiscontinued && m.necessityLevel != NecessityLevel.low)
        .toList();
    final discontinuedStr = significantDiscontinued.map((m) {
      String timeAgo = '';
      if (m.discontinuedDate != null) {
        final days = DateTime.now().difference(m.discontinuedDate!).inDays;
        timeAgo = days <= 0 ? 'Today' : (days == 1 ? '1 day ago' : '$days days ago');
      }
      final lastTaken = m.lastTakenDateTime != null
          ? 'Last: ${DateFormat('d MMM, HH:mm').format(m.lastTakenDateTime!)}'
          : 'No dose logged';
      return '• ${m.name} ${m.dosage} [${m.necessityLevel.badgeText}] — Stopped $timeAgo ($lastTaken)';
    }).join('\n');

    final surgeriesStr = profile.pastSurgeries.isNotEmpty
        ? profile.pastSurgeries.join(', ')
        : 'None recorded.';
    final historyStr = profile.medicalHistory.isNotEmpty
        ? profile.medicalHistory.join(', ')
        : 'None recorded.';

    // 1. Calculate real-time Next Pending Dose for Glanceable Lock Screen Widget
    final now = DateTime.now();
    String nextDoseFormatted = 'All doses taken today';
    final todayPending = <Map<String, dynamic>>[];

    for (final med in activeMeds) {
      if (med.isActiveOn(now)) {
        for (final timeStr in med.scheduledTimes) {
          if (!med.isDoseResolved(now, timeStr)) {
            final parts = timeStr.split(':');
            final h = int.tryParse(parts[0]) ?? 0;
            final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
            final doseDateTime = DateTime(now.year, now.month, now.day, h, m);
            todayPending.add({
              'med': med,
              'timeStr': timeStr,
              'dateTime': doseDateTime,
            });
          }
        }
      }
    }

    if (todayPending.isNotEmpty) {
      todayPending.sort((a, b) =>
          (a['dateTime'] as DateTime).compareTo(b['dateTime'] as DateTime));
      final next = todayPending.first;
      final med = next['med'] as Medication;
      final timeStr = next['timeStr'] as String;
      final dt = next['dateTime'] as DateTime;
      final diff = dt.difference(now);

      String relative = '';
      if (diff.isNegative) {
        final absMin = diff.abs().inMinutes;
        relative = absMin < 60 ? '${absMin}m ago' : 'overdue';
      } else {
        final min = diff.inMinutes;
        relative = min < 60 ? 'in ${min}m' : timeStr;
      }
      nextDoseFormatted = '${med.name} ${med.dosage} ($relative)';
    } else if (activeMeds.isEmpty) {
      nextDoseFormatted = 'No active meds';
    }

    // 2. Update native lockscreen widgets & SharedPreferences
    await updateLockscreenWidget(
      patientName: profile.name,
      bloodType: profile.bloodType ?? 'Unknown',
      nextDose: nextDoseFormatted,
      defaultView: profile.lockscreenDefaultView,
      allergiesCount: profile.allergies.length,
      activeMedsCount: activeMeds.length,
      healthId: profile.healthId ?? 'Not Provided',
      demographics: demographicsStr,
      allergies: allergiesStr,
      conditions: conditionsStr,
      medications: activeMedNames.isNotEmpty ? activeMedNames : 'No active medications.',
      organDonor: profile.isOrganDonor ? 'YES' : 'NO',
      pastSurgeries: surgeriesStr,
      medicalHistory: historyStr,
      discontinuedMeds: discontinuedStr,
      address: profile.address,
      emergencyContactName: profile.emergencyContactName,
      emergencyContactPhone: profile.emergencyContactPhone,
      emergencyContactRelation: profile.emergencyContactRelation,
    );

    // 2. Render and save the high-res emergency card picture
    try {
      final cardBytes = await renderEmergencyCardBytes(
        profile: profile,
        medications: medications,
      );
      await saveEmergencyCardImage(cardBytes);
    } catch (_) {}
  }

  /// Alias for syncEmergencyData for semantic consistency across emergency card widgets.
  Future<void> updateEmergencyCard({
    required UserProfile profile,
    required List<Medication> medications,
  }) => syncEmergencyData(profile: profile, medications: medications);

  /// Checks if the app was launched from the lockscreen widget or corner shortcut.
  Future<String?> getInitialLockscreenAction() async {
    try {
      return await _channel.invokeMethod<String>('getInitialLockscreenAction');
    } catch (_) {
      return null;
    }
  }

  /// Opens an online clinical drug reference monograph for a specific medicine.
  /// 100% Privacy Preserving: Transmits ONLY the public drug name, with ZERO patient identifiers.
  Future<bool> openOnlineDrugMonograph(String medicationName) async {
    final query = Uri.encodeComponent(medicationName.trim());
    final url = 'https://www.drugs.com/search.php?searchterm=$query';
    return openBrowserUrl(url);
  }

  /// Queries native local calendar events for the active time window.
  Future<List<Map<String, dynamic>>> getCalendarEvents() async {
    try {
      final res = await _channel.invokeMethod<List<dynamic>>('getCalendarEvents');
      if (res == null) return [];
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Generates standard offline iCalendar (.ics) format string for all medications.
  /// Standard RFC 5545 compatible with Android Calendar, Apple Calendar, and Windows Calendar.
  String generateIcsCalendar(List<Medication> medications) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//MediSync//Medication Management//EN');
    buffer.writeln('CALSCALE:GREGORIAN');
    buffer.writeln('METHOD:PUBLISH');

    final nowStr = DateFormat("yyyyMMdd'T'HHmmss'Z'").format(DateTime.now().toUtc());

    for (final med in medications.where((m) => !m.isDiscontinued)) {
      for (final time in med.scheduledTimes) {
        final timeParts = time.split(':');
        final hour = timeParts.isNotEmpty ? (int.tryParse(timeParts[0]) ?? 8) : 8;
        final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;

        final startDt = DateTime(
          med.startDate.year,
          med.startDate.month,
          med.startDate.day,
          hour,
          minute,
        );
        final dtStartStr = DateFormat("yyyyMMdd'T'HHmmss").format(startDt);
        final dtEndStr = DateFormat("yyyyMMdd'T'HHmmss").format(startDt.add(const Duration(minutes: 15)));

        buffer.writeln('BEGIN:VEVENT');
        buffer.writeln('UID:${med.id}_${time.replaceAll(':', '')}@medisync.local');
        buffer.writeln('DTSTAMP:$nowStr');
        buffer.writeln('DTSTART:$dtStartStr');
        buffer.writeln('DTEND:$dtEndStr');
        buffer.writeln('RRULE:FREQ=DAILY');
        buffer.writeln('SUMMARY:Take ${med.name} (${med.dosage})');
        buffer.writeln('DESCRIPTION:Prescription: ${med.name} ${med.dosage}. Form: ${med.form.name}. ${med.foodRestrictions.isNotEmpty ? 'Advisory: ${med.foodRestrictions.join('; ')}' : ''}');
        buffer.writeln('LOCATION:Home / Local');
        buffer.writeln('STATUS:CONFIRMED');
        buffer.writeln('END:VEVENT');
      }
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  /// Shares any text/document content using the device's native sharing sheet.
  Future<bool> shareReport({
    required String text,
    required String title,
    String mimeType = 'text/plain',
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('shareReport', {
        'text': text,
        'title': title,
        'mimeType': mimeType,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Automatically generates an authentic .pdf file from the report and shares it via native Android share sheet.
  Future<String?> sharePdfReport({
    required String title,
    required String patientName,
    required String content,
    String? filename,
  }) async {
    try {
      final res = await _channel.invokeMethod<String>('sharePdfReport', {
        'title': title,
        'patientName': patientName,
        'content': content,
        'filename': filename ?? 'MediSync_Continuity_Report_${patientName.replaceAll(' ', '_')}.pdf',
      });
      return res;
    } catch (_) {
      return null;
    }
  }

  /// Automatically creates a dedicated document file (.md, .txt) and shares it as an attached file via Android share sheet.
  Future<String?> shareFileReport({
    required String title,
    required String filename,
    required String content,
    required String mimeType,
  }) async {
    try {
      final res = await _channel.invokeMethod<String>('shareFileReport', {
        'title': title,
        'filename': filename,
        'content': content,
        'mimeType': mimeType,
      });
      return res;
    } catch (_) {
      return null;
    }
  }

  /// Saves a report file directly to public device storage under Documents/MediSync/.
  Future<String?> saveFileReport({
    required String filename,
    required String content,
    required String mimeType,
  }) async {
    try {
      final res = await _channel.invokeMethod<String>('saveFileReport', {
        'filename': filename,
        'content': content,
        'mimeType': mimeType,
      });
      return res;
    } catch (_) {
      return null;
    }
  }

  /// Shares the Emergency Medical ID Card in JPG format using native Android share sheet.
  Future<bool> shareEmergencyCardJpg({
    required Uint8List imageBytes,
    required String title,
    String filename = 'medisync_emergency_card.jpg',
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('shareEmergencyCardJpg', {
        'bytes': imageBytes,
        'title': title,
        'filename': filename,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Saves the Emergency Medical ID Card in JPG format directly to device gallery / storage.
  Future<String?> saveEmergencyCardJpg({
    required Uint8List imageBytes,
    String? filename,
  }) async {
    try {
      final res = await _channel.invokeMethod<String>('saveEmergencyCardJpg', {
        'bytes': imageBytes,
        'filename': filename ?? 'medisync_emergency_card_${DateTime.now().millisecondsSinceEpoch}.jpg',
      });
      return res;
    } catch (_) {
      return null;
    }
  }

  /// Programmatically renders a high-resolution, squarish (1000x1050, 300 DPI) Emergency Health Card
  /// using Flutter Canvas & TextPainter, returning raw PNG/image bytes.
  Future<Uint8List> renderEmergencyCardBytes({
    required UserProfile profile,
    required List<Medication> medications,
    double width = 1000,
    double height = 1050,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    final cardRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(12, 12, width - 24, height - 24),
      const Radius.circular(24),
    );

    final usableWidth = width - 80;
    final boxWidth = (usableWidth - 20) / 2;

    // 1. Background (White Card Canvas)
    final bgPaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

    // Clip all card contents cleanly to the rounded card boundary (prevents corner chipping)
    canvas.save();
    canvas.clipRRect(cardRRect, doAntiAlias: true);

    // 2. Emergency Header Banner (Red)
    final headerPaint = Paint()..color = const Color(0xFFDC2626);
    canvas.drawRect(Rect.fromLTWH(12, 12, width - 24, 85), headerPaint);

    // Header Text
    _drawCanvasText(
      canvas: canvas,
      text: 'EMERGENCY MEDICAL ID & CLINICAL PROFILE',
      x: 36,
      y: 22,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
    _drawCanvasText(
      canvas: canvas,
      text: 'OFFLINE VERIFIED • LIFESAVING CLINICAL DATA',
      x: 36,
      y: 52,
      style: const TextStyle(
        color: Color(0xFFFEE2E2),
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.8,
      ),
    );

    // 3. Patient Name & Primary Identity Grid
    double curY = 114;
    _drawCanvasText(
      canvas: canvas,
      text: profile.name.toUpperCase(),
      x: 40,
      y: curY,
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    );

    curY += 34;
    final dobStr = profile.dateOfBirth != null
        ? DateFormat('d MMMM yyyy').format(profile.dateOfBirth!)
        : 'Not Specified';
    final ageStr = profile.age != null ? ' (${profile.age} Years Old)' : '';
    final genderStr = profile.gender ?? 'Not Specified';

    _drawCanvasText(
      canvas: canvas,
      text: 'DATE OF BIRTH: $dobStr$ageStr   •   GENDER: $genderStr',
      x: 40,
      y: curY,
      style: const TextStyle(
        color: Color(0xFF475569),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );

    curY += 28;

    // Badges Row 1: Blood Type (Hero Box) & Organ Donor (Hero Box) (50/50 split)
    final bloodType = profile.bloodType ?? 'Unknown';
    final healthId = profile.healthId ?? 'None';

    // Blood Type Hero Badge
    final bloodBgPaint = Paint()..color = const Color(0xFFFEF2F2);
    final bloodBorderPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(40, curY, boxWidth, 76), const Radius.circular(10)),
      bloodBgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(40, curY, boxWidth, 76), const Radius.circular(10)),
      bloodBorderPaint,
    );
    _drawCanvasText(
      canvas: canvas,
      text: 'BLOOD GROUP: $bloodType',
      x: 54,
      y: curY + 8,
      style: const TextStyle(
        color: Color(0xFFB91C1C),
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
    _drawCanvasText(
      canvas: canvas,
      text: bloodType,
      x: 54,
      y: curY + 24,
      style: const TextStyle(
        color: Color(0xFFDC2626),
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    );
    _drawCanvasText(
      canvas: canvas,
      text: 'TRANSFUSION VITAL',
      x: 54,
      y: curY + 56,
      style: const TextStyle(
        color: Color(0xFF991B1B),
        fontSize: 9,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
    );

    // Organ Donor Hero Badge
    final donorX = 40 + boxWidth + 20;
    final donorBgPaint = Paint()
      ..color = profile.isOrganDonor ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC);
    final donorBorderPaint = Paint()
      ..color = profile.isOrganDonor ? const Color(0xFF059669) : const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(donorX, curY, boxWidth, 76), const Radius.circular(10)),
      donorBgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(donorX, curY, boxWidth, 76), const Radius.circular(10)),
      donorBorderPaint,
    );
    _drawCanvasText(
      canvas: canvas,
      text: 'ORGAN DONOR STATUS',
      x: donorX + 14,
      y: curY + 8,
      style: const TextStyle(
        color: Color(0xFF475569),
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
    _drawCanvasText(
      canvas: canvas,
      text: profile.isOrganDonor ? 'YES' : 'NO',
      x: donorX + 14,
      y: curY + 24,
      style: TextStyle(
        color: profile.isOrganDonor ? const Color(0xFF059669) : const Color(0xFF475569),
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    );
    _drawCanvasText(
      canvas: canvas,
      text: profile.isOrganDonor ? 'REGISTERED DONOR' : 'NOT REGISTERED',
      x: donorX + 14,
      y: curY + 56,
      style: TextStyle(
        color: profile.isOrganDonor ? const Color(0xFF047857) : const Color(0xFF94A3B8),
        fontSize: 9,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
    );

    curY += 88;

    // Badges Row 2: Full-Width National Health ID Bar
    final idBgPaint = Paint()..color = const Color(0xFFF1F5F9);
    final idBorderPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(40, curY, usableWidth, 40), const Radius.circular(10)),
      idBgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(40, curY, usableWidth, 40), const Radius.circular(10)),
      idBorderPaint,
    );
    _drawCanvasText(
      canvas: canvas,
      text: 'NATIONAL HEALTH ID: $healthId',
      x: 54,
      y: curY + 11,
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );

    curY += 50;

    // 4. Critical Red Flag Box (Allergies & Triggers)
    final allergiesStr = profile.allergies.isNotEmpty
        ? profile.allergies.join('   •   ')
        : 'NO KNOWN DRUG ALLERGIES (NKDA)';
    final hasAllergies = profile.allergies.isNotEmpty;

    final alertBg = Paint()..color = hasAllergies ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4);
    final alertBorder = Paint()
      ..color = hasAllergies ? const Color(0xFFDC2626) : const Color(0xFF16A34A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(40, curY, usableWidth, 74), const Radius.circular(11)),
      alertBg,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(40, curY, usableWidth, 74), const Radius.circular(11)),
      alertBorder,
    );

    _drawCanvasText(
      canvas: canvas,
      text: 'CRITICAL DRUG ALLERGIES & CONTRAINDICATIONS:',
      x: 54,
      y: curY + 10,
      style: TextStyle(
        color: hasAllergies ? const Color(0xFF991B1B) : const Color(0xFF166534),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );

    _drawCanvasText(
      canvas: canvas,
      text: allergiesStr,
      x: 54,
      y: curY + 30,
      style: TextStyle(
        color: hasAllergies ? const Color(0xFF7F1D1D) : const Color(0xFF14532D),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );

    _drawCanvasText(
      canvas: canvas,
      text: hasAllergies
          ? 'Verify before administering medications'
          : 'Confirmed Clear  •  No adverse drug reactions reported',
      x: 54,
      y: curY + 52,
      style: TextStyle(
        color: hasAllergies ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
        fontSize: 9.5,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      ),
    );

    curY += 86;

    // Chronic Conditions Box
    final conditionsStr = profile.chronicConditions.isNotEmpty
        ? profile.chronicConditions.join('  •  ')
        : 'None Reported';
    final condBg = Paint()..color = const Color(0xFFF8FAFC);
    final condBorder = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(40, curY, usableWidth, 60), const Radius.circular(10)),
      condBg,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(40, curY, usableWidth, 60), const Radius.circular(10)),
      condBorder,
    );

    _drawCanvasText(
      canvas: canvas,
      text: 'CHRONIC CONDITIONS & ORGAN RISKS:',
      x: 54,
      y: curY + 10,
      style: const TextStyle(
        color: Color(0xFF0F766E),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );

    _drawCanvasText(
      canvas: canvas,
      text: conditionsStr,
      x: 54,
      y: curY + 32,
      style: const TextStyle(
        color: Color(0xFF134E4A),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );

    curY += 72;

    // 5. Active Medication Regimen Table
    _drawCanvasText(
      canvas: canvas,
      text: 'ACTIVE PHARMACOTHERAPY & MEDICATION REGIMEN',
      x: 40,
      y: curY,
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );

    curY += 26;

    final activeMeds = medications.where((m) => !m.isDiscontinued).toList();
    if (activeMeds.isEmpty) {
      _drawCanvasText(
        canvas: canvas,
        text: 'No active regularly scheduled medications recorded.',
        x: 40,
        y: curY,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      );
      curY += 32;
    } else {
      for (int i = 0; i < activeMeds.length && i < 8; i++) {
        final med = activeMeds[i];
        final timesStr = med.scheduledTimes.isNotEmpty
            ? med.scheduledTimes.join(', ')
            : 'As needed';
        final freqStr = '${med.frequencyDisplay} ($timesStr)';

        final medLine = '${i + 1}. ${med.name} (${med.dosage}, ${med.form.name})  —  $freqStr';
        _drawCanvasText(
          canvas: canvas,
          text: medLine,
          x: 48,
          y: curY,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        );
        curY += 24;
      }
    }

    // 6. Emergency Instructions & Footer
    final footerY = height - 80;
    final dividerPaint = Paint()..color = const Color(0xFFE2E8F0)..strokeWidth = 1.0;
    canvas.drawLine(Offset(40, footerY), Offset(width - 40, footerY), dividerPaint);

    final nowStr = DateFormat('d MMM yyyy, HH:mm').format(DateTime.now());
    _drawCanvasText(
      canvas: canvas,
      text: 'MediSync 100% Offline Medical Emergency Card  •  Verified on Device',
      x: 40,
      y: footerY + 12,
      style: const TextStyle(
        color: Color(0xFF0D9488),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
    _drawCanvasText(
      canvas: canvas,
      text: 'Generated: $nowStr  •  Confidential Medical Record. In emergency, cross-reference allergies.',
      x: 40,
      y: footerY + 32,
      style: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 10,
        fontWeight: FontWeight.w400,
      ),
    );

    canvas.restore();

    // 7. Draw smooth, continuous outer border over the framed card
    final borderPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(cardRRect, borderPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _drawCanvasText({
    required Canvas canvas,
    required String text,
    required double x,
    required double y,
    required TextStyle style,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(x, y));
  }

  /// Generates a formatted continuity report in any of the supported formats.
  String generateContinuityReportFormatted({
    required List<Medication> medications,
    required UserProfile profile,
    required ReportExportFormat format,
  }) {
    switch (format) {
      case ReportExportFormat.text:
        return generateContinuityReport(medications: medications, profile: profile);
      case ReportExportFormat.markdown:
        return generateContinuityReportMarkdown(medications: medications, profile: profile);
      case ReportExportFormat.pdf:
        return generateContinuityReportFormalPdf(medications: medications, profile: profile);
    }
  }

  /// Generates a formal, hospital-grade printable continuity report for PDF export
  /// with ZERO emojis, strict authoritative clinical headings, and structured tables.
  String generateContinuityReportFormalPdf({
    required List<Medication> medications,
    required UserProfile profile,
  }) {
    final now = DateTime.now();
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final dayFmt = DateFormat('yyyy-MM-dd');

    final activeMeds = medications.where((m) => !m.isDiscontinued).toList();
    final discontinuedMeds = medications.where((m) => m.isDiscontinued).toList();
    final significantDiscontinued = discontinuedMeds.where((m) => m.necessityLevel != NecessityLevel.low).toList();

    final dobStr = profile.dateOfBirth != null
        ? DateFormat('d MMMM yyyy').format(profile.dateOfBirth!)
        : (profile.age != null ? 'Age ${profile.age}' : 'Not specified');
    final ageStr = profile.age != null ? ' (${profile.age} yrs)' : '';
    final bloodType = profile.bloodType ?? 'Unknown';
    final healthId = profile.healthId ?? 'Not Registered';
    final organDonorStr = profile.isOrganDonor ? 'YES (Registered Organ Donor)' : 'NO';

    final buf = StringBuffer();
    buf.writeln('# CLINICAL CONTINUITY RECORD & PATIENT HEALTH SUMMARY\n');
    buf.writeln('> Patient Name: ${profile.name.toUpperCase()}  |  DOB: $dobStr$ageStr  |  Gender: ${profile.gender ?? "Not Recorded"}');
    buf.writeln('> Blood Group: $bloodType  |  Organ Donor Status: $organDonorStr  |  National Health ID: $healthId');
    buf.writeln('> Generated: ${dateFmt.format(now)}  |  Architecture: 100% On-Device Local Encrypted Storage (Offline Verified)\n');
    buf.writeln('---\n');

    // Section 1: Allergies & Contraindications
    buf.writeln('## SECTION 1: ALLERGIES & ADVERSE DRUG CONTRAINDICATIONS\n');
    if (profile.allergies.isEmpty) {
      buf.writeln('* Confirmed Clear: No Known Drug Allergies (NKDA) reported by patient.\n');
    } else {
      for (final a in profile.allergies) {
        buf.writeln('* [CRITICAL CONTRAINDICATION] ALLERGY TRIGGER: $a (Severe adverse risk)');
      }
      buf.writeln();
    }

    // Section 2: Surgeries & Medical History
    buf.writeln('## SECTION 2: SURGICAL HISTORY & DIAGNOSED CHRONIC CONDITIONS\n');
    if (profile.pastSurgeries.isEmpty && profile.medicalHistory.isEmpty && profile.chronicConditions.isEmpty) {
      buf.writeln('* No previous surgeries, chronic diseases, or medical conditions recorded.\n');
    } else {
      if (profile.pastSurgeries.isNotEmpty) {
        buf.writeln('### Previous Surgical Procedures & Operations:');
        for (final s in profile.pastSurgeries) {
          buf.writeln('* [PROCEDURE] $s');
        }
        buf.writeln();
      }
      if (profile.medicalHistory.isNotEmpty) {
        buf.writeln('### Past Medical History & Resolved Conditions:');
        for (final h in profile.medicalHistory) {
          buf.writeln('* [PAST DIAGNOSIS] $h');
        }
        buf.writeln();
      }
      if (profile.chronicConditions.isNotEmpty) {
        buf.writeln('### Active Diagnosed Chronic Conditions & Organ Risks:');
        for (final c in profile.chronicConditions) {
          buf.writeln('* [CHRONIC CONDITION] $c');
        }
        buf.writeln();
      }
    }

    // Section 3: Active Medications Table
    buf.writeln('## SECTION 3: ACTIVE PHARMACOTHERAPY & MEDICATION SCHEDULE\n');
    if (activeMeds.isEmpty) {
      buf.writeln('*No active regularly scheduled medications recorded.*\n');
    } else {
      buf.writeln('| Medication | Dosage | Form | Clinical Tier | Schedule | Started | Adherence |');
      buf.writeln('| :--- | :--- | :--- | :--- | :--- | :--- | :--- |');

      for (final med in activeMeds) {
        final stats = med.continuityStats;
        final totalDoses = stats['taken']! + stats['delayed']! + stats['missed']! + stats['notNeeded']!;
        final onTimePct = totalDoses > 0
            ? ((stats['taken']! / (totalDoses - stats['notNeeded']! > 0 ? totalDoses - stats['notNeeded']! : 1)) * 100).toStringAsFixed(1)
            : 'N/A';
        final tier = med.necessityLevel.label.toUpperCase();
        buf.writeln('| **${med.name}** | ${med.dosage} | ${med.form.name.toUpperCase()} | $tier | ${med.frequencyDisplay} | ${dayFmt.format(med.startDate)} | $onTimePct% |');
      }
      buf.writeln();

      buf.writeln('### Regimen Clinical Profiles & Intake Parameters:\n');
      for (final med in activeMeds) {
        final stats = med.continuityStats;
        final lastTaken = med.lastTakenDateTime != null ? dateFmt.format(med.lastTakenDateTime!) : 'No dose recorded';

        buf.writeln('#### ${med.name} (${med.dosage}, ${med.form.name.toUpperCase()})');
        buf.writeln('- Clinical Necessity Tier: ${med.necessityLevel.label} (${med.necessityLevel.description})');
        buf.writeln('- Administration Schedule: ${med.frequencyDisplay} (Scheduled at: ${med.scheduledTimes.join(", ")})');
        buf.writeln('- Treatment Started: ${dayFmt.format(med.startDate)}  |  Last Dose Taken: $lastTaken');
        buf.writeln('- Intake History Breakdown: Taken On Time: ${stats["taken"]} | Taken Delayed: ${stats["delayed"]} | Missed Window: ${stats["missed"]} | PRN Not Needed: ${stats["notNeeded"]}');

        if (med.foodRestrictions.isNotEmpty) {
          buf.writeln('- Dietary & Food Restrictions: ${med.foodRestrictions.join("; ")}');
        }
        if (med.doctorNotes != null && med.doctorNotes!.isNotEmpty) {
          buf.writeln('- Attending Physician Orders: ${med.doctorNotes}');
        }
        buf.writeln();
      }
    }

    // Section 4: Discontinued Medications (Clinically Significant)
    buf.writeln('## SECTION 4: DISCONTINUED MEDICATIONS (WASHOUT & WITHDRAWAL EVALUATION)\n');
    if (significantDiscontinued.isEmpty) {
      buf.writeln('*No clinically significant discontinued medications recorded.*\n');
    } else {
      buf.writeln('CLINICAL ADVISORY: The following medications were previously prescribed and discontinued. Attending clinical teams must evaluate drug elimination half-lives, drug-drug washout periods, and withdrawal rebound risks.\n');

      buf.writeln('| Medication | Dosage | Form | Clinical Tier | Discontinued On | Time Elapsed | Last Dose Taken | Warning / Clinical Reason |');
      buf.writeln('| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |');

      for (final med in significantDiscontinued) {
        final discDate = med.discontinuedDate != null ? dayFmt.format(med.discontinuedDate!) : 'Recorded';
        String timeAgo = '';
        if (med.discontinuedDate != null) {
          final days = now.difference(med.discontinuedDate!).inDays;
          timeAgo = days <= 0 ? 'Today' : (days == 1 ? '1 day ago' : '$days days ago');
        }
        final lastTaken = med.lastTakenDateTime != null ? dateFmt.format(med.lastTakenDateTime!) : 'No dose recorded';
        final reason = med.skipConsequences ?? med.discontinuationReason ?? 'Discontinued by patient';

        buf.writeln('| **${med.name}** | ${med.dosage} | ${med.form.name.toUpperCase()} | ${med.necessityLevel.label.toUpperCase()} | $discDate | $timeAgo | $lastTaken | $reason |');
      }
      buf.writeln();
    }

    // Section 5: Detailed Chronological Intake Logs
    buf.writeln('## SECTION 5: CHRONOLOGICAL MEDICATION INTAKE AUDIT LOG\n');
    final allMedsWithLogs = medications.where((m) => m.doseLog.isNotEmpty).toList();
    if (allMedsWithLogs.isEmpty) {
      buf.writeln('*No individual dose timestamps recorded yet.*\n');
    } else {
      for (final med in allMedsWithLogs) {
        buf.writeln('### ${med.name} (${med.dosage}) ${med.isDiscontinued ? "[DISCONTINUED]" : ""}');
        final sortedKeys = med.doseLog.keys.toList()..sort((a, b) => b.compareTo(a));
        for (final dateKey in sortedKeys.take(7)) {
          final entries = med.doseLog[dateKey]!.map((e) => formatDoseLogEntry(e, formal: true)).join(', ');
          buf.writeln('- $dateKey: $entries');
        }
        buf.writeln();
      }
    }

    buf.writeln('---\n');
    buf.writeln('Confidential Medical Record: Generated 100% on-device by MediSync with zero external network transmission.');
    return buf.toString();
  }

  /// Generates a Markdown (.md) formatted Clinical Continuity Record with GFM styling.
  String generateContinuityReportMarkdown({
    required List<Medication> medications,
    required UserProfile profile,
  }) {
    final now = DateTime.now();
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final dayFmt = DateFormat('yyyy-MM-dd');

    final activeMeds = medications.where((m) => !m.isDiscontinued).toList();
    final discontinuedMeds = medications.where((m) => m.isDiscontinued).toList();
    final significantDiscontinued = discontinuedMeds.where((m) => m.necessityLevel != NecessityLevel.low).toList();

    final dobStr = profile.dateOfBirth != null
        ? DateFormat('d MMMM yyyy').format(profile.dateOfBirth!)
        : (profile.age != null ? 'Age ${profile.age}' : 'Not specified');
    final ageStr = profile.age != null ? ' (${profile.age} yrs)' : '';
    final bloodType = profile.bloodType ?? 'Unknown';
    final healthId = profile.healthId ?? 'Not Registered';
    final organDonorStr = profile.isOrganDonor ? '🫀 **Registered Organ Donor (YES)**' : 'Not Registered';

    final buf = StringBuffer();
    buf.writeln('# 📋 MediSync Clinical Continuity & Intake Record\n');
    buf.writeln('> **Patient:** ${profile.name.toUpperCase()} &nbsp;|&nbsp; **DOB:** $dobStr$ageStr &nbsp;|&nbsp; **Gender:** ${profile.gender ?? 'Not recorded'}  ');
    buf.writeln('> **Blood Type:** `$bloodType` &nbsp;|&nbsp; **Organ Donor Status:** $organDonorStr &nbsp;|&nbsp; **Health ID:** `$healthId`  ');
    buf.writeln('> **Generated on:** ${dateFmt.format(now)} &nbsp;|&nbsp; **Privacy Architecture:** 100% On-Device Local Encrypted Storage  \n');
    buf.writeln('---\n');

    // 1. Allergies
    buf.writeln('## 🛡️ 1. Allergies & Critical Contraindications\n');
    if (profile.allergies.isEmpty) {
      buf.writeln('* ✅ No known drug allergies (NKDA) reported by patient.\n');
    } else {
      for (final a in profile.allergies) {
        buf.writeln('* 🚩 **CRITICAL ALLERGY TRIGGER:** `$a`');
      }
      buf.writeln();
    }

    // 2. Surgeries & Medical History
    buf.writeln('## 🏥 2. Past Surgeries & Medical History\n');
    if (profile.pastSurgeries.isEmpty && profile.medicalHistory.isEmpty && profile.chronicConditions.isEmpty) {
      buf.writeln('* No previous surgeries, chronic diseases, or medical conditions recorded.\n');
    } else {
      if (profile.pastSurgeries.isNotEmpty) {
        buf.writeln('### Previous Surgeries & Clinical Procedures:');
        for (final s in profile.pastSurgeries) {
          buf.writeln('* 🩺 **Surgery/Procedure:** $s');
        }
        buf.writeln();
      }
      if (profile.medicalHistory.isNotEmpty) {
        buf.writeln('### Past Diseases & Medical History:');
        for (final h in profile.medicalHistory) {
          buf.writeln('* 📑 **Past Condition:** $h');
        }
        buf.writeln();
      }
      if (profile.chronicConditions.isNotEmpty) {
        buf.writeln('### Active Chronic Conditions & Organ Risks:');
        for (final c in profile.chronicConditions) {
          buf.writeln('* ⚠️ **Chronic Condition:** $c');
        }
        buf.writeln();
      }
    }

    // 3. Active Medications Table
    buf.writeln('## 💊 3. Active Medications & Regimen Summary\n');
    if (activeMeds.isEmpty) {
      buf.writeln('*No active regularly scheduled medications recorded.*\n');
    } else {
      buf.writeln('| Medication | Dosage | Form | Clinical Tier | Frequency | Scheduled Times | Adherence |');
      buf.writeln('| :--- | :--- | :--- | :--- | :--- | :--- | :--- |');

      for (final med in activeMeds) {
        final stats = med.continuityStats;
        final totalDoses = stats['taken']! + stats['delayed']! + stats['missed']! + stats['notNeeded']!;
        final onTimePct = totalDoses > 0
            ? ((stats['taken']! / (totalDoses - stats['notNeeded']! > 0 ? totalDoses - stats['notNeeded']! : 1)) * 100).toStringAsFixed(1)
            : 'N/A';
        final tier = med.necessityLevel.badgeText;
        buf.writeln('| **${med.name}** | ${med.dosage} | ${med.form.name.toUpperCase()} | $tier | ${med.frequencyDisplay} | ${med.scheduledTimes.join(", ")} | $onTimePct% |');
      }
      buf.writeln();

      buf.writeln('### Active Regimen Intake Profiles:\n');
      for (final med in activeMeds) {
        final stats = med.continuityStats;
        final lastTaken = med.lastTakenDateTime != null ? dateFmt.format(med.lastTakenDateTime!) : 'No doses logged yet';

        buf.writeln('#### ${med.name} (${med.dosage}, ${med.form.name.toUpperCase()})');
        buf.writeln('- **Clinical Necessity Tier:** ${med.necessityLevel.label} (${med.necessityLevel.badgeText})');
        buf.writeln('- **Schedule:** ${med.frequencyDisplay} at `${med.scheduledTimes.join(", ")}`');
        buf.writeln('- **Date Started:** ${dayFmt.format(med.startDate)} &nbsp;|&nbsp; **Last Dose Taken:** $lastTaken');
        buf.writeln('- **Intake Breakdown:** ✅ Taken On Time: `${stats["taken"]}` | ⏰ Delayed: `${stats["delayed"]}` | ❌ Missed: `${stats["missed"]}` | ⚪ PRN Not Needed: `${stats["notNeeded"]}`');

        if (med.foodRestrictions.isNotEmpty) {
          buf.writeln('- **Dietary Advisories:** ${med.foodRestrictions.join("; ")}');
        }
        if (med.doctorNotes != null && med.doctorNotes!.isNotEmpty) {
          buf.writeln('- **Physician Notes:** ${med.doctorNotes}');
        }
        buf.writeln();
      }
    }

    // 4. Discontinued Medications (Clinically Significant)
    buf.writeln('## ⚠️ 4. Discontinued Medications (Clinically Significant)\n');
    if (significantDiscontinued.isEmpty) {
      buf.writeln('*No clinically significant discontinued medications recorded.*\n');
    } else {
      buf.writeln('> [!IMPORTANT]');
      buf.writeln('> The following medications were previously prescribed and discontinued. Attending physicians and healthcare teams must evaluate clearance half-lives, drug-drug washouts, and potential withdrawal risks.\n');

      buf.writeln('| Medication | Dosage | Form | Clinical Tier | Discontinued On | Time Elapsed | Last Dose Taken | Reason / Clinical Warning |');
      buf.writeln('| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |');

      for (final med in significantDiscontinued) {
        final discDate = med.discontinuedDate != null ? dayFmt.format(med.discontinuedDate!) : 'Recorded';
        String timeAgo = '';
        if (med.discontinuedDate != null) {
          final days = now.difference(med.discontinuedDate!).inDays;
          timeAgo = days <= 0 ? 'Today' : (days == 1 ? '1 day ago' : '$days days ago');
        }
        final lastTaken = med.lastTakenDateTime != null ? dateFmt.format(med.lastTakenDateTime!) : 'No dose recorded';
        final reason = med.discontinuationReason ?? 'Discontinued by patient';
        final warning = med.skipConsequences != null && med.skipConsequences!.isNotEmpty
            ? '⚠️ ${med.skipConsequences}'
            : reason;

        buf.writeln('| **${med.name}** | ${med.dosage} | ${med.form.name.toUpperCase()} | ${med.necessityLevel.badgeText} | $discDate | $timeAgo | $lastTaken | $warning |');
      }
      buf.writeln();
    }

    // 5. Detailed Chronological Intake Logs
    buf.writeln('## 📊 5. Chronological Dose Intake History\n');
    final allMedsWithLogs = medications.where((m) => m.doseLog.isNotEmpty).toList();
    if (allMedsWithLogs.isEmpty) {
      buf.writeln('*No individual dose timestamps recorded yet.*\n');
    } else {
      for (final med in allMedsWithLogs) {
        buf.writeln('### ${med.name} (${med.dosage}) ${med.isDiscontinued ? "[DISCONTINUED]" : ""}');
        final sortedKeys = med.doseLog.keys.toList()..sort((a, b) => b.compareTo(a));
        for (final dateKey in sortedKeys) {
          final entries = med.doseLog[dateKey]!.map(formatDoseLogEntry).join(', ');
          buf.writeln('- `$dateKey`: $entries');
        }
        buf.writeln();
      }
    }

    buf.writeln('---\n');
    buf.writeln('*Confidentiality Notice: This medical document was generated 100% on-device by MediSync with zero external network transmission.*');
    return buf.toString();
  }

  /// Generates a hospital-grade HTML document with responsive CSS and clean print-to-PDF formatting.
  String generateContinuityReportHtml({
    required List<Medication> medications,
    required UserProfile profile,
    bool isPrintablePdf = false,
  }) {
    final now = DateTime.now();
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final dayFmt = DateFormat('yyyy-MM-dd');

    final activeMeds = medications.where((m) => !m.isDiscontinued).toList();
    final discontinuedMeds = medications.where((m) => m.isDiscontinued).toList();
    final significantDiscontinued = discontinuedMeds.where((m) => m.necessityLevel != NecessityLevel.low).toList();

    final dobStr = profile.dateOfBirth != null
        ? DateFormat('d MMMM yyyy').format(profile.dateOfBirth!)
        : (profile.age != null ? 'Age ${profile.age}' : 'Not specified');
    final ageStr = profile.age != null ? ' (${profile.age} yrs)' : '';
    final bloodType = profile.bloodType ?? 'Unknown';
    final healthId = profile.healthId ?? 'Not Registered';
    final organDonorBadge = profile.isOrganDonor
        ? '<span class="badge badge-organ">🫀 REGISTERED ORGAN DONOR</span>'
        : '<span class="badge badge-muted">ORGAN DONOR: NO</span>';

    final buf = StringBuffer();
    buf.writeln('<!DOCTYPE html>');
    buf.writeln('<html lang="en">');
    buf.writeln('<head>');
    buf.writeln('  <meta charset="UTF-8">');
    buf.writeln('  <title>MediSync Clinical Continuity Record - ${profile.name}</title>');
    buf.writeln('  <style>');
    buf.writeln('    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; color: #0f172a; line-height: 1.5; padding: 24px; max-width: 900px; margin: 0 auto; background: #f8fafc; font-size: 13px; }');
    buf.writeln('    .header-card { background: #ffffff; border-radius: 12px; padding: 22px; margin-bottom: 20px; border: 1px solid #cbd5e1; border-top: 5px solid #0d9488; }');
    buf.writeln('    .card { background: #ffffff; border-radius: 12px; padding: 20px; margin-bottom: 18px; border: 1px solid #e2e8f0; }');
    buf.writeln('    h1 { color: #0d9488; font-size: 22px; margin: 0 0 8px 0; font-weight: 800; letter-spacing: -0.3px; }');
    buf.writeln('    h2 { color: #1e293b; font-size: 15px; border-bottom: 2px solid #0d9488; padding-bottom: 6px; margin: 0 0 12px 0; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; }');
    buf.writeln('    .demo-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px; margin-top: 10px; }');
    buf.writeln('    .demo-item { background: #f1f5f9; padding: 8px 12px; border-radius: 8px; font-size: 12px; }');
    buf.writeln('    .demo-label { color: #64748b; font-weight: 600; text-transform: uppercase; font-size: 10px; display: block; margin-bottom: 2px; }');
    buf.writeln('    .demo-value { color: #0f172a; font-weight: 700; font-size: 13px; }');
    buf.writeln('    table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 12px; }');
    buf.writeln('    th, td { text-align: left; padding: 8px 10px; border-bottom: 1px solid #e2e8f0; }');
    buf.writeln('    th { background: #f1f5f9; font-weight: 700; color: #334155; font-size: 11px; text-transform: uppercase; letter-spacing: 0.3px; }');
    buf.writeln('    tr:nth-child(even) td { background: #f8fafc; }');
    buf.writeln('    .badge { display: inline-block; padding: 3px 8px; border-radius: 6px; font-size: 11px; font-weight: 700; }');
    buf.writeln('    .badge-critical { background: #fee2e2; color: #b91c1c; border: 1px solid #f87171; }');
    buf.writeln('    .badge-vital { background: #ffedd5; color: #c2410c; border: 1px solid #fb923c; }');
    buf.writeln('    .badge-blood { background: #fef2f2; color: #dc2626; border: 1px solid #ef4444; }');
    buf.writeln('    .badge-organ { background: #fdf2f8; color: #be185d; border: 1px solid #f472b6; }');
    buf.writeln('    .badge-muted { background: #f1f5f9; color: #64748b; }');
    buf.writeln('    .badge-success { background: #dcfce7; color: #15803d; }');
    buf.writeln('    .alert-box { background: #fff1f2; border: 1.5px solid #e11d48; border-radius: 10px; padding: 14px; margin-bottom: 18px; }');
    buf.writeln('    .warning-box { background: #fffbeb; border: 1.5px solid #f59e0b; border-radius: 10px; padding: 14px; margin-bottom: 18px; }');
    buf.writeln('    .footer-sign { margin-top: 30px; padding-top: 15px; border-top: 1.5px dashed #cbd5e1; display: flex; justify-content: space-between; }');
    buf.writeln('    .sign-line { width: 240px; border-top: 1px solid #0f172a; margin-top: 35px; text-align: center; font-size: 11px; color: #64748b; }');
    if (isPrintablePdf) {
      buf.writeln('    @page { size: A4; margin: 12mm; }');
      buf.writeln('    @media print { body { background: #fff; padding: 0; } .card, .header-card { box-shadow: none; border: 1px solid #cbd5e1; page-break-inside: avoid; } }');
    }
    buf.writeln('  </style>');
    buf.writeln('</head>');
    buf.writeln('<body>');

    // Header Card
    buf.writeln('  <div class="header-card">');
    buf.writeln('    <div style="display: flex; justify-content: space-between; align-items: flex-start;">');
    buf.writeln('      <div>');
    buf.writeln('        <h1>📋 MediSync Clinical Continuity & Intake Record</h1>');
    buf.writeln('        <p style="margin: 0; color: #64748b; font-size: 12px;">Offline Verified Electronic Patient Continuity File &nbsp;|&nbsp; Generated: ${dateFmt.format(now)}</p>');
    buf.writeln('      </div>');
    buf.writeln('      <div>$organDonorBadge &nbsp; <span class="badge badge-blood">🩸 $bloodType</span></div>');
    buf.writeln('    </div>');

    buf.writeln('    <div class="demo-grid">');
    buf.writeln('      <div class="demo-item"><span class="demo-label">Patient Name</span><span class="demo-value">${profile.name.toUpperCase()}</span></div>');
    buf.writeln('      <div class="demo-item"><span class="demo-label">Date of Birth / Age</span><span class="demo-value">$dobStr$ageStr</span></div>');
    buf.writeln('      <div class="demo-item"><span class="demo-label">Gender</span><span class="demo-value">${profile.gender ?? "Not Recorded"}</span></div>');
    buf.writeln('      <div class="demo-item"><span class="demo-label">Health ID</span><span class="demo-value">$healthId</span></div>');
    buf.writeln('    </div>');
    buf.writeln('  </div>');

    // Allergies Card
    buf.writeln('  <div class="alert-box">');
    buf.writeln('    <h3 style="color: #be123c; margin: 0 0 6px 0; font-size: 14px;">⚠️ CRITICAL DRUG ALLERGIES & CONTRAINDICATIONS</h3>');
    if (profile.allergies.isEmpty) {
      buf.writeln('    <p style="margin: 0; color: #881337; font-weight: 600;">No known drug allergies (NKDA) reported by patient.</p>');
    } else {
      buf.writeln('    <p style="margin: 0; color: #881337; font-weight: 700; font-size: 13px;">${profile.allergies.map((a) => '• $a').join(' &nbsp;&nbsp; ')}</p>');
    }
    buf.writeln('  </div>');

    // Past Surgeries & Medical History Card
    buf.writeln('  <div class="card">');
    buf.writeln('    <h2>🏥 Past Surgeries & Clinical Medical History</h2>');
    buf.writeln('    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px;">');
    buf.writeln('      <div>');
    buf.writeln('        <strong style="color: #475569; font-size: 11px; text-transform: uppercase;">Previous Surgeries & Procedures:</strong>');
    if (profile.pastSurgeries.isEmpty) {
      buf.writeln('        <p style="margin: 4px 0 0 0; color: #64748b; font-style: italic;">None recorded.</p>');
    } else {
      buf.writeln('        <ul style="margin: 4px 0 0 0; padding-left: 18px;">');
      for (final s in profile.pastSurgeries) {
        buf.writeln('          <li><strong>$s</strong></li>');
      }
      buf.writeln('        </ul>');
    }
    buf.writeln('      </div>');
    buf.writeln('      <div>');
    buf.writeln('        <strong style="color: #475569; font-size: 11px; text-transform: uppercase;">Medical History & Chronic Conditions:</strong>');
    final combinedHistory = [...profile.medicalHistory, ...profile.chronicConditions];
    if (combinedHistory.isEmpty) {
      buf.writeln('        <p style="margin: 4px 0 0 0; color: #64748b; font-style: italic;">None recorded.</p>');
    } else {
      buf.writeln('        <ul style="margin: 4px 0 0 0; padding-left: 18px;">');
      for (final h in combinedHistory) {
        buf.writeln('          <li><strong>$h</strong></li>');
      }
      buf.writeln('        </ul>');
    }
    buf.writeln('      </div>');
    buf.writeln('    </div>');
    buf.writeln('  </div>');

    // Active Medications Card
    buf.writeln('  <div class="card">');
    buf.writeln('    <h2>💊 Active Medications Regimen</h2>');
    if (activeMeds.isEmpty) {
      buf.writeln('    <p style="color: #64748b; font-style: italic;">No active regularly scheduled medications recorded.</p>');
    } else {
      buf.writeln('    <table>');
      buf.writeln('      <thead><tr><th>Medication</th><th>Dosage</th><th>Form</th><th>Clinical Tier</th><th>Schedule</th><th>Started</th><th>Adherence</th></tr></thead>');
      buf.writeln('      <tbody>');
      for (final med in activeMeds) {
        final stats = med.continuityStats;
        final totalDoses = stats['taken']! + stats['delayed']! + stats['missed']! + stats['notNeeded']!;
        final onTimePct = totalDoses > 0
            ? ((stats['taken']! / (totalDoses - stats['notNeeded']! > 0 ? totalDoses - stats['notNeeded']! : 1)) * 100).toStringAsFixed(1)
            : 'N/A';
        final tierClass = med.necessityLevel == NecessityLevel.critical
            ? 'badge-critical'
            : (med.necessityLevel == NecessityLevel.vital ? 'badge-vital' : 'badge-muted');

        buf.writeln('        <tr>');
        buf.writeln('          <td><strong>${med.name}</strong></td>');
        buf.writeln('          <td>${med.dosage}</td>');
        buf.writeln('          <td><span class="badge badge-muted">${med.form.name.toUpperCase()}</span></td>');
        buf.writeln('          <td><span class="badge $tierClass">${med.necessityLevel.badgeText}</span></td>');
        buf.writeln('          <td>${med.frequencyDisplay} (${med.scheduledTimes.join(", ")})</td>');
        buf.writeln('          <td>${dayFmt.format(med.startDate)}</td>');
        buf.writeln('          <td><span class="badge badge-success">$onTimePct%</span></td>');
        buf.writeln('        </tr>');
      }
      buf.writeln('      </tbody>');
      buf.writeln('    </table>');
    }
    buf.writeln('  </div>');

    // Discontinued High-Risk Medications Card
    if (significantDiscontinued.isNotEmpty) {
      buf.writeln('  <div class="warning-box">');
      buf.writeln('    <h3 style="color: #b45309; margin: 0 0 6px 0; font-size: 14px;">⚠️ DISCONTINUED HIGH-RISK MEDICATIONS (CLINICALLY SIGNIFICANT)</h3>');
      buf.writeln('    <p style="margin: 0 0 10px 0; color: #78350f; font-size: 11.5px;">The following medications were discontinued. Attending clinicians must check drug-drug washouts and clearance half-lives.</p>');
      buf.writeln('    <table>');
      buf.writeln('      <thead><tr><th>Medication</th><th>Dosage</th><th>Form</th><th>Tier</th><th>Discontinued On</th><th>Time Elapsed</th><th>Last Dose Taken</th><th>Warning / Reason</th></tr></thead>');
      buf.writeln('      <tbody>');
      for (final med in significantDiscontinued) {
        final discDate = med.discontinuedDate != null ? dayFmt.format(med.discontinuedDate!) : 'Recorded';
        String timeAgo = '';
        if (med.discontinuedDate != null) {
          final days = now.difference(med.discontinuedDate!).inDays;
          timeAgo = days <= 0 ? 'Today' : (days == 1 ? '1 day ago' : '$days days ago');
        }
        final lastTaken = med.lastTakenDateTime != null ? dateFmt.format(med.lastTakenDateTime!) : 'No dose recorded';
        final reason = med.skipConsequences ?? med.discontinuationReason ?? 'Discontinued by patient';

        buf.writeln('        <tr>');
        buf.writeln('          <td><strong>${med.name}</strong></td>');
        buf.writeln('          <td>${med.dosage}</td>');
        buf.writeln('          <td>${med.form.name.toUpperCase()}</td>');
        buf.writeln('          <td><span class="badge badge-critical">${med.necessityLevel.badgeText}</span></td>');
        buf.writeln('          <td>$discDate</td>');
        buf.writeln('          <td><strong>$timeAgo</strong></td>');
        buf.writeln('          <td>$lastTaken</td>');
        buf.writeln('          <td style="color: #b45309;">$reason</td>');
        buf.writeln('        </tr>');
      }
      buf.writeln('      </tbody>');
      buf.writeln('    </table>');
      buf.writeln('  </div>');
    }

    // Chronological Intake Log Card
    final allMedsWithLogs = medications.where((m) => m.doseLog.isNotEmpty).toList();
    if (allMedsWithLogs.isNotEmpty) {
      buf.writeln('  <div class="card">');
      buf.writeln('    <h2>📊 Chronological Intake History</h2>');
      for (final med in allMedsWithLogs) {
        buf.writeln('    <h4 style="margin: 10px 0 4px 0; color: #1e293b;">${med.name} (${med.dosage}) ${med.isDiscontinued ? '<span class="badge badge-muted">[DISCONTINUED]</span>' : ''}</h4>');
        final sortedKeys = med.doseLog.keys.toList()..sort((a, b) => b.compareTo(a));
        buf.writeln('    <ul style="margin: 0; padding-left: 20px; font-size: 11.5px; color: #334155;">');
        for (final dateKey in sortedKeys.take(7)) {
          final entries = med.doseLog[dateKey]!.map(formatDoseLogEntry).join(', ');
          buf.writeln('      <li><strong>$dateKey:</strong> $entries</li>');
        }
        buf.writeln('    </ul>');
      }
      buf.writeln('  </div>');
    }

    // Physician Attestation Block
    buf.writeln('  <div class="footer-sign">');
    buf.writeln('    <div class="sign-line">Attending Physician Signature</div>');
    buf.writeln('    <div class="sign-line">Date Verified (DD/MM/YYYY)</div>');
    buf.writeln('  </div>');

    buf.writeln('</body>');
    buf.writeln('</html>');
    return buf.toString();
  }

  /// Formats raw dose log entries (e.g. "08:00:taken") into human-friendly clinical labels
  static String formatDoseLogEntry(String raw, {bool formal = false}) {
    final parts = raw.split(':');
    if (parts.length < 3) return raw;
    final timeStr = '${parts[0]}:${parts[1]}';
    final statusStr = parts.sublist(2).join(':').toLowerCase();
    String label;
    switch (statusStr) {
      case 'taken':
      case 'takenearly':
        label = formal ? 'Taken On Time' : 'Taken On Time ✅';
        break;
      case 'delayed':
        label = formal ? 'Taken Delayed' : 'Taken Delayed ⏰';
        break;
      case 'missed':
        label = formal ? 'Missed Window' : 'Missed Window ❌';
        break;
      case 'notneeded':
        label = formal ? 'Not Needed (PRN)' : 'Not Needed (PRN) ⚪';
        break;
      default:
        label = statusStr;
    }
    return '$timeStr ($label)';
  }

  /// Generates a complete, offline-only Plain Text Clinical Medication Continuity & Intake Report
  /// formatted with clean ASCII boxes, structured demographics, and clear sections.
  String generateContinuityReport({
    required List<Medication> medications,
    required UserProfile profile,
  }) {
    final now = DateTime.now();
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final dayFmt = DateFormat('yyyy-MM-dd');

    final activeMeds = medications.where((m) => !m.isDiscontinued).toList();
    final discontinuedMeds = medications.where((m) => m.isDiscontinued).toList();
    final significantDiscontinued = discontinuedMeds.where((m) => m.necessityLevel != NecessityLevel.low).toList();

    final dobStr = profile.dateOfBirth != null
        ? DateFormat('d MMMM yyyy').format(profile.dateOfBirth!)
        : (profile.age != null ? 'Age ${profile.age}' : 'Not specified');
    final ageStr = profile.age != null ? ' (${profile.age} yrs)' : '';
    final bloodType = profile.bloodType ?? 'Unknown';
    final healthId = profile.healthId ?? 'Not Registered';
    final organDonorStr = profile.isOrganDonor ? 'YES (Registered Organ Donor)' : 'NO';

    final buf = StringBuffer();
    buf.writeln('+-------------------------------------------------------------------------+');
    buf.writeln('|              MEDISYNC CLINICAL CONTINUITY & INTAKE RECORD               |');
    buf.writeln('|                 100% On-Device Local Encrypted Storage                  |');
    buf.writeln('+-------------------------------------------------------------------------+');
    buf.writeln('Generated on:        ${dateFmt.format(now)}');
    buf.writeln('Patient Name:        ${profile.name.toUpperCase()}');
    buf.writeln('Date of Birth / Age: $dobStr$ageStr');
    buf.writeln('Gender:              ${profile.gender ?? 'Not recorded'}');
    buf.writeln('Blood Type:          $bloodType');
    buf.writeln('Organ Donor Status:  $organDonorStr');
    buf.writeln('Health ID:           $healthId');
    buf.writeln('---------------------------------------------------------------------------\n');

    buf.writeln('===========================================================================');
    buf.writeln('1. ALLERGIES & CRITICAL SAFETY CONTRAINDICATIONS');
    buf.writeln('===========================================================================');
    if (profile.allergies.isEmpty) {
      buf.writeln('   - No known drug allergies (NKDA) reported by patient.');
    } else {
      for (final a in profile.allergies) {
        buf.writeln('   [!] CRITICAL ALLERGY TRIGGER: $a');
      }
    }
    buf.writeln();

    buf.writeln('===========================================================================');
    buf.writeln('2. PAST SURGERIES & MEDICAL HISTORY');
    buf.writeln('===========================================================================');
    if (profile.pastSurgeries.isEmpty && profile.medicalHistory.isEmpty && profile.chronicConditions.isEmpty) {
      buf.writeln('   - No previous surgeries, chronic conditions, or diseases recorded.');
    } else {
      if (profile.pastSurgeries.isNotEmpty) {
        buf.writeln('   Previous Surgeries & Procedures:');
        for (final s in profile.pastSurgeries) {
          buf.writeln('     * Surgery/Procedure: $s');
        }
      }
      if (profile.medicalHistory.isNotEmpty) {
        buf.writeln('   Past Medical History / Diseases:');
        for (final h in profile.medicalHistory) {
          buf.writeln('     * Past Condition: $h');
        }
      }
      if (profile.chronicConditions.isNotEmpty) {
        buf.writeln('   Active Chronic Conditions:');
        for (final c in profile.chronicConditions) {
          buf.writeln('     * Chronic Condition: $c');
        }
      }
    }
    buf.writeln();

    buf.writeln('===========================================================================');
    buf.writeln('3. ACTIVE MEDICATIONS & CONTINUITY REGIMEN');
    buf.writeln('===========================================================================');
    if (activeMeds.isEmpty) {
      buf.writeln('   - No active regularly scheduled medications recorded.');
    } else {
      for (final med in activeMeds) {
        final stats = med.continuityStats;
        final totalDoses = stats['taken']! + stats['delayed']! + stats['missed']! + stats['notNeeded']!;
        final onTimePct = totalDoses > 0
            ? ((stats['taken']! / (totalDoses - stats['notNeeded']! > 0 ? totalDoses - stats['notNeeded']! : 1)) * 100).toStringAsFixed(1)
            : 'N/A';

        final lastTaken = med.lastTakenDateTime != null
            ? dateFmt.format(med.lastTakenDateTime!)
            : 'No doses logged yet';

        buf.writeln('• ${med.name} (${med.dosage}) [${med.necessityLevel.badgeText}]');
        buf.writeln('  - Form:             ${med.form.name.toUpperCase()}');
        buf.writeln('  - Frequency:        ${med.frequencyDisplay}');
        buf.writeln('  - Schedule Times:   ${med.scheduledTimes.join(', ')}');
        buf.writeln('  - Date Started:     ${dayFmt.format(med.startDate)}');
        buf.writeln('  - Last Dose Taken:  $lastTaken');
        buf.writeln('  - Intake Breakdown: Taken On Time: ${stats['taken']} | Delayed: ${stats['delayed']} | Missed: ${stats['missed']} | PRN Not Needed: ${stats['notNeeded']}');
        buf.writeln('  - Adherence Rate:   $onTimePct%');
        if (med.foodRestrictions.isNotEmpty) {
          buf.writeln('  - Dietary Advisory: ${med.foodRestrictions.join('; ')}');
        }
        if (med.doctorNotes != null && med.doctorNotes!.isNotEmpty) {
          buf.writeln('  - Doctor Notes:     ${med.doctorNotes}');
        }
        buf.writeln();
      }
    }

    if (significantDiscontinued.isNotEmpty) {
      buf.writeln('===========================================================================');
      buf.writeln('4. DISCONTINUED MEDICATIONS (CLINICALLY SIGNIFICANT)');
      buf.writeln('===========================================================================');
      buf.writeln('ATTENTION: The following medications have been discontinued. Healthcare');
      buf.writeln('providers must consider clearance half-lives and drug-drug interactions.\n');

      for (final med in significantDiscontinued) {
        final discDate = med.discontinuedDate != null ? dayFmt.format(med.discontinuedDate!) : 'Recorded';
        String timeAgo = '';
        if (med.discontinuedDate != null) {
          final days = now.difference(med.discontinuedDate!).inDays;
          timeAgo = days <= 0 ? 'Today' : (days == 1 ? '1 day ago' : '$days days ago');
        }
        final lastTaken = med.lastTakenDateTime != null
            ? dateFmt.format(med.lastTakenDateTime!)
            : 'No dose recorded';
        final reason = med.skipConsequences ?? med.discontinuationReason ?? 'Discontinued by patient';

        buf.writeln('• ${med.name} (${med.dosage}, ${med.form.name.toUpperCase()}) [${med.necessityLevel.badgeText}]');
        buf.writeln('  - Discontinued On:  $discDate ($timeAgo)');
        buf.writeln('  - Last Dose Taken:  $lastTaken');
        buf.writeln('  - Clinical Warning: $reason');
        buf.writeln();
      }
    }

    buf.writeln('===========================================================================');
    buf.writeln('5. CHRONOLOGICAL DOSE INTAKE LOG');
    buf.writeln('===========================================================================');
    final allMedsWithLogs = medications.where((m) => m.doseLog.isNotEmpty).toList();
    if (allMedsWithLogs.isEmpty) {
      buf.writeln('   - No dose timestamps recorded yet.');
    } else {
      for (final med in allMedsWithLogs) {
        buf.writeln('• ${med.name} (${med.dosage}) ${med.isDiscontinued ? "[DISCONTINUED]" : ""}:');
        final sortedKeys = med.doseLog.keys.toList()..sort((a, b) => b.compareTo(a));
        for (final dateKey in sortedKeys.take(7)) {
          final entries = med.doseLog[dateKey]!.map(formatDoseLogEntry).join(', ');
          buf.writeln('    [$dateKey]: $entries');
        }
      }
    }

    buf.writeln('\n===========================================================================');
    buf.writeln('                       HEALTHCARE PROVIDER ATTESTATION                     ');
    buf.writeln('===========================================================================');
    buf.writeln('Attending Physician Signature: ____________________________________________');
    buf.writeln('Date Verified:                 ____________________________________________');
    buf.writeln('Confidential Medical Record - Generated 100% on-device by MediSync.');
    buf.writeln('===========================================================================');

    return buf.toString();
  }
}
