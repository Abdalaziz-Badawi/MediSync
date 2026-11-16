import '../data/medicines_database.dart';
import '../models/condition.dart';
import '../models/medication.dart';
import '../models/safety_flag.dart';
import '../models/side_effect.dart';
import '../models/user_profile.dart';

class SmartScheduleResult {
  final List<String> times;
  final String rationale;

  const SmartScheduleResult({
    required this.times,
    required this.rationale,
  });
}

class SchedulerService {
  /// Proposes optimal schedule times with studied clinical rationales.
  static SmartScheduleResult calculateSmartScheduleWithRationale({
    required int timesPerDay,
    required UserProfile profile,
    required List<SideEffect> sideEffects,
    required List<MedicationCondition> preConditions,
    required List<MedicationCondition> postConditions,
  }) {
    final times = calculateSmartSchedule(
      timesPerDay: timesPerDay,
      profile: profile,
      sideEffects: sideEffects,
      preConditions: preConditions,
      postConditions: postConditions,
    );

    final causesDrowsiness = sideEffects.any(
      (s) =>
          s.type == SideEffectType.drowsiness ||
          s.scheduleHint == ScheduleHint.scheduleNearBedtime,
    );
    final beforeSleepCondition = preConditions.any(
          (c) => c.type == ConditionType.sleep,
        ) ||
        postConditions.any((c) => c.type == ConditionType.sleep);

    final requiresFood = sideEffects.any(
          (s) =>
              s.type == SideEffectType.stomachUpset ||
              s.type == SideEffectType.nausea ||
              s.scheduleHint == ScheduleHint.scheduleAfterMeal,
        ) ||
        preConditions.any((c) => c.type == ConditionType.meal) ||
        postConditions.any((c) => c.type == ConditionType.meal);

    final requiresEmptyStomach = preConditions.any(
      (c) => c.type == ConditionType.emptyStomach,
    );

    final causesInsomnia = sideEffects.any(
      (s) =>
          s.type == SideEffectType.insomnia ||
          s.scheduleHint == ScheduleHint.scheduleMorning,
    );

    final reasons = <String>[];

    if (causesDrowsiness || beforeSleepCondition) {
      reasons.add(
        'Scheduled at bedtime (${times.last}) to leverage drowsiness safely during sleep and avoid daytime fatigue.',
      );
    }
    if (requiresFood) {
      reasons.add(
        'Aligned 20 minutes after your meal times to buffer your gastric mucosa and minimize stomach upset.',
      );
    }
    if (requiresEmptyStomach) {
      reasons.add(
        'Arranged early in the morning upon waking (${times.first}) to ensure maximal therapeutic absorption without food interference.',
      );
    }
    if (causesInsomnia) {
      reasons.add(
        'Placed in the morning (${times.first}) so stimulation does not interfere with your evening sleep cycle.',
      );
    }

    if (reasons.isEmpty) {
      reasons.add(
        'Evenly spaced across your daily waking routine (${profile.wakeTime} to ${profile.sleepTime}) to maintain consistent drug plasma concentrations.',
      );
    }

    return SmartScheduleResult(
      times: times,
      rationale: reasons.join('\n• '),
    );
  }

