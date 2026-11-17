import 'package:flutter_test/flutter_test.dart';
import 'package:medisync/core/data/medicines_database.dart';
import 'package:medisync/core/models/condition.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/models/safety_flag.dart';
import 'package:medisync/core/models/side_effect.dart';
import 'package:medisync/core/models/user_profile.dart';
import 'package:medisync/core/services/device_integration_service.dart';
import 'package:medisync/core/services/scheduler_service.dart';

void main() {
  group('SchedulerService Tests', () {
    const testProfile = UserProfile(
      name: 'John Doe',
      allergies: ['Penicillin'],
      wakeTime: '07:00',
      sleepTime: '23:00',
      breakfastTime: '08:00',
      lunchTime: '13:00',
      dinnerTime: '20:00',
    );

    test('Arranges bedtime slot with clinical rationale for medication causing drowsiness', () {
      final result = SchedulerService.calculateSmartScheduleWithRationale(
        timesPerDay: 1,
        profile: testProfile,
        sideEffects: const [
          SideEffect(
            type: SideEffectType.drowsiness,
            description: 'Causes sleepiness',
            scheduleHint: ScheduleHint.scheduleNearBedtime,
          ),
        ],
        preConditions: const [],
        postConditions: const [],
      );

      expect(result.times.length, 1);
      // Bedtime is 23:00 -> 30 min before is 22:30
      expect(result.times.first, '22:30');
      expect(result.rationale.contains('bedtime'), true);
      expect(result.rationale.contains('drowsiness'), true);
    });

    test('Arranges mealtime slots for medication causing stomach upset', () {
      final schedule = SchedulerService.calculateSmartSchedule(
        timesPerDay: 2,
        profile: testProfile,
        sideEffects: const [
          SideEffect(
            type: SideEffectType.stomachUpset,
            description: 'Causes stomach ache',
            scheduleHint: ScheduleHint.scheduleAfterMeal,
          ),
        ],
        preConditions: const [],
        postConditions: const [],
      );

      expect(schedule.length, 2);
      expect(schedule[0], '08:20');
      expect(schedule[1], '20:20');
    });

    test('Schedules empty stomach medication for early morning absorption', () {
      final schedule = SchedulerService.calculateSmartSchedule(
        timesPerDay: 1,
        profile: testProfile,
        sideEffects: const [],
        preConditions: const [
          MedicationCondition(
            type: ConditionType.emptyStomach,
            timing: ConditionTiming.before,
            description: 'Empty stomach',
          ),
        ],
        postConditions: const [],
      );

      expect(schedule.length, 1);
      // Wake time 07:00 + 15 min = 07:15
      expect(schedule.first, '07:15');
    });

    test('Searches medical database for Panadol and Amoxicillin', () {
      final panadolResults = MedicinesDatabase.search('panadol');
      expect(panadolResults.isNotEmpty, true);
      expect(panadolResults.first.genericName, 'Paracetamol');

      final amoxResults = MedicinesDatabase.search('amoxicillin');
      expect(amoxResults.isNotEmpty, true);
      expect(amoxResults.first.allergenTriggers.contains('penicillin'), true);
    });

    test('Detects allergy conflict for Penicillin derivative template', () {
      final template = MedicinesDatabase.search('Augmentin').first;
      final flags = SchedulerService.checkSafety(
        medicationName: 'Augmentin',
        profile: testProfile,
        matchedTemplate: template,
      );

      expect(flags.isNotEmpty, true);
      expect(flags.first.severity, FlagSeverity.critical);
      expect(flags.first.relatedAllergy, 'Penicillin');
    });

    test('Flags no safety conflict for safe medication', () {
      final flags = SchedulerService.checkSafety(
        medicationName: 'Metformin',
        profile: testProfile,
      );

      expect(flags.isEmpty, true);
    });

    test('Detects Drug-Drug Interaction: NSAID + Anticoagulant Hemorrhage Risk', () {
      final existingWarfarin = Medication(
        id: 'med_warfarin',
        name: 'Coumadin',
        dosage: '5mg',
        form: MedicationForm.pill,
        timesPerDay: 1,
        scheduledTimes: const ['18:00'],
        startDate: DateTime(2026, 11, 1),
      );

      final flags = SchedulerService.checkSafety(
        medicationName: 'Advil',
        profile: testProfile,
        existingMeds: [existingWarfarin],
      );

      expect(flags.any((f) => f.title.contains('Bleeding Risk') || f.title.contains('Anticoagulant')), true);
    });

    test('Detects Chelation & Absorption Spacing Advisory for Fluoroquinolones & Cations', () {
      final existingAntacid = Medication(
        id: 'med_calcium',
        name: 'Calcium Carbonate',
        dosage: '500mg',
        form: MedicationForm.pill,
        timesPerDay: 1,
        scheduledTimes: const ['08:00'],
        startDate: DateTime(2026, 11, 1),
      );

      final flags = SchedulerService.checkSafety(
        medicationName: 'Cipro',
        profile: testProfile,
        existingMeds: [existingAntacid],
      );

      expect(flags.any((f) => f.title.contains('Absorption') || f.title.contains('Chelation')), true);
    });

    test('Medication frequency active checks for Monthly, Twice-Monthly, Every-X-Days', () {
      final startDate = DateTime(2026, 11, 1);

      final monthlyMed = Medication(
        id: 'monthly_1',
        name: 'Monthly Injection',
        dosage: '1 dose',
        form: MedicationForm.injection,
        timesPerDay: 1,
        scheduledTimes: const ['09:00'],
        startDate: startDate,
        scheduleFrequency: ScheduleFrequency.monthly,
        monthlyDays: const [1],
      );

      expect(monthlyMed.isActiveOn(DateTime(2026, 11, 1)), true);
      expect(monthlyMed.isActiveOn(DateTime(2026, 11, 2)), false);
      expect(monthlyMed.isActiveOn(DateTime(2026, 12, 1)), true);

      final twiceMonthlyMed = Medication(
        id: 'bi_monthly_1',
        name: 'Bi-Monthly Med',
        dosage: '1 tablet',
        form: MedicationForm.pill,
        timesPerDay: 1,
        scheduledTimes: const ['09:00'],
        startDate: startDate,
        scheduleFrequency: ScheduleFrequency.twiceMonthly,
        monthlyDays: const [1, 15],
      );

      expect(twiceMonthlyMed.isActiveOn(DateTime(2026, 11, 1)), true);
      expect(twiceMonthlyMed.isActiveOn(DateTime(2026, 11, 15)), true);
      expect(twiceMonthlyMed.isActiveOn(DateTime(2026, 11, 10)), false);

      final every3DaysMed = Medication(
        id: 'every_3_days',
        name: 'Intermittent Med',
        dosage: '1 capsule',
        form: MedicationForm.capsule,
        timesPerDay: 1,
        scheduledTimes: const ['10:00'],
        startDate: startDate,
        scheduleFrequency: ScheduleFrequency.everyXDays,
        intervalDays: 3,
      );

      expect(every3DaysMed.isActiveOn(DateTime(2026, 11, 1)), true); // day 0
      expect(every3DaysMed.isActiveOn(DateTime(2026, 11, 2)), false); // day 1
      expect(every3DaysMed.isActiveOn(DateTime(2026, 11, 3)), false); // day 2
      expect(every3DaysMed.isActiveOn(DateTime(2026, 11, 4)), true); // day 3
    });

    test('Medication DoseStatus records and tracks Taken, Delayed, Missed, and Not-Needed states', () {
      final med = Medication(
        id: 'med_test_status',
        name: 'Lipitor',
        dosage: '20mg',
        form: MedicationForm.pill,
        timesPerDay: 2,
        scheduledTimes: const ['08:00', '20:00'],
        startDate: DateTime(2026, 11, 1),
        doseLog: const {
          '2026-11-17': ['08:00:taken', '20:00:delayed'],
          '2026-11-16': ['08:00:missed', '20:00:notNeeded'],
          '2026-11-15': ['08:00'], // legacy format -> defaults to taken
        },
      );

      final targetDate = DateTime(2026, 11, 17);
      expect(med.getDoseStatus(targetDate, '08:00'), DoseStatus.taken);
      expect(med.getDoseStatus(targetDate, '20:00'), DoseStatus.delayed);
      expect(med.getDoseStatus(DateTime(2026, 11, 16), '08:00'), DoseStatus.missed);
      expect(med.getDoseStatus(DateTime(2026, 11, 16), '20:00'), DoseStatus.notNeeded);
      expect(med.getDoseStatus(DateTime(2026, 11, 15), '08:00'), DoseStatus.taken);
      expect(med.getDoseStatus(targetDate, '12:00'), DoseStatus.pending);

      // Continuity Stats
      final stats = med.continuityStats;
      expect(stats['taken'], 2);
      expect(stats['delayed'], 1);
      expect(stats['missed'], 1);
      expect(stats['notNeeded'], 1);

      // Last taken date calculation
      expect(med.lastTakenDateTime, DateTime(2026, 11, 17, 20, 0));
    });

    test('DeviceIntegrationService produces offline ICS and patient continuity report', () {
      final med = Medication(
        id: 'med_test_rpt',
        name: 'Synthroid',
        dosage: '50mcg',
        form: MedicationForm.pill,
        timesPerDay: 1,
        scheduledTimes: const ['07:00'],
        startDate: DateTime(2026, 11, 1),
        foodRestrictions: const ['Take on empty stomach 30-60m before breakfast'],
        doseLog: const {
          '2026-11-17': ['07:00:taken'],
        },
      );

      final service = DeviceIntegrationService();
      final ics = service.generateIcsCalendar([med]);
      expect(ics.contains('BEGIN:VCALENDAR'), true);
      expect(ics.contains('Take Synthroid (50mcg)'), true);
      expect(ics.contains('END:VCALENDAR'), true);

      final rpt = service.generateContinuityReport(
        medications: [med],
        profile: testProfile,
      );
      expect(rpt.contains('MEDISYNC CLINICAL CONTINUITY'), true);
      expect(rpt.contains('Synthroid'), true);
      expect(rpt.contains('Penicillin'), true);
      expect(rpt.contains('100% On-Device Local Encrypted Storage'), true);
    });

    test('MedicinesDatabase supplies evidence-based food & dietary restrictions', () {
      final lipitor = MedicinesDatabase.search('Lipitor').first;
      expect(lipitor.foodRestrictions.any((r) => r.toLowerCase().contains('grapefruit')), true);

      final cipro = MedicinesDatabase.search('Cipro').first;
      expect(cipro.foodRestrictions.any((r) => r.toLowerCase().contains('dairy') || r.toLowerCase().contains('calcium')), true);

      final synthroid = MedicinesDatabase.search('Synthroid').first;
      expect(synthroid.foodRestrictions.any((r) => r.toLowerCase().contains('empty stomach') || r.toLowerCase().contains('breakfast')), true);
    });

    test('Dose marked as Not Needed resolves dose and preserves adherence without showing as delayed or pending', () {
      final now = DateTime.now();
      final dateKey = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final prnMed = Medication(
        id: 'med_prn_test',
        name: 'Ibuprofen PRN',
        dosage: '400mg',
        form: MedicationForm.pill,
        timesPerDay: 1,
        scheduledTimes: const ['14:00'],
        scheduleFrequency: ScheduleFrequency.asNeeded,
        startDate: now.subtract(const Duration(days: 3)),
        doseLog: {
          dateKey: ['14:00:notNeeded'],
        },
      );

      // Verify status is DoseStatus.notNeeded
      expect(prnMed.getDoseStatus(now, '14:00'), DoseStatus.notNeeded);

      // Crucial: Dose is resolved (so it is excluded from upcoming and overdue next dose countdown)
      expect(prnMed.isDoseResolved(now, '14:00'), true);

      // Not considered taken
      expect(prnMed.isDoseTaken(now, '14:00'), false);

      // Verify continuity stats correctly increment notNeeded
      final stats = prnMed.continuityStats;
      expect(stats['notNeeded'], 1);
      expect(stats['taken'], 0);
      expect(stats['missed'], 0);
      expect(stats['delayed'], 0);
    });

    test('Clinical spacing logic computes appropriate minimum intervals between doses', () {
      // BID requires >= 6h separation
      expect(
        SchedulerService.calculateSmartSchedule(
          timesPerDay: 2,
          profile: testProfile,
          sideEffects: const [],
          preConditions: const [],
          postConditions: const [],
        ).length,
        2,
      );

      // TID requires >= 4h separation
      expect(
        SchedulerService.calculateSmartSchedule(
          timesPerDay: 3,
          profile: testProfile,
          sideEffects: const [],
          preConditions: const [],
          postConditions: const [],
        ).length,
        3,
      );

      // QID requires >= 3h separation
      expect(
        SchedulerService.calculateSmartSchedule(
          timesPerDay: 4,
          profile: testProfile,
          sideEffects: const [],
          preConditions: const [],
          postConditions: const [],
        ).length,
        4,
      );
    });
  });
}
