import '../data/medicines_database.dart';
import '../models/condition.dart';
import '../models/medication.dart';
import '../models/safety_flag.dart';
import '../models/side_effect.dart';
import '../models/user_profile.dart';

class CompanionMealReminder {
  final String mealName; // "Breakfast", "Lunch", "Dinner"
  final String mealTime; // "HH:mm"
  final String medicationTime; // "HH:mm"
  final String medicationName;
  final String advice;

  const CompanionMealReminder({
    required this.mealName,
    required this.mealTime,
    required this.medicationTime,
    required this.medicationName,
    required this.advice,
  });
}

class SmartScheduleResult {
  final List<String> times;
  final String rationale;
  final List<CompanionMealReminder> companionMealReminders;

  const SmartScheduleResult({
    required this.times,
    required this.rationale,
    this.companionMealReminders = const [],
  });
}

class SchedulerService {
  /// Proposes optimal schedule times with studied clinical rationales
  /// and seamless companion meal reminders.
  static SmartScheduleResult calculateSmartScheduleWithRationale({
    required int timesPerDay,
    required UserProfile profile,
    required List<SideEffect> sideEffects,
    required List<MedicationCondition> preConditions,
    required List<MedicationCondition> postConditions,
    String medicationName = '',
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
    final mealReminders = <CompanionMealReminder>[];

    if (requiresFood) {
      reasons.add(
        'Arranged 20 minutes after your meal times to naturally buffer gastric mucosa and prevent stomach discomfort without interrupting your daily flow.',
      );

      // Create companion meal reminders
      final medDisplayName = medicationName.isNotEmpty ? medicationName : 'your medication';
      for (final time in times) {
        if (time == _adjustMinutes(profile.breakfastTime, 20)) {
          mealReminders.add(CompanionMealReminder(
            mealName: 'Breakfast',
            mealTime: profile.breakfastTime,
            medicationTime: time,
            medicationName: medDisplayName,
            advice: '🍽️ Breakfast Time: Enjoy your breakfast! Remember to take $medDisplayName 20 minutes after at $time.',
          ));
        } else if (time == _adjustMinutes(profile.lunchTime, 20)) {
          mealReminders.add(CompanionMealReminder(
            mealName: 'Lunch',
            mealTime: profile.lunchTime,
            medicationTime: time,
            medicationName: medDisplayName,
            advice: '🍽️ Lunch Time: Have a nourishing meal! Your $medDisplayName dose is scheduled 20 minutes after at $time.',
          ));
        } else if (time == _adjustMinutes(profile.dinnerTime, 20)) {
          mealReminders.add(CompanionMealReminder(
            mealName: 'Dinner',
            mealTime: profile.dinnerTime,
            medicationTime: time,
            medicationName: medDisplayName,
            advice: '🍽️ Dinner Time: Enjoy your evening meal! Your $medDisplayName is planned 20 minutes after at $time.',
          ));
        }
      }
    }

    if (causesDrowsiness || beforeSleepCondition) {
      reasons.add(
        'Scheduled at bedtime (${times.last}) to leverage drowsiness safely during sleep and avoid daytime fatigue.',
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
        'Evenly spaced across your daily waking routine (${profile.wakeTime} to ${profile.sleepTime}) to maintain steady therapeutic blood levels.',
      );
    }

    return SmartScheduleResult(
      times: times,
      rationale: reasons.join('\n• '),
      companionMealReminders: mealReminders,
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

    // Aligned meal times: 20 minutes after meal time
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
        return [breakfastSlot];
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

  /// Verifies safety against user's allergies and existing medications
  /// checking active ingredients, drug classes, and inactive excipients.
  static List<SafetyFlag> checkSafety({
    required String medicationName,
    required UserProfile profile,
    List<Medication> existingMeds = const [],
    MedicineTemplate? matchedTemplate,
  }) {
    final flags = <SafetyFlag>[];
    final cleanName = medicationName.trim().toLowerCase();
    if (cleanName.isEmpty) return flags;

    // 1. Direct and Class Allergy Checks from matched template
    if (matchedTemplate != null) {
      for (final trigger in matchedTemplate.allergenTriggers) {
        for (final userAllergy in profile.allergies) {
          final cleanUserAllergy = userAllergy.trim().toLowerCase();
          if (cleanUserAllergy.isNotEmpty &&
              (trigger.contains(cleanUserAllergy) ||
                  cleanUserAllergy.contains(trigger))) {
            flags.add(SafetyFlag(
              severity: FlagSeverity.critical,
              tier: AlertTier.tier1HardStop,
              title: 'Critical Allergy Conflict (Tier 1)',
              message:
                  'Danger: "$medicationName" (${matchedTemplate.drugClass}) contains active triggers matching your allergy to "$userAllergy". Do NOT take without clinical approval.',
              relatedAllergy: userAllergy,
              clinicalRationale: 'Direct match or high structural homology with known allergen.',
            ));
            break;
          }
        }
      }

      // 2. Inactive Excipient Cross-Referencing
      _checkExcipientAllergies(
        medicationName: medicationName,
        matchedTemplate: matchedTemplate,
        userAllergies: profile.allergies,
        flags: flags,
      );
    }

    // 3. Fallback direct string match & cross-reactivity matrix
    for (final allergy in profile.allergies) {
      final cleanAllergy = allergy.trim().toLowerCase();
      if (cleanAllergy.isEmpty) continue;

      if (cleanName.contains(cleanAllergy) || cleanAllergy.contains(cleanName)) {
        if (!flags.any((f) => f.relatedAllergy == allergy)) {
          flags.add(SafetyFlag(
            severity: FlagSeverity.critical,
            tier: AlertTier.tier1HardStop,
            title: 'Direct Drug Allergy Detected (Tier 1)',
            message:
                'Warning: "$medicationName" directly matches your documented allergy to "$allergy". Please consult your doctor.',
            relatedAllergy: allergy,
          ));
        }
      } else {
        final crossResult = _checkCrossReactivity(cleanName, cleanAllergy);
        if (crossResult != null && !flags.any((f) => f.relatedAllergy == allergy)) {
          flags.add(SafetyFlag(
            severity: crossResult.severity,
            tier: crossResult.tier,
            title: crossResult.title,
            message:
                'Notice: "$medicationName" shares cross-reactivity with your "$allergy" allergy: ${crossResult.note}',
            relatedAllergy: allergy,
            clinicalRationale: crossResult.note,
          ));
        }
      }
    }

    // 4. Duplicate Existing Medication Check & Drug-Drug Interactions
    for (final existing in existingMeds) {
      final existingClean = existing.name.trim().toLowerCase();
      if (cleanName == existingClean) {
        flags.add(SafetyFlag(
          severity: FlagSeverity.warning,
          tier: AlertTier.tier2HighAdvisory,
          title: 'Duplicate Medication Warning',
          message:
              'You already have an active medication record for "${existing.name}". Avoid accidental double-dosing.',
          relatedMedicationName: existing.name,
        ));
      }
    }

    // 5. Drug-Drug Cross-Referencing & Required Spacing Analysis
    _checkDrugDrugInteractions(
      medicationName: medicationName,
      cleanName: cleanName,
      matchedTemplate: matchedTemplate,
      existingMeds: existingMeds,
      flags: flags,
    );

    return flags;
  }

  /// Fact-checks drug interactions, dangerous clinical combinations and required spacing.
  static void _checkDrugDrugInteractions({
    required String medicationName,
    required String cleanName,
    required MedicineTemplate? matchedTemplate,
    required List<Medication> existingMeds,
    required List<SafetyFlag> flags,
  }) {
    for (final existing in existingMeds) {
      final existingClean = existing.name.trim().toLowerCase();
      if (existingClean == cleanName) continue;

      // 1. NSAID + Anticoagulant/Antiplatelet
      final isNewNSAID = _isNsaid(cleanName, matchedTemplate);
      final isExistingNSAID = _isNsaid(existingClean, null);
      final isNewAnticoagulant = _isAnticoagulant(cleanName, matchedTemplate);
      final isExistingAnticoagulant = _isAnticoagulant(existingClean, null);

      if ((isNewNSAID && isExistingAnticoagulant) || (isNewAnticoagulant && isExistingNSAID)) {
        flags.add(SafetyFlag(
          severity: FlagSeverity.critical,
          tier: AlertTier.tier1HardStop,
          title: 'Critical Conflict: Major Bleeding Risk',
          message: 'DANGER: Combining "$medicationName" with "${existing.name}" dramatically heightens gastrointestinal ulceration and severe bleeding risk.',
          relatedMedicationName: existing.name,
          clinicalRationale: 'Synergistic antiplatelet and anticoagulant effects compromise mucosal hemostasis.',
        ));
      }

      // 2. Dual NSAID Therapy
      if (isNewNSAID && isExistingNSAID) {
        flags.add(SafetyFlag(
          severity: FlagSeverity.warning,
          tier: AlertTier.tier2HighAdvisory,
          title: 'Duplicate Class: Dual NSAID Warning',
          message: 'Caution: Taking "$medicationName" alongside "${existing.name}" elevates gastric and renal toxicity without extra pain relief.',
          relatedMedicationName: existing.name,
          clinicalRationale: 'Additive COX inhibition produces redundant toxicity without therapeutic synergy.',
        ));
      }

      // 3. Chelation & Absorption Spacing (Tetracyclines/Fluoroquinolones vs Calcium/Iron/Antacids)
      final isNewChelator = _isChelatorAntibiotic(cleanName, matchedTemplate);
      final isExistingChelator = _isChelatorAntibiotic(existingClean, null);
      final isNewMineral = _isMineralOrAntacid(cleanName, matchedTemplate);
      final isExistingMineral = _isMineralOrAntacid(existingClean, null);

      if ((isNewChelator && isExistingMineral) || (isNewMineral && isExistingChelator)) {
        flags.add(SafetyFlag(
          severity: FlagSeverity.warning,
          tier: AlertTier.tier2HighAdvisory,
          title: 'Absorption Conflict: Separate by ≥ 2-4 Hours',
          message: 'Spacing Required: "$medicationName" binds with multivalent cations in "${existing.name}". Separate doses by at least 2 to 4 hours.',
          relatedMedicationName: existing.name,
          clinicalRationale: 'Polyvalent metal ions (Ca, Mg, Fe, Al) form unabsorbable chelate complexes with the antibiotic.',
        ));
      }

      // 4. Thyroid Hormone Spacing (Levothyroxine vs Minerals/PPIs)
      final isNewThyroid = cleanName.contains('levothyroxine') || cleanName.contains('synthroid');
      final isExistingThyroid = existingClean.contains('levothyroxine') || existingClean.contains('synthroid');

      if ((isNewThyroid && isExistingMineral) || (isNewMineral && isExistingThyroid)) {
        flags.add(SafetyFlag(
          severity: FlagSeverity.warning,
          tier: AlertTier.tier2HighAdvisory,
          title: 'Endocrine Spacing: Separate by ≥ 4 Hours',
          message: 'Spacing Required: Taking "$medicationName" with "${existing.name}" impairs thyroid hormone uptake. Separate by at least 4 hours.',
          relatedMedicationName: existing.name,
          clinicalRationale: 'Direct chelation and altered gastric pH sharply reduce levothyroxine intestinal absorption.',
        ));
      }
    }
  }

  static bool _isNsaid(String name, MedicineTemplate? tmpl) {
    if (tmpl != null && tmpl.drugClass.toLowerCase().contains('nsaid')) return true;
    const nsaids = ['ibuprofen', 'advil', 'motrin', 'aspirin', 'naproxen', 'aleve', 'celebrex', 'celecoxib', 'diclofenac', 'voltaren', 'meloxicam'];
    return nsaids.any((n) => name.contains(n));
  }

  static bool _isAnticoagulant(String name, MedicineTemplate? tmpl) {
    if (tmpl != null && (tmpl.drugClass.toLowerCase().contains('anticoagulant') || tmpl.drugClass.toLowerCase().contains('antiplatelet'))) return true;
    const bloodThinners = ['warfarin', 'coumadin', 'eliquis', 'apixaban', 'xarelto', 'rivaroxaban', 'pradaxa', 'plavix', 'clopidogrel'];
    return bloodThinners.any((b) => name.contains(b));
  }

  static bool _isChelatorAntibiotic(String name, MedicineTemplate? tmpl) {
    const chelators = ['doxycycline', 'vibramycin', 'cipro', 'ciprofloxacin', 'levofloxacin', 'levaquin', 'tetracycline', 'minocycline'];
    return chelators.any((c) => name.contains(c));
  }

  static bool _isMineralOrAntacid(String name, MedicineTemplate? tmpl) {
    const minerals = ['calcium', 'iron', 'ferrous', 'antacid', 'tums', 'maalox', 'multivitamin', 'zinc', 'magnesium'];
    return minerals.any((m) => name.contains(m));
  }

  /// Screens inactive pharmaceutical excipients against food, additive, and animal allergies.
  static void _checkExcipientAllergies({
    required String medicationName,
    required MedicineTemplate matchedTemplate,
    required List<String> userAllergies,
    required List<SafetyFlag> flags,
  }) {
    for (final allergy in userAllergies) {
      final cleanAllergy = allergy.trim().toLowerCase();
      if (cleanAllergy.isEmpty) continue;

      for (final excipient in matchedTemplate.inactiveExcipients) {
        final cleanExcipient = excipient.toLowerCase();

        // Dairy / Milk allergy -> Lactose monohydrate check
        if ((cleanAllergy.contains('milk') || cleanAllergy.contains('dairy') || cleanAllergy.contains('lactose')) &&
            cleanExcipient.contains('lactose')) {
          final isDPI = matchedTemplate.defaultForm == MedicationForm.inhaler;
          flags.add(SafetyFlag(
            severity: isDPI ? FlagSeverity.critical : FlagSeverity.warning,
            tier: isDPI ? AlertTier.tier1HardStop : AlertTier.tier3Caution,
            title: isDPI ? 'Inhaler Lactose Warning (Tier 1)' : 'Excipient Notice: Lactose',
            message: isDPI
                ? 'Danger: "$medicationName" is a Dry Powder Inhaler containing lactose carrier, which may contain trace milk proteins known to trigger severe bronchospasm in milk allergy.'
                : 'Notice: "$medicationName" contains lactose monohydrate as a tablet filler.',
            relatedAllergy: allergy,
            relatedExcipient: excipient,
          ));
        }

        // Peanut allergy -> Peanut / Arachis oil
        if ((cleanAllergy.contains('peanut') || cleanAllergy.contains('arachis')) &&
            (cleanExcipient.contains('peanut') || cleanExcipient.contains('arachis'))) {
          flags.add(SafetyFlag(
            severity: FlagSeverity.critical,
            tier: AlertTier.tier1HardStop,
            title: 'Critical Excipient Conflict: Peanut Oil (Tier 1)',
            message: 'Danger: "$medicationName" uses peanut oil vehicle. Contraindicated in peanut allergy.',
            relatedAllergy: allergy,
            relatedExcipient: excipient,
          ));
        }

        // Sesame allergy -> Sesame oil vehicle
        if (cleanAllergy.contains('sesame') && cleanExcipient.contains('sesame')) {
          flags.add(SafetyFlag(
            severity: FlagSeverity.critical,
            tier: AlertTier.tier1HardStop,
            title: 'Critical Excipient Conflict: Sesame Oil (Tier 1)',
            message: 'Danger: "$medicationName" contains sesame oil vehicle. High anaphylaxis risk in sesame allergy.',
            relatedAllergy: allergy,
            relatedExcipient: excipient,
          ));
        }

        // Alpha-gal / Gelatin allergy -> Bovine/Porcine Gelatin
        if ((cleanAllergy.contains('gelatin') || cleanAllergy.contains('alpha-gal') || cleanAllergy.contains('pork') || cleanAllergy.contains('beef')) &&
            cleanExcipient.contains('gelatin')) {
          flags.add(SafetyFlag(
            severity: FlagSeverity.warning,
            tier: AlertTier.tier2HighAdvisory,
            title: 'Excipient Warning: Gelatin Capsule (Tier 2)',
            message: 'Caution: "$medicationName" uses a gelatin capsule shell (animal-derived). May trigger Alpha-gal or gelatin hypersensitivity.',
            relatedAllergy: allergy,
            relatedExcipient: excipient,
          ));
        }

        // Wheat / Gluten / Celiac -> Wheat starch
        if ((cleanAllergy.contains('wheat') || cleanAllergy.contains('gluten') || cleanAllergy.contains('celiac')) &&
            cleanExcipient.contains('wheat')) {
          flags.add(SafetyFlag(
            severity: FlagSeverity.critical,
            tier: AlertTier.tier1HardStop,
            title: 'Gluten / Wheat Starch Conflict (Tier 1)',
            message: 'Warning: "$medicationName" lists wheat starch as an inactive binder.',
            relatedAllergy: allergy,
            relatedExcipient: excipient,
          ));
        }

        // Egg allergy -> Egg lecithin / phosphatides
        if (cleanAllergy.contains('egg') &&
            (cleanExcipient.contains('egg') || cleanExcipient.contains('lecithin'))) {
          flags.add(SafetyFlag(
            severity: FlagSeverity.warning,
            tier: AlertTier.tier2HighAdvisory,
            title: 'Excipient Advisory: Egg Phosphatides',
            message: 'Advisory: "$medicationName" contains egg-derived emulsifiers.',
            relatedAllergy: allergy,
            relatedExcipient: excipient,
          ));
        }

        // Aspirin allergy -> Tartrazine (Yellow #5)
        if ((cleanAllergy.contains('aspirin') || cleanAllergy.contains('salicylate')) &&
            cleanExcipient.contains('tartrazine')) {
          flags.add(SafetyFlag(
            severity: FlagSeverity.warning,
            tier: AlertTier.tier2HighAdvisory,
            title: 'AERD Cross-Sensitivity: Tartrazine',
            message: 'Caution: "$medicationName" contains Tartrazine (Yellow #5), which can induce bronchospasm in aspirin-sensitive patients.',
            relatedAllergy: allergy,
            relatedExcipient: excipient,
          ));
        }

        // PKU -> Aspartame
        if ((cleanAllergy.contains('aspartame') || cleanAllergy.contains('pku') || cleanAllergy.contains('phenylketonuria')) &&
            cleanExcipient.contains('aspartame')) {
          flags.add(SafetyFlag(
            severity: FlagSeverity.critical,
            tier: AlertTier.tier1HardStop,
            title: 'PKU Warning: Contains Aspartame (Tier 1)',
            message: 'Contraindicated: "$medicationName" contains aspartame (metabolizes to phenylalanine).',
            relatedAllergy: allergy,
            relatedExcipient: excipient,
          ));
        }
      }
    }
  }

  static _CrossReactivityCheck? _checkCrossReactivity(String drug, String allergy) {
    final rules = [
      // Penicillin -> Cephalosporin (R1 side chain analysis)
      _CrossReactivityCheck(
        drugKeyword: 'amoxicillin',
        allergyKeyword: 'penicillin',
        title: 'Penicillin Class Cross-Reactivity',
        note: 'Amoxicillin is an aminopenicillin with shared beta-lactam core.',
        severity: FlagSeverity.critical,
        tier: AlertTier.tier1HardStop,
      ),
      _CrossReactivityCheck(
        drugKeyword: 'ampicillin',
        allergyKeyword: 'penicillin',
        title: 'Penicillin Class Cross-Reactivity',
        note: 'Ampicillin belongs directly to the penicillin antibiotic family.',
        severity: FlagSeverity.critical,
        tier: AlertTier.tier1HardStop,
      ),
      _CrossReactivityCheck(
        drugKeyword: 'cephalexin',
        allergyKeyword: 'penicillin',
        title: 'Beta-Lactam Side-Chain Cross-Reactivity (Tier 2)',
        note: 'Cephalexin shares identical R1 side chain with ampicillin (~5-10% cross-reactivity).',
        severity: FlagSeverity.warning,
        tier: AlertTier.tier2HighAdvisory,
      ),
      _CrossReactivityCheck(
        drugKeyword: 'keflex',
        allergyKeyword: 'penicillin',
        title: 'Beta-Lactam Side-Chain Cross-Reactivity (Tier 2)',
        note: 'Keflex (cephalexin) shares an R1 side chain with ampicillin.',
        severity: FlagSeverity.warning,
        tier: AlertTier.tier2HighAdvisory,
      ),

      // NSAIDs & Aspirin
      _CrossReactivityCheck(
        drugKeyword: 'advil',
        allergyKeyword: 'nsaid',
        title: 'NSAID Class Warning',
        note: 'Advil (Ibuprofen) is a nonsteroidal anti-inflammatory drug.',
        severity: FlagSeverity.critical,
        tier: AlertTier.tier1HardStop,
      ),
      _CrossReactivityCheck(
        drugKeyword: 'ibuprofen',
        allergyKeyword: 'aspirin',
        title: 'AERD / Salicylate Cross-Reactivity',
        note: 'Ibuprofen shares COX-1 inhibition pathway with aspirin, which can trigger bronchospasm in aspirin-sensitive individuals.',
        severity: FlagSeverity.warning,
        tier: AlertTier.tier2HighAdvisory,
      ),
      _CrossReactivityCheck(
        drugKeyword: 'aspirin',
        allergyKeyword: 'ibuprofen',
        title: 'AERD / NSAID Cross-Reactivity',
        note: 'Aspirin and Ibuprofen share cross-reactive COX-1 mechanisms.',
        severity: FlagSeverity.warning,
        tier: AlertTier.tier2HighAdvisory,
      ),

      // Sulfa
      _CrossReactivityCheck(
        drugKeyword: 'celebrex',
        allergyKeyword: 'sulfa',
        title: 'Sulfa Advisory (Tier 3)',
        note: 'Celecoxib contains a non-arylamine sulfonamide moiety. True cross-reactivity with antibiotic sulfas is low.',
        severity: FlagSeverity.info,
        tier: AlertTier.tier3Caution,
      ),
      _CrossReactivityCheck(
        drugKeyword: 'bactrim',
        allergyKeyword: 'sulfa',
        title: 'Antibacterial Sulfonamide (Tier 1)',
        note: 'Bactrim is an arylamine sulfonamide with high risk of severe hypersensitivity.',
        severity: FlagSeverity.critical,
        tier: AlertTier.tier1HardStop,
      ),

      // Paracetamol / Acetaminophen
      _CrossReactivityCheck(
        drugKeyword: 'tylenol',
        allergyKeyword: 'paracetamol',
        title: 'Generic Equivalence',
        note: 'Tylenol (Acetaminophen) is identical to Paracetamol.',
        severity: FlagSeverity.critical,
        tier: AlertTier.tier1HardStop,
      ),
      _CrossReactivityCheck(
        drugKeyword: 'panadol',
        allergyKeyword: 'acetaminophen',
        title: 'Generic Equivalence',
        note: 'Panadol (Paracetamol) is identical to Acetaminophen.',
        severity: FlagSeverity.critical,
        tier: AlertTier.tier1HardStop,
      ),
    ];

    for (final r in rules) {
      if (drug.contains(r.drugKeyword) && allergy.contains(r.allergyKeyword)) {
        return r;
      }
    }
    return null;
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

class _CrossReactivityCheck {
  final String drugKeyword;
  final String allergyKeyword;
  final String title;
  final String note;
  final FlagSeverity severity;
  final AlertTier tier;

  const _CrossReactivityCheck({
    required this.drugKeyword,
    required this.allergyKeyword,
    required this.title,
    required this.note,
    required this.severity,
    required this.tier,
  });
}