  /// Proposes optimal schedule times for a medication given user routine,
  /// side-effects, and conditions.
  static List<String> calculateSmartSchedule({
    required int timesPerDay,
    required UserProfile profile,
    required List<SideEffect> sideEffects,
    required List<MedicationCondition> preConditions,
    required List<MedicationCondition> postConditions,
  }) {
    final causesDrowsiness = sideEffects.any(
      (s) =>
          s.type == SideEffectType.drowsiness ||
          s.scheduleHint == ScheduleHint.scheduleNearBedtime,
    );
    final beforeSleepCondition = preConditions.any(
          (c) => c.type == ConditionType.sleep,
        ) ||
        postConditions.any((c) => c.type == ConditionType.sleep);

    final requiresFood = sideEffects.any(
          (s) =>
              s.type == SideEffectType.stomachUpset ||
              s.type == SideEffectType.nausea ||
              s.scheduleHint == ScheduleHint.scheduleAfterMeal,
        ) ||
        preConditions.any((c) => c.type == ConditionType.meal) ||
        postConditions.any((c) => c.type == ConditionType.meal);

    final requiresEmptyStomach = preConditions.any(
      (c) => c.type == ConditionType.emptyStomach,
    );

    final causesInsomnia = sideEffects.any(
      (s) =>
          s.type == SideEffectType.insomnia ||
          s.scheduleHint == ScheduleHint.scheduleMorning,
    );

    final bedtimeSlot = _adjustMinutes(profile.sleepTime, -30);
    final breakfastSlot = _adjustMinutes(profile.breakfastTime, 20);
    final lunchSlot = _adjustMinutes(profile.lunchTime, 20);
    final dinnerSlot = _adjustMinutes(profile.dinnerTime, 20);

    final emptyStomachMorning = _adjustMinutes(profile.wakeTime, 15);
    final emptyStomachAfternoon = _adjustMinutes(profile.lunchTime, 120);

    if (timesPerDay <= 1) {
      if (causesDrowsiness || beforeSleepCondition) {
        return [bedtimeSlot];
      }
      if (causesInsomnia) {
        return [breakfastSlot];
      }
      if (requiresEmptyStomach) {
        return [emptyStomachMorning];
      }
      if (requiresFood) {
        return [lunchSlot];
      }
      return [breakfastSlot];
    }

    if (timesPerDay == 2) {
      if (causesDrowsiness || beforeSleepCondition) {
        return [
          requiresFood ? breakfastSlot : _adjustMinutes(profile.wakeTime, 30),
          bedtimeSlot,
        ];
      }
      if (requiresFood) {
        return [breakfastSlot, dinnerSlot];
      }
      if (requiresEmptyStomach) {
        return [emptyStomachMorning, emptyStomachAfternoon];
      }
      return [breakfastSlot, dinnerSlot];
    }

    if (timesPerDay == 3) {
      if (requiresFood) {
        return [breakfastSlot, lunchSlot, dinnerSlot];
      }
      return [
        breakfastSlot,
        lunchSlot,
        causesDrowsiness ? bedtimeSlot : dinnerSlot,
      ];
    }

    if (timesPerDay == 4) {
      return [
        breakfastSlot,
        lunchSlot,
        dinnerSlot,
        bedtimeSlot,
      ];
    }

    return _distributeAcrossDay(profile.wakeTime, profile.sleepTime, timesPerDay);
  }

  /// Verifies safety against user's allergies and existing medications.
  static List<SafetyFlag> checkSafety({
    required String medicationName,
    required UserProfile profile,
    List<Medication> existingMeds = const [],
    MedicineTemplate? matchedTemplate,
  }) {
    final flags = <SafetyFlag>[];
    final cleanName = medicationName.trim().toLowerCase();
    if (cleanName.isEmpty) return flags;

    // Check against template's allergen triggers
    if (matchedTemplate != null) {
      for (final trigger in matchedTemplate.allergenTriggers) {
        for (final userAllergy in profile.allergies) {
          final cleanUserAllergy = userAllergy.trim().toLowerCase();
          if (cleanUserAllergy.isNotEmpty &&
              (trigger.contains(cleanUserAllergy) ||
                  cleanUserAllergy.contains(trigger))) {
            flags.add(SafetyFlag(
              severity: FlagSeverity.critical,
              title: 'Critical Allergy Conflict Flagged',
              message:
                  'Danger: "$medicationName" (${matchedTemplate.drugClass}) contains or triggers "$userAllergy". Do NOT take this medication without consulting your doctor or pharmacist.',
              relatedAllergy: userAllergy,
            ));
            break;
          }
        }
      }
    }

    // Direct match against user allergies
    for (final allergy in profile.allergies) {
      final cleanAllergy = allergy.trim().toLowerCase();
      if (cleanAllergy.isEmpty) continue;

      if (cleanName.contains(cleanAllergy) || cleanAllergy.contains(cleanName)) {
        if (!flags.any((f) => f.relatedAllergy == allergy)) {
          flags.add(SafetyFlag(
            severity: FlagSeverity.critical,
            title: 'Allergy Conflict Detected',
            message:
                'Warning: "$medicationName" directly matches your documented allergy to "$allergy". Please consult your doctor.',
            relatedAllergy: allergy,
          ));
        }
      } else {
        final isCrossReact = _checkCrossReactivity(cleanName, cleanAllergy);
        if (isCrossReact && !flags.any((f) => f.relatedAllergy == allergy)) {
          flags.add(SafetyFlag(
            severity: FlagSeverity.critical,
            title: 'Cross-Allergy Warning',
            message:
                'Notice: "$medicationName" belongs to or shares cross-reactivity with the "$allergy" drug family. Please review with your doctor.',
            relatedAllergy: allergy,
          ));
        }
      }
    }

    // Check duplicate existing medication
    for (final existing in existingMeds) {
      final existingClean = existing.name.trim().toLowerCase();
      if (cleanName == existingClean) {
        flags.add(SafetyFlag(
          severity: FlagSeverity.warning,
          title: 'Duplicate Medication',
          message:
              'You already have an active medication record for "${existing.name}". Avoid accidental double-dosing.',
          relatedMedicationName: existing.name,
        ));
      }
    }

    return flags;
  }

