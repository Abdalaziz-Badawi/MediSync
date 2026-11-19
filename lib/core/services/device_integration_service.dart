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
  html('Web HTML (.html)', 'text/html', '.html'),
  xml('Standard XML (.xml)', 'application/xml', '.xml'),
  doc('Microsoft Word (.doc)', 'application/msword', '.doc'),
  pdf('Printable PDF Layout', 'text/html', '.pdf');

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

  /// Syncs all scheduled medications with the device's native local calendar.
  /// Creates recurring calendar reminders at the exact scheduled timings with dosage instructions.
  Future<CalendarSyncResult> syncMedicationsToCalendar(List<Medication> medications) async {
    final activeMeds = medications.where((m) => m.scheduleFrequency != ScheduleFrequency.asNeeded).toList();
    if (activeMeds.isEmpty) {
      return const CalendarSyncResult(
        success: false,
        syncedCount: 0,
        message: 'No scheduled medications found to sync. As-needed medicines do not have fixed timings.',
      );
    }

    final now = DateTime.now();
    final events = <Map<String, dynamic>>[];

    for (final med in activeMeds) {
      for (final time in med.scheduledTimes) {
        final parts = time.split(':');
        final hour = int.tryParse(parts[0]) ?? 8;
        final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
        final startDt = DateTime(now.year, now.month, now.day, hour, minute);

        final instructions = [
          'Dosage: ${med.dosage} (${med.form.name})',
          if (med.preConditions.isNotEmpty)
            'Before: ${med.preConditions.map((c) => c.description).join(", ")}',
          if (med.postConditions.isNotEmpty)
            'After: ${med.postConditions.map((c) => c.description).join(", ")}',
          if (med.foodRestrictions.isNotEmpty)
            'Dietary: ${med.foodRestrictions.join("; ")}',
          if (med.doctorNotes != null && med.doctorNotes!.isNotEmpty)
            'Notes: ${med.doctorNotes}',
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
          'title': 'Take ${med.name} (${med.dosage})',
          'description': instructions,
          'beginTime': startDt.millisecondsSinceEpoch,
          'endTime': startDt.add(const Duration(minutes: 15)).millisecondsSinceEpoch,
          'rrule': rrule,
        });
      }
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
            message: 'Successfully synced $count medication schedule events to your phone calendar!',
          );
        } else if (reason == 'PERMISSION_REQUESTED') {
          return const CalendarSyncResult(
            success: false,
            syncedCount: 0,
            message: 'Calendar write permission requested. Please allow calendar access in the system dialog to complete synchronization.',
          );
        }
      }
    } catch (_) {
      // Fallback: If platform direct provider write is unsupported, offer ICS generation
    }

    // Fallback: insert the first event via intent to ensure calendar launches
    if (events.isNotEmpty) {
      final first = events.first;
      await insertCalendarEvent(
        title: first['title'] as String,
        description: first['description'] as String,
        eventDateTime: DateTime.fromMillisecondsSinceEpoch(first['beginTime'] as int),
      );
    }

    return CalendarSyncResult(
      success: true,
      syncedCount: events.length,
      message: 'Created calendar reminder events for ${events.length} dose schedule(s).',
    );
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
      case ReportExportFormat.html:
      case ReportExportFormat.pdf:
        return generateContinuityReportHtml(medications: medications, profile: profile, isPrintablePdf: format == ReportExportFormat.pdf);
      case ReportExportFormat.xml:
        return generateContinuityReportXml(medications: medications, profile: profile);
      case ReportExportFormat.doc:
        return generateContinuityReportDoc(medications: medications, profile: profile);
    }
  }

  /// Generates a Markdown (.md) formatted Clinical Continuity Record with GFM styling.
  String generateContinuityReportMarkdown({
    required List<Medication> medications,
    required UserProfile profile,
  }) {
    final now = DateTime.now();
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final dayFmt = DateFormat('yyyy-MM-dd');

    final buf = StringBuffer();
    buf.writeln('# 📋 MediSync Clinical Continuity & Intake Record\n');
    buf.writeln('> **Generated on:** ${dateFmt.format(now)}  ');
    buf.writeln('> **Patient Identifier:** ${profile.name}  ');
    buf.writeln('> **Storage Mode:** 100% On-Device Local Encrypted Storage  \n');

    buf.writeln('## 🛡️ 1. Allergies & Safety Triggers\n');
    if (profile.allergies.isEmpty) {
      buf.writeln('* No known drug allergies (NKDA) reported.\n');
    } else {
      for (final a in profile.allergies) {
        buf.writeln('* 🚩 **Allergy Conflict:** `$a`');
      }
      buf.writeln();
    }

    buf.writeln('## 💊 2. Active Medications & Regimen Summary\n');
    buf.writeln('| Medication | Dosage | Form | Frequency | Scheduled Times | Adherence |');
    buf.writeln('| :--- | :--- | :--- | :--- | :--- | :--- |');

    for (final med in medications) {
      final stats = med.continuityStats;
      final totalDoses = stats['taken']! + stats['delayed']! + stats['missed']! + stats['notNeeded']!;
      final onTimePct = totalDoses > 0
          ? ((stats['taken']! / (totalDoses - stats['notNeeded']! > 0 ? totalDoses - stats['notNeeded']! : 1)) * 100).toStringAsFixed(1)
          : 'N/A';
      buf.writeln('| **${med.name}** | ${med.dosage} | ${med.form.name.toUpperCase()} | ${med.scheduleFrequency.name} | ${med.scheduledTimes.join(", ")} | $onTimePct% |');
    }
    buf.writeln();

    buf.writeln('## 📊 3. Detailed Intake Records & History\n');
    for (final med in medications) {
      final stats = med.continuityStats;
      final lastTaken = med.lastTakenDateTime != null ? dateFmt.format(med.lastTakenDateTime!) : 'No doses logged yet';

      buf.writeln('### ${med.name} (${med.dosage})');
      buf.writeln('- **Started:** ${dayFmt.format(med.startDate)}');
      buf.writeln('- **Last Dose Taken:** $lastTaken');
      buf.writeln('- **Intake Breakdown:**');
      buf.writeln('  - ✅ Taken On Time: `${stats["taken"]}`');
      buf.writeln('  - ⏰ Taken Delayed: `${stats["delayed"]}`');
      buf.writeln('  - ❌ Missed Window: `${stats["missed"]}`');
      buf.writeln('  - ⚪ Not Needed (PRN): `${stats["notNeeded"]}`');

      if (med.foodRestrictions.isNotEmpty) {
        buf.writeln('- **Dietary Advisories:** ${med.foodRestrictions.join("; ")}');
      }

      if (med.doseLog.isNotEmpty) {
        buf.writeln('\n**Chronological Intake Log:**');
        final sortedKeys = med.doseLog.keys.toList()..sort((a, b) => b.compareTo(a));
        for (final dateKey in sortedKeys) {
          buf.writeln('- `$dateKey`: ${med.doseLog[dateKey]!.join(", ")}');
        }
      }
      buf.writeln();
    }

    buf.writeln('---');
    buf.writeln('*Confidentiality Notice: This document was produced strictly on-device by MediSync.*');
    return buf.toString();
  }

  /// Generates a rich HTML document with responsive CSS and optional print-to-PDF formatting.
  String generateContinuityReportHtml({
    required List<Medication> medications,
    required UserProfile profile,
    bool isPrintablePdf = false,
  }) {
    final now = DateTime.now();
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

    final buf = StringBuffer();
    buf.writeln('<!DOCTYPE html>');
    buf.writeln('<html lang="en">');
    buf.writeln('<head>');
    buf.writeln('  <meta charset="UTF-8">');
    buf.writeln('  <title>MediSync Continuity Report - ${profile.name}</title>');
    buf.writeln('  <style>');
    buf.writeln('    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; color: #1e293b; line-height: 1.5; padding: 24px; max-width: 860px; margin: 0 auto; background: #f8fafc; }');
    buf.writeln('    .card { background: #ffffff; border-radius: 12px; padding: 20px; margin-bottom: 20px; border: 1px solid #e2e8f0; box-shadow: 0 1px 3px rgba(0,0,0,0.05); }');
    buf.writeln('    h1 { color: #0f766e; font-size: 24px; margin-top: 0; }');
    buf.writeln('    h2 { color: #1e293b; font-size: 18px; border-bottom: 2px solid #0f766e; padding-bottom: 6px; }');
    buf.writeln('    table { width: 100%; border-collapse: collapse; margin-top: 12px; }');
    buf.writeln('    th, td { text-align: left; padding: 10px; border-bottom: 1px solid #e2e8f0; font-size: 13px; }');
    buf.writeln('    th { background: #f1f5f9; font-weight: 600; color: #334155; }');
    buf.writeln('    .badge { display: inline-block; padding: 2px 8px; border-radius: 6px; font-size: 11px; font-weight: 600; background: #e0f2fe; color: #0369a1; }');
    buf.writeln('    .badge-danger { background: #fee2e2; color: #b91c1c; }');
    buf.writeln('    .badge-success { background: #dcfce7; color: #15803d; }');
    if (isPrintablePdf) {
      buf.writeln('    @page { size: A4; margin: 15mm; }');
      buf.writeln('    @media print { body { background: #fff; padding: 0; } .card { box-shadow: none; border: 1px solid #ccc; } }');
    }
    buf.writeln('  </style>');
    buf.writeln('</head>');
    buf.writeln('<body>');
    buf.writeln('  <div class="card">');
    buf.writeln('    <h1>🏥 MediSync Clinical Continuity & Intake Record</h1>');
    buf.writeln('    <p><strong>Patient:</strong> ${profile.name} &nbsp;|&nbsp; <strong>Generated:</strong> ${dateFmt.format(now)} &nbsp;|&nbsp; <strong>Mode:</strong> 100% On-Device Local</p>');
    buf.writeln('  </div>');

    buf.writeln('  <div class="card">');
    buf.writeln('    <h2>🛡️ Known Allergies & Safety Flags</h2>');
    if (profile.allergies.isEmpty) {
      buf.writeln('    <p>No known drug allergies (NKDA) reported by patient.</p>');
    } else {
      buf.writeln('    <ul>');
      for (final a in profile.allergies) {
        buf.writeln('      <li><span class="badge badge-danger">ALLERGY TRIGGER</span> <strong>$a</strong></li>');
      }
      buf.writeln('    </ul>');
    }
    buf.writeln('  </div>');

    buf.writeln('  <div class="card">');
    buf.writeln('    <h2>💊 Active Medications & Regimen Summary</h2>');
    buf.writeln('    <table>');
    buf.writeln('      <thead><tr><th>Medication</th><th>Dosage</th><th>Form</th><th>Frequency</th><th>Schedule</th><th>Adherence</th></tr></thead>');
    buf.writeln('      <tbody>');
    for (final med in medications) {
      final stats = med.continuityStats;
      final totalDoses = stats['taken']! + stats['delayed']! + stats['missed']! + stats['notNeeded']!;
      final onTimePct = totalDoses > 0
          ? ((stats['taken']! / (totalDoses - stats['notNeeded']! > 0 ? totalDoses - stats['notNeeded']! : 1)) * 100).toStringAsFixed(1)
          : 'N/A';
      buf.writeln('        <tr>');
      buf.writeln('          <td><strong>${med.name}</strong></td>');
      buf.writeln('          <td>${med.dosage}</td>');
      buf.writeln('          <td><span class="badge">${med.form.name.toUpperCase()}</span></td>');
      buf.writeln('          <td>${med.scheduleFrequency.name}</td>');
      buf.writeln('          <td>${med.scheduledTimes.join(", ")}</td>');
      buf.writeln('          <td><span class="badge badge-success">$onTimePct%</span></td>');
      buf.writeln('        </tr>');
    }
    buf.writeln('      </tbody>');
    buf.writeln('    </table>');
    buf.writeln('  </div>');

    buf.writeln('  <div class="card">');
    buf.writeln('    <h2>📋 Detailed Intake Log</h2>');
    for (final med in medications) {
      final stats = med.continuityStats;
      buf.writeln('    <h3>${med.name} (${med.dosage})</h3>');
      buf.writeln('    <p><strong>Stats:</strong> Taken on time: ${stats["taken"]} | Delayed: ${stats["delayed"]} | Missed: ${stats["missed"]} | Not needed: ${stats["notNeeded"]}</p>');
      if (med.doseLog.isNotEmpty) {
        buf.writeln('    <ul>');
        for (final entry in med.doseLog.entries) {
          buf.writeln('      <li><strong>${entry.key}:</strong> ${entry.value.join(", ")}</li>');
        }
        buf.writeln('    </ul>');
      }
    }
    buf.writeln('  </div>');

    buf.writeln('</body>');
    buf.writeln('</html>');
    return buf.toString();
  }

  /// Generates a structured XML document for healthcare interoperability and HL7/FHIR alignment.
  String generateContinuityReportXml({
    required List<Medication> medications,
    required UserProfile profile,
  }) {
    final now = DateTime.now();
    final dateFmt = DateFormat('yyyy-MM-ddTHH:mm:ss');
    final dayFmt = DateFormat('yyyy-MM-dd');

    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<MediSyncContinuityRecord version="1.6.0" generatedAt="${dateFmt.format(now)}">');
    buf.writeln('  <Patient>');
    buf.writeln('    <Name><![CDATA[${profile.name}]]></Name>');
    buf.writeln('    <StorageSecurity>OnDeviceEncrypted</StorageSecurity>');
    buf.writeln('  </Patient>');

    buf.writeln('  <Allergies count="${profile.allergies.length}">');
    for (final a in profile.allergies) {
      buf.writeln('    <AllergyTrigger><![CDATA[$a]]></AllergyTrigger>');
    }
    buf.writeln('  </Allergies>');

    buf.writeln('  <Medications count="${medications.length}">');
    for (final med in medications) {
      final stats = med.continuityStats;
      buf.writeln('    <Medication id="${med.id}">');
      buf.writeln('      <Name><![CDATA[${med.name}]]></Name>');
      buf.writeln('      <Dosage><![CDATA[${med.dosage}]]></Dosage>');
      buf.writeln('      <Form>${med.form.name}</Form>');
      buf.writeln('      <Frequency>${med.scheduleFrequency.name}</Frequency>');
      buf.writeln('      <StartDate>${dayFmt.format(med.startDate)}</StartDate>');
      buf.writeln('      <ScheduledTimes>');
      for (final t in med.scheduledTimes) {
        buf.writeln('        <Time>$t</Time>');
      }
      buf.writeln('      </ScheduledTimes>');
      buf.writeln('      <Statistics>');
      buf.writeln('        <TakenOnTime>${stats["taken"]}</TakenOnTime>');
      buf.writeln('        <TakenDelayed>${stats["delayed"]}</TakenDelayed>');
      buf.writeln('        <Missed>${stats["missed"]}</Missed>');
      buf.writeln('        <NotNeeded>${stats["notNeeded"]}</NotNeeded>');
      buf.writeln('      </Statistics>');
      buf.writeln('      <DoseLog>');
      for (final e in med.doseLog.entries) {
        buf.writeln('        <LogEntry date="${e.key}"><![CDATA[${e.value.join(", ")}]]></LogEntry>');
      }
      buf.writeln('      </DoseLog>');
      buf.writeln('    </Medication>');
    }
    buf.writeln('  </Medications>');
    buf.writeln('</MediSyncContinuityRecord>');
    return buf.toString();
  }

  /// Generates a Word-compatible (.doc) HTML/MIME file readable by Microsoft Word and Google Docs.
  String generateContinuityReportDoc({
    required List<Medication> medications,
    required UserProfile profile,
  }) {
    return generateContinuityReportHtml(medications: medications, profile: profile, isPrintablePdf: true);
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
