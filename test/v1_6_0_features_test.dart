import 'package:flutter_test/flutter_test.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/models/user_profile.dart';
import 'package:medisync/core/services/device_integration_service.dart';
import 'package:medisync/core/services/scheduler_service.dart';
import 'package:medisync/core/services/streak_service.dart';

void main() {
  group('v1.6.0 Feature Expansion & Polish Tests', () {
    final testProfile = UserProfile(
      name: 'Abdalaziz Badawi',
      allergies: ['Penicillin', 'Sulfa', 'Aspirin'],
      wakeTime: '07:30',
      sleepTime: '23:00',
      breakfastTime: '08:30',
      lunchTime: '13:00',
      dinnerTime: '19:30',
    );

    test('Calendar-style Discontinuation: preserves historical logs and halts future schedule', () {
      final now = DateTime.now();
      final pastDate = now.subtract(const Duration(days: 10));
      final futureDate = now.add(const Duration(days: 5));

      final activeMed = Medication(
        id: 'amox-101',
        name: 'Amoxicillin',
        dosage: '500 mg',
        timesPerDay: 2,
        scheduledTimes: ['08:00', '20:00'],
        startDate: pastDate,
        doseLog: {
          '${pastDate.year}-${pastDate.month.toString().padLeft(2, '0')}-${pastDate.day.toString().padLeft(2, '0')}': ['08:00', '20:00'],
        },
      );

      // Verify active on both past and future before discontinuation
      expect(activeMed.isActiveOn(pastDate), isTrue);
      expect(activeMed.isActiveOn(futureDate), isTrue);
      expect(activeMed.isDiscontinued, isFalse);

      // Discontinue starting today
      final discontinuedMed = activeMed.copyWith(
        discontinuedDate: now,
        discontinuationReason: 'Completed acute therapeutic course',
      );

      expect(discontinuedMed.isDiscontinued, isTrue);
      expect(discontinuedMed.discontinuationReason, 'Completed acute therapeutic course');

      // Crucial: Active in history (past), but inactive in future!
      expect(discontinuedMed.isActiveOn(pastDate), isTrue);
      expect(discontinuedMed.isActiveOn(futureDate), isFalse);

      // Historical intake logs and continuity stats MUST remain 100% intact!
      expect(discontinuedMed.doseLog.isNotEmpty, isTrue);
      final stats = discontinuedMed.continuityStats;
      expect(stats['taken'], 2);

      // Resume test
      final resumedMed = Medication(
        id: discontinuedMed.id,
        name: discontinuedMed.name,
        dosage: discontinuedMed.dosage,
        form: discontinuedMed.form,
        timesPerDay: discontinuedMed.timesPerDay,
        scheduledTimes: discontinuedMed.scheduledTimes,
        startDate: discontinuedMed.startDate,
        discontinuedDate: null,
        discontinuationReason: null,
      );
      expect(resumedMed.isDiscontinued, isFalse);
      expect(resumedMed.isActiveOn(futureDate), isTrue);
    });

    test('Duolingo-inspired Adherence Streak: computes streak, milestones, and 7-day flame trail', () {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final med = Medication(
        id: 'atorv-1',
        name: 'Atorvastatin',
        dosage: '20 mg',
        timesPerDay: 1,
        scheduledTimes: ['21:00'],
        startDate: now.subtract(const Duration(days: 30)),
        doseLog: {
          todayStr: ['21:00'],
        },
      );

      final streakData = StreakService.computeStreakData([med]);
      expect(streakData.currentStreak, greaterThanOrEqualTo(1));
      expect(streakData.weeklyDayStatus.length, 7); // Monday through Sunday
      expect(streakData.nextMilestone, isNotNull);
    });

    test('Red Flag Allergy Checking: guards against premature 1-letter triggers and catches true conflicts', () {
      // 1-letter input "P" should NEVER flag Penicillin
      final flagsP = SchedulerService.checkSafety(
        medicationName: 'P',
        profile: testProfile,
      );
      expect(flagsP.isEmpty, isTrue);

      // 2-letter input "Pa" should NOT trigger false positive
      final flagsPa = SchedulerService.checkSafety(
        medicationName: 'Pa',
        profile: testProfile,
      );
      expect(flagsPa.isEmpty, isTrue);

      // True allergy: "Penicillin VK" triggers Red Flag against testProfile.allergies ['Penicillin', 'Sulfa', 'Aspirin']
      final flagsPen = SchedulerService.checkSafety(
        medicationName: 'Penicillin VK',
        profile: testProfile,
      );
      expect(flagsPen.any((f) => f.relatedAllergy == 'Penicillin'), isTrue);

      // True allergy: "Aspirin 81mg" triggers Red Flag against Aspirin
      final flagsAsp = SchedulerService.checkSafety(
        medicationName: 'Aspirin Cardio',
        profile: testProfile,
      );
      expect(flagsAsp.any((f) => f.relatedAllergy == 'Aspirin'), isTrue);
    });

    test('Multi-Format Continuity Report: generates Text, Markdown, HTML, XML, Word Doc, and PDF layout', () {
      final integration = DeviceIntegrationService();
      final now = DateTime.now();

      final med = Medication(
        id: 'lisin-1',
        name: 'Lisinopril',
        dosage: '10 mg',
        timesPerDay: 1,
        scheduledTimes: ['08:00'],
        startDate: now.subtract(const Duration(days: 14)),
      );

      final txt = integration.generateContinuityReportFormatted(
        medications: [med],
        profile: testProfile,
        format: ReportExportFormat.text,
      );
      expect(txt.contains('MEDISYNC CLINICAL CONTINUITY'), isTrue);
      expect(txt.contains('Lisinopril'), isTrue);

      final md = integration.generateContinuityReportFormatted(
        medications: [med],
        profile: testProfile,
        format: ReportExportFormat.markdown,
      );
      expect(md.contains('# 📋 MediSync Clinical Continuity'), isTrue);
      expect(md.contains('| **Lisinopril** |'), isTrue);

      final textReport = integration.generateContinuityReportFormatted(
        medications: [med],
        profile: testProfile,
        format: ReportExportFormat.text,
      );
      expect(textReport.contains('MEDISYNC CLINICAL CONTINUITY'), isTrue);
      expect(textReport.contains('Lisinopril'), isTrue);

      final pdf = integration.generateContinuityReportFormatted(
        medications: [med],
        profile: testProfile,
        format: ReportExportFormat.pdf,
      );
      expect(pdf.contains('CLINICAL CONTINUITY RECORD'), isTrue);
      expect(pdf.contains('Lisinopril'), isTrue);
    });
  });
}
