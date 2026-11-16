import 'package:flutter_test/flutter_test.dart';
import 'package:medisync/core/data/medicines_database.dart';
import 'package:medisync/core/models/condition.dart';
import 'package:medisync/core/models/safety_flag.dart';
import 'package:medisync/core/models/side_effect.dart';
import 'package:medisync/core/models/user_profile.dart';
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
  });
}