  static bool _checkCrossReactivity(String drug, String allergy) {
    final pairs = [
      {'drug': 'amoxicillin', 'allergy': 'penicillin'},
      {'drug': 'ampicillin', 'allergy': 'penicillin'},
      {'drug': 'augmentin', 'allergy': 'penicillin'},
      {'drug': 'keflex', 'allergy': 'penicillin'},
      {'drug': 'cephalexin', 'allergy': 'penicillin'},
      {'drug': 'advil', 'allergy': 'ibuprofen'},
      {'drug': 'motrin', 'allergy': 'ibuprofen'},
      {'drug': 'naproxen', 'allergy': 'nsaid'},
      {'drug': 'aleve', 'allergy': 'nsaid'},
      {'drug': 'ibuprofen', 'allergy': 'nsaid'},
      {'drug': 'aspirin', 'allergy': 'nsaid'},
      {'drug': 'celebrex', 'allergy': 'sulfa'},
      {'drug': 'tylenol', 'allergy': 'paracetamol'},
      {'drug': 'panadol', 'allergy': 'paracetamol'},
      {'drug': 'acetaminophen', 'allergy': 'paracetamol'},
      {'drug': 'paracetamol', 'allergy': 'acetaminophen'},
      {'drug': 'bactrim', 'allergy': 'sulfa'},
      {'drug': 'septra', 'allergy': 'sulfa'},
    ];

    for (final p in pairs) {
      if (drug.contains(p['drug']!) && allergy.contains(p['allergy']!)) {
        return true;
      }
    }
    return false;
  }

  static String _adjustMinutes(String hhmm, int deltaMinutes) {
    try {
      final parts = hhmm.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final total = (h * 60 + m + deltaMinutes) % (24 * 60);
      final finalTotal = total < 0 ? total + (24 * 60) : total;
      final newH = finalTotal ~/ 60;
      final newM = finalTotal % 60;
      return '${newH.toString().padLeft(2, '0')}:${newM.toString().padLeft(2, '0')}';
    } catch (_) {
      return hhmm;
    }
  }

  static List<String> _distributeAcrossDay(String wake, String sleep, int count) {
    try {
      final wakeParts = wake.split(':').map(int.parse).toList();
      final sleepParts = sleep.split(':').map(int.parse).toList();
      final wakeMin = wakeParts[0] * 60 + wakeParts[1];
      var sleepMin = sleepParts[0] * 60 + sleepParts[1];
      if (sleepMin <= wakeMin) sleepMin += 24 * 60;

      final interval = (sleepMin - wakeMin) / (count + 1);
      final list = <String>[];
      for (int i = 1; i <= count; i++) {
        final total = (wakeMin + (interval * i).round()) % (24 * 60);
        final h = total ~/ 60;
        final m = total % 60;
        list.add('${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
      }
      return list;
    } catch (_) {
      return ['08:00', '20:00'];
    }
  }
}
