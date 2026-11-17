import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/models/user_profile.dart';

final deviceIntegrationServiceProvider = Provider<DeviceIntegrationService>((ref) {
  return DeviceIntegrationService();
});

class DeviceIntegrationService {
  static const _channel = MethodChannel('com.example.medisync/device_integration');

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

    for (final med in medications) {
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

  /// Generates a complete, offline-only Clinical Medication Continuity & Intake Report.
  /// Strictly requires user permission & call to action before generation.
  String generateContinuityReport({
    required List<Medication> medications,
    required UserProfile profile,
  }) {
    final now = DateTime.now();
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final dayFmt = DateFormat('yyyy-MM-dd');

    final buf = StringBuffer();
    buf.writeln('================================================================');
    buf.writeln('           MEDISYNC CLINICAL CONTINUITY & INTAKE RECORD         ');
    buf.writeln('================================================================');
    buf.writeln('Generated on: ${dateFmt.format(now)}');
    buf.writeln('Patient Identifier: ${profile.name}');
    buf.writeln('Storage Architecture: 100% On-Device Local Encrypted Storage');
    buf.writeln('Privacy Consent: Authorized by patient on-device');
    buf.writeln('----------------------------------------------------------------\n');

    buf.writeln('1. ALLERGIES & CLINICAL SAFETY TRIGGERS:');
    if (profile.allergies.isEmpty) {
      buf.writeln('   - No known drug allergies (NKDA) reported.');
    } else {
      for (final a in profile.allergies) {
        buf.writeln('   - [ALLERGY]: $a');
      }
    }
    buf.writeln('\n----------------------------------------------------------------');
    buf.writeln('2. ACTIVE MEDICATIONS & CONTINUITY SUMMARY:');
    buf.writeln('----------------------------------------------------------------');

    for (final med in medications) {
      final stats = med.continuityStats;
      final totalDoses = stats['taken']! + stats['delayed']! + stats['missed']! + stats['notNeeded']!;
      final onTimePct = totalDoses > 0
          ? ((stats['taken']! / (totalDoses - stats['notNeeded']! > 0 ? totalDoses - stats['notNeeded']! : 1)) * 100).toStringAsFixed(1)
          : 'N/A';

      final lastTaken = med.lastTakenDateTime != null
          ? dateFmt.format(med.lastTakenDateTime!)
          : 'No doses logged yet';

      buf.writeln('\n• Medication: ${med.name} (${med.dosage})');
      buf.writeln('  Form: ${med.form.name.toUpperCase()}');
      buf.writeln('  Frequency: ${med.scheduleFrequency.name}');
      buf.writeln('  Schedule Times: ${med.scheduledTimes.join(', ')}');
      buf.writeln('  Date Started: ${dayFmt.format(med.startDate)}');
      buf.writeln('  Last Dose Taken: $lastTaken');
      buf.writeln('  Intake Stats:');
      buf.writeln('    - Taken On Time: ${stats['taken']}');
      buf.writeln('    - Taken Delayed: ${stats['delayed']}');
      buf.writeln('    - Missed Window: ${stats['missed']}');
      buf.writeln('    - Skipped / Not Needed: ${stats['notNeeded']}');
      buf.writeln('    - Adherence Rate: $onTimePct%');
      if (med.foodRestrictions.isNotEmpty) {
        buf.writeln('  Dietary Advisories:');
        for (final r in med.foodRestrictions) {
          buf.writeln('    * $r');
        }
      }

      // Chronological Log entries for this medication
      if (med.doseLog.isNotEmpty) {
        buf.writeln('  Chronological Intake Log:');
        final sortedKeys = med.doseLog.keys.toList()..sort((a, b) => b.compareTo(a));
        for (final dateKey in sortedKeys) {
          final entries = med.doseLog[dateKey]!;
          buf.writeln('    [$dateKey]: ${entries.join(', ')}');
        }
      }
    }

    buf.writeln('\n================================================================');
    buf.writeln('                    CONFIDENTIALITY NOTICE                      ');
    buf.writeln('================================================================');
    buf.writeln('This medical continuity record was produced strictly within the');
    buf.writeln('isolated sandbox of MediSync on this device. No network requests,');
    buf.writeln('cloud backups, or third-party tracking have been executed.');
    buf.writeln('================================================================');

    return buf.toString();
  }
}
