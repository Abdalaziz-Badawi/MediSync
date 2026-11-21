import 'package:flutter_test/flutter_test.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/models/user_profile.dart';
import 'package:medisync/core/services/notification_service.dart';
import 'package:medisync/core/services/streak_service.dart';

void main() {
  group('v1.7.0 Multi-Tier Interval Scheduling & Display', () {
    test('monthly frequency displays correctly and does not show daily', () {
      final med = Medication(
        id: 'med-monthly-1',
        name: 'Vitamin D3 Injection',
        dosage: '60000 IU',
        timesPerDay: 1,
        scheduledTimes: ['09:00'],
        startDate: DateTime(2026, 1, 1),
        scheduleFrequency: ScheduleFrequency.monthly,
        monthlyDays: [1],
      );

      expect(med.frequencyDisplay, 'Monthly (Day 1) • 1x');
      expect(med.frequencyDisplay.contains('daily'), isFalse);
    });

    test('everyXWeeks displays and computes active days accurately', () {
      final start = DateTime(2026, 1, 5); // Monday
      final med = Medication(
        id: 'med-weeks-1',
        name: 'Methotrexate',
        dosage: '15 mg',
        timesPerDay: 1,
        scheduledTimes: ['08:00'],
        startDate: start,
        scheduleFrequency: ScheduleFrequency.everyXWeeks,
        intervalWeeks: 3,
      );

      expect(med.frequencyDisplay, 'Every 3 weeks (Daily) • 1x');
      // Active on start date
      expect(med.isActiveOn(start), isTrue);
      // Active 3 weeks later
      expect(med.isActiveOn(start.add(const Duration(days: 21))), isTrue);
      // Not active 1 or 2 weeks later
      expect(med.isActiveOn(start.add(const Duration(days: 7))), isFalse);
      expect(med.isActiveOn(start.add(const Duration(days: 14))), isFalse);
    });

    test('everyXMonths displays and computes active days accurately', () {
      final start = DateTime(2026, 1, 15);
      final med = Medication(
        id: 'med-months-1',
        name: 'B12 Depot',
        dosage: '1000 mcg',
        timesPerDay: 1,
        scheduledTimes: ['10:00'],
        startDate: start,
        scheduleFrequency: ScheduleFrequency.everyXMonths,
        intervalMonths: 2,
        monthlyDays: [15],
      );

      expect(med.frequencyDisplay, 'Every 2 months (Day 15) • 1x');
      // Active in January (month difference = 0 % 2 == 0)
      expect(med.isActiveOn(DateTime(2026, 1, 15)), isTrue);
      // Not active in February (month difference = 1 % 2 != 0)
      expect(med.isActiveOn(DateTime(2026, 2, 15)), isFalse);
      // Active in March (month difference = 2 % 2 == 0)
      expect(med.isActiveOn(DateTime(2026, 3, 15)), isTrue);
    });
  });

  group('v1.7.0 Dynamic BMI & Health Biometrics', () {
    test('computes BMI and classifies normal weight correctly', () {
      const profile = UserProfile(
        name: 'Alex Mercer',
        heightCm: 180.0,
        weightKg: 72.0,
      );

      expect(profile.bmi, isNotNull);
      // 72 / (1.8 * 1.8) = 22.22
      expect(profile.bmi!, closeTo(22.22, 0.05));
      expect(profile.bmiCategory, 'Normal');
    });

    test('computes underweight, overweight, and obese accurately', () {
      const underweight = UserProfile(name: 'A', heightCm: 175.0, weightKg: 50.0);
      expect(underweight.bmiCategory, 'Underweight');

      const overweight = UserProfile(name: 'B', heightCm: 170.0, weightKg: 78.0);
      expect(overweight.bmiCategory, 'Overweight');

      const obese = UserProfile(name: 'C', heightCm: 165.0, weightKg: 95.0);
      expect(obese.bmiCategory, 'Obese');
    });

    test('handles missing or zero height gracefully without crashing', () {
      const empty = UserProfile(name: 'No metrics');
      expect(empty.bmi, isNull);
      expect(empty.bmiCategory, 'Unrecorded');

      const zeroHeight = UserProfile(name: 'Zero', heightCm: 0.0, weightKg: 70.0);
      expect(zeroHeight.bmi, isNull);
      expect(zeroHeight.bmiCategory, 'Unrecorded');
    });
  });

  group('v1.7.0 3-Phase Clinical Reminder Architecture IDs', () {
    test('generates unique deterministic notification IDs for pre, at, and post phases', () {
      const medId = 'med-10050';
      const time = '08:00';

      final baseId = NotificationService.getNotificationId(medId, time);
      final preId = NotificationService.getPreNotificationId(medId, time);
      final postId = NotificationService.getPostNotificationId(medId, time);

      // Verify they do not collide
      expect(preId, isNot(equals(baseId)));
      expect(postId, isNot(equals(baseId)));
      expect(preId, isNot(equals(postId)));
    });
  });

  group('v1.7.0 Vital Continuity Shield & Non-Punitive PRN', () {
    test('as-needed doses marked as notNeeded preserve protected days continuity', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      final yesterdayKey = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final med = Medication(
        id: 'med-prn-1',
        name: 'Salbutamol Inhaler',
        dosage: '100 mcg',
        timesPerDay: 1,
        scheduledTimes: ['08:00'],
        startDate: yesterday.subtract(const Duration(days: 5)),
        scheduleFrequency: ScheduleFrequency.asNeeded,
        doseLog: {
          yesterdayKey: ['08:00:notNeeded'],
          todayKey: ['08:00:taken'],
        },
      );

      final streakData = StreakService.computeStreakData([med]);
      // Should count both days as protected!
      expect(streakData.currentStreak, greaterThanOrEqualTo(2));
    });

    test('ContinuityService typedef and milestones reflect medical rebranding', () {
      expect(ContinuityMilestone.all.isNotEmpty, isTrue);
      final first = ContinuityMilestone.all.first;
      expect(first.title.toLowerCase().contains('shield') || first.title.toLowerCase().contains('vital'), isTrue);
    });
  });

  group('v1.7.0 Chronic Patient Features: Supply Runway & Missed Dose Advice', () {
    test('calculates package remaining runway and low supply alerts', () {
      final med = Medication(
        id: 'med-supply-1',
        name: 'Atorvastatin',
        dosage: '20 mg',
        timesPerDay: 1,
        scheduledTimes: ['21:00'],
        startDate: DateTime.now(),
        packageSize: 30,
        pillsRemaining: 5, // 5 days left -> < 7 days
      );

      expect(med.estimatedDosesRemaining, 5);
      expect(med.estimatedDaysRemaining, 5);
      expect(med.isLowSupply, isTrue);
    });

    test('provides evidence-based missed dose advice with halfway rule', () {
      final med = Medication(
        id: 'med-advice-1',
        name: 'Metformin',
        dosage: '500 mg',
        timesPerDay: 2,
        scheduledTimes: ['08:00', '20:00'],
        startDate: DateTime.now(),
      );

      final advice = med.missedDoseAdvice;
      expect(advice.contains('skip and wait'), isTrue);
      expect(advice.contains('Never take two doses at once'), isTrue);
    });
  });
}
