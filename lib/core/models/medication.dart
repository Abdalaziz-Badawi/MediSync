import 'package:flutter/material.dart';
import 'condition.dart';
import 'safety_flag.dart';
import 'side_effect.dart';

enum MedicationForm {
  pill,
  capsule,
  liquid,
  injection,
  inhaler,
  drops,
  topical,
  other,
}

enum ScheduleFrequency {
  daily,         // Every day (or specific days of week)
  weekly,        // Once or specific days every week
  biWeekly,      // Every 2 weeks (alternate weeks)
  everyXWeeks,   // Every X weeks (custom week interval)
  monthly,       // Once a month (e.g. 1st or custom day of month)
  twiceMonthly,  // Twice a month (e.g. 1st and 15th)
  everyXMonths,  // Every X months (e.g. every 2, 3, 6 months)
  everyXDays,    // Every X days (e.g. every 2 or 3 days)
  asNeeded,      // PRN / As Needed
}

enum DoseStatus {
  pending,    // Scheduled, not taken yet
  taken,      // Taken on time
  delayed,    // Taken delayed / late
  missed,     // Missed dosing window
  notNeeded,  // As needed / PRN medication was not required / skipped
  takenEarly, // Taken early ahead of scheduled time slot
}

/// Clinical necessity level dictating adherence strictness and skip safety gating.
enum NecessityLevel {
  critical, // Life-critical (insulin, anticoagulants, antiarrhythmics, immunosuppressants, antiepileptics). Unsafe to skip.
  vital,    // Vital / Essential (antihypertensives, antibiotics, psychiatric medications, hormones).
  moderate, // Maintenance / Symptom control (statins, daily PPIs, maintenance allergy).
  low,      // Symptomatic / PRN / OTC (analgesics, PRN antacids, vitamins).
}

extension NecessityLevelExtension on NecessityLevel {
  String get label {
    switch (this) {
      case NecessityLevel.critical:
        return 'Life-Critical';
      case NecessityLevel.vital:
        return 'Vital';
      case NecessityLevel.moderate:
        return 'Moderate';
      case NecessityLevel.low:
        return 'Symptomatic';
    }
  }

  String get displayName => label;

  String get badgeText {
    switch (this) {
      case NecessityLevel.critical:
        return '🚨 Life-Critical • Unsafe to Skip';
      case NecessityLevel.vital:
        return '⚡ Vital Dose • Essential';
      case NecessityLevel.moderate:
        return '🛡️ Standard Maintenance';
      case NecessityLevel.low:
        return '🟢 Symptomatic / PRN';
    }
  }

  Color get color {
    switch (this) {
      case NecessityLevel.critical:
        return const Color(0xFFDC2626); // Crimson Red
      case NecessityLevel.vital:
        return const Color(0xFFEA580C); // Vibrant Orange
      case NecessityLevel.moderate:
        return const Color(0xFF2563EB); // Royal Blue
      case NecessityLevel.low:
        return const Color(0xFF16A34A); // Emerald Green
    }
  }

  IconData get icon {
    switch (this) {
      case NecessityLevel.critical:
        return Icons.warning_amber_rounded;
      case NecessityLevel.vital:
        return Icons.priority_high_rounded;
      case NecessityLevel.moderate:
        return Icons.info_outline_rounded;
      case NecessityLevel.low:
        return Icons.check_circle_outline_rounded;
    }
  }

  String get description {
    switch (this) {
      case NecessityLevel.critical:
        return 'Unsafe to skip. Missing or delaying this medication causes acute, dangerous clinical complications.';
      case NecessityLevel.vital:
        return 'Essential daily therapy. Missing impacts clinical control, disease progression, or triggers rebound.';
      case NecessityLevel.moderate:
        return 'Standard maintenance. Consistent adherence delivers optimal long-term therapeutic outcomes.';
      case NecessityLevel.low:
        return 'Symptomatic / as-needed medication. Can be skipped safely when symptoms are absent.';
    }
  }
}

class Medication {
  final String id;
  final String name;
  final String dosage;
  final MedicationForm form;
  final int timesPerDay;
  final List<String> scheduledTimes; // formatted as "HH:mm" (24h)
  final int? durationDays; // null if ongoing
  final DateTime startDate;
  final List<MedicationCondition> preConditions;
  final List<MedicationCondition> postConditions;
  final List<SideEffect> sideEffects;
  final int? refillsRemaining;
  final int? refillAlertThreshold;
  final String? doctorNotes;
  final bool isVerified;
  final List<SafetyFlag> safetyFlags;
  // Days of week active: 1 = Monday, ..., 7 = Sunday.
  final List<int> daysOfWeek;
  // Scheduling frequency details
  final ScheduleFrequency scheduleFrequency;
  final int? intervalDays; // Used for everyXDays (e.g. 2, 3, 5)
  final int? intervalWeeks; // Used for everyXWeeks (e.g. 2, 3, 4)
  final List<int> monthlyDays; // Used for monthly / twiceMonthly (e.g. [1] or [1, 15])
  final int? intervalMonths; // Used for everyXMonths (e.g. 2, 3, 6)
  // Therapeutic category / drug class for clinical styling and guidance
  final String? category;
  // Package-based refill runway
  final int? packageSize; // Total commercial pack quantity (e.g. 30, 60 pills)
  final int? pillsRemaining; // Current live supply
  // Food & Dietary restrictions (e.g. avoid grapefruit, avoid dairy for 2h)
  final List<String> foodRestrictions;
  // Inactive excipients list (for food/additive cross-reference screening)
  final List<String> inactiveExcipients;
  // Meal sync info (e.g., 'after_breakfast', 'after_lunch', 'after_dinner', 'with_meal')
  final String? mealCondition;
  // Clinical necessity level & dangerous skip consequences
  final NecessityLevel necessityLevel;
  final String? skipConsequences;
  final bool isDiligentReminder;
  // Discontinuation: if stopped from a certain date forward, past logs are preserved but future schedules are inactive
  final DateTime? discontinuedDate;
  final String? discontinuationReason;
  // Tracks doses taken/delayed/missed: key is "yyyy-MM-dd", value is list of times (e.g. ["08:00", "20:00:delayed", "14:00:missed"])
  final Map<String, List<String>> doseLog;

  const Medication({
    required this.id,
    required this.name,
    required this.dosage,
    this.form = MedicationForm.pill,
    required this.timesPerDay,
    required this.scheduledTimes,
    this.durationDays,
    required this.startDate,
    this.preConditions = const [],
    this.postConditions = const [],
    this.sideEffects = const [],
    this.refillsRemaining,
    this.refillAlertThreshold,
    this.doctorNotes,
    this.isVerified = false,
    this.safetyFlags = const [],
    this.daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
    this.scheduleFrequency = ScheduleFrequency.daily,
    this.intervalDays,
    this.intervalWeeks,
    this.monthlyDays = const [1],
    this.intervalMonths,
    this.category,
    this.packageSize,
    this.pillsRemaining,
    this.foodRestrictions = const [],
    this.inactiveExcipients = const [],
    this.mealCondition,
    this.necessityLevel = NecessityLevel.moderate,
    this.skipConsequences,
    this.isDiligentReminder = false,
    this.discontinuedDate,
    this.discontinuationReason,
    this.doseLog = const {},
  });

  bool get isOngoing => durationDays == null;

  bool get isDiscontinued => discontinuedDate != null;

  DateTime? get endDate {
    if (durationDays == null) return null;
    return startDate.add(Duration(days: durationDays!));
  }

  bool isActiveOn(DateTime date) {
    final startOfCheck = DateTime(date.year, date.month, date.day);

    // 0. Discontinuation check: if discontinued, it is completely removed from all future dates
    // and is no longer active on or after the day it was discontinued.
    if (isDiscontinued) {
      if (discontinuedDate != null) {
        final endOfDiscontinueDay = DateTime(
          discontinuedDate!.year,
          discontinuedDate!.month,
          discontinuedDate!.day,
        );
        // Inactive on or after discontinuation day; active only for historical records prior to discontinuation
        if (startOfCheck.isAfter(endOfDiscontinueDay) || startOfCheck.isAtSameMomentAs(endOfDiscontinueDay)) {
          return false;
        }
      } else {
        return false;
      }
    }

    // 1. Start date check
    final startOfStart = DateTime(startDate.year, startDate.month, startDate.day);
    if (startOfCheck.isBefore(startOfStart)) return false;

    // 2. Duration / end date check
    if (durationDays != null) {
      final end = endDate!;
      final startOfEnd = DateTime(end.year, end.month, end.day);
      if (startOfCheck.isAfter(startOfEnd)) return false;
    }

    // 3. Frequency-specific rules
    switch (scheduleFrequency) {
      case ScheduleFrequency.asNeeded:
        return true; // PRN is active every day

      case ScheduleFrequency.daily:
      case ScheduleFrequency.weekly:
        if (daysOfWeek.isNotEmpty && !daysOfWeek.contains(date.weekday)) {
          return false;
        }
        return true;

      case ScheduleFrequency.biWeekly:
        if (daysOfWeek.isNotEmpty && !daysOfWeek.contains(date.weekday)) {
          return false;
        }
        final weekDiff = startOfCheck.difference(startOfStart).inDays ~/ 7;
        return weekDiff % 2 == 0;

      case ScheduleFrequency.everyXWeeks:
        if (daysOfWeek.isNotEmpty && !daysOfWeek.contains(date.weekday)) {
          return false;
        }
        final intervalW = (intervalWeeks != null && intervalWeeks! > 0) ? intervalWeeks! : 2;
        final weekDiff = startOfCheck.difference(startOfStart).inDays ~/ 7;
        return weekDiff >= 0 && (weekDiff % intervalW == 0);

      case ScheduleFrequency.monthly:
        final days = monthlyDays.isNotEmpty ? monthlyDays : [startOfStart.day];
        return days.contains(date.day);

      case ScheduleFrequency.twiceMonthly:
        final days = monthlyDays.isNotEmpty ? monthlyDays : [1, 15];
        return days.contains(date.day);

      case ScheduleFrequency.everyXMonths:
        final intervalM = (intervalMonths != null && intervalMonths! > 0) ? intervalMonths! : 3;
        final monthDiff = (date.year - startDate.year) * 12 + (date.month - startDate.month);
        final days = monthlyDays.isNotEmpty ? monthlyDays : [startOfStart.day];
        return monthDiff >= 0 && (monthDiff % intervalM == 0) && days.contains(date.day);

      case ScheduleFrequency.everyXDays:
        final interval = (intervalDays != null && intervalDays! > 1) ? intervalDays! : 2;
        final dayDiff = startOfCheck.difference(startOfStart).inDays;
        return dayDiff >= 0 && (dayDiff % interval == 0);
    }
  }

  /// Dynamic clinical description of the schedule frequency
  String get frequencyDisplay {
    if (isDiscontinued) return 'Discontinued';
    switch (scheduleFrequency) {
      case ScheduleFrequency.asNeeded:
        return 'As Needed (PRN)';
      case ScheduleFrequency.daily:
        if (daysOfWeek.length == 7 || daysOfWeek.isEmpty) {
          return timesPerDay == 1 ? 'Once daily' : '${timesPerDay}x daily';
        }
        return '${_formatDaysOfWeek(daysOfWeek)} • ${timesPerDay}x';
      case ScheduleFrequency.everyXDays:
        final days = (intervalDays != null && intervalDays! > 1) ? intervalDays! : 2;
        return 'Every $days days • ${timesPerDay}x';
      case ScheduleFrequency.weekly:
        return 'Weekly (${_formatDaysOfWeek(daysOfWeek)}) • ${timesPerDay}x';
      case ScheduleFrequency.biWeekly:
        return 'Every 2 weeks (${_formatDaysOfWeek(daysOfWeek)}) • ${timesPerDay}x';
      case ScheduleFrequency.everyXWeeks:
        final weeks = (intervalWeeks != null && intervalWeeks! > 0) ? intervalWeeks! : 2;
        return 'Every $weeks weeks (${_formatDaysOfWeek(daysOfWeek)}) • ${timesPerDay}x';
      case ScheduleFrequency.monthly:
        final days = monthlyDays.isNotEmpty ? monthlyDays.join(', ') : '${startDate.day}';
        return 'Monthly (Day $days) • ${timesPerDay}x';
      case ScheduleFrequency.twiceMonthly:
        final days = monthlyDays.isNotEmpty ? monthlyDays.join(', ') : '1, 15';
        return 'Twice a month (Days $days) • ${timesPerDay}x';
      case ScheduleFrequency.everyXMonths:
        final months = (intervalMonths != null && intervalMonths! > 0) ? intervalMonths! : 3;
        final days = monthlyDays.isNotEmpty ? monthlyDays.join(', ') : '${startDate.day}';
        return 'Every $months months (Day $days) • ${timesPerDay}x';
    }
  }

  static String _formatDaysOfWeek(List<int> days) {
    if (days.isEmpty || days.length == 7) return 'Daily';
    const dayNames = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
    final sorted = List<int>.from(days)..sort();
    return sorted.map((d) => dayNames[d] ?? '').where((s) => s.isNotEmpty).join(', ');
  }

  /// Refill runway calculations
  int get estimatedDosesRemaining {
    if (pillsRemaining != null) return pillsRemaining!;
    if (packageSize != null) {
      final totalTaken = continuityStats['taken'] ?? 0;
      final rem = packageSize! - totalTaken;
      return rem > 0 ? rem : 0;
    }
    return 30; // Default estimate
  }

  int get estimatedDaysRemaining {
    final dosesPerDay = timesPerDay > 0 ? timesPerDay : 1;
    return (estimatedDosesRemaining / dosesPerDay).ceil();
  }

  bool get isLowSupply => estimatedDaysRemaining <= 7;

  /// Evidence-based clinical guidance for missed doses
  String get missedDoseAdvice {
    final cat = (category ?? '').toLowerCase();
    if (cat.contains('insulin') || form == MedicationForm.injection) {
      return 'Check blood glucose first before taking a corrective dose. Do not take extra units without medical guidance.';
    }
    if (timesPerDay == 1) {
      return 'If within 12 hours of the missed time, take it now. If closer to your next scheduled dose, skip it. Never take a double dose.';
    } else if (timesPerDay == 2) {
      return 'If within 4-6 hours of scheduled time, take now. Otherwise, skip and wait for the next scheduled dose. Never take two doses at once.';
    } else {
      return 'Take as soon as remembered if not close to the next dose. If your next dose is in < 2 hours, skip the missed dose. Never double up.';
    }
  }

  /// Harmonic clinical theme color based on drug category and physical form
  Color get categoryColor {
    final cat = (category ?? '').toLowerCase();
    if (cat.contains('cardio') || cat.contains('blood pressure') || cat.contains('hyperten') || cat.contains('heart')) {
      return const Color(0xFFE11D48); // Rose Ruby
    }
    if (cat.contains('anti') || cat.contains('infect') || cat.contains('penicillin') || cat.contains('bacter')) {
      return const Color(0xFF0D9488); // Teal
    }
    if (cat.contains('pain') || cat.contains('analgesic') || cat.contains('headache') || cat.contains('nsaid')) {
      return const Color(0xFF0284C7); // Ocean Blue
    }
    if (cat.contains('diabet') || cat.contains('metabol') || cat.contains('insulin') || cat.contains('sugar')) {
      return const Color(0xFF7C3AED); // Violet
    }
    if (cat.contains('respir') || cat.contains('asthma') || cat.contains('inhal') || cat.contains('lung')) {
      return const Color(0xFF059669); // Emerald Mint
    }
    if (cat.contains('stomach') || cat.contains('gastro') || cat.contains('gerd') || cat.contains('ulcer')) {
      return const Color(0xFFD97706); // Amber
    }
    if (cat.contains('nerve') || cat.contains('psych') || cat.contains('sleep') || cat.contains('sedat')) {
      return const Color(0xFF4F46E5); // Indigo
    }

    // Fallback based on form
    switch (form) {
      case MedicationForm.pill:
        return const Color(0xFF0D9488); // Teal
      case MedicationForm.capsule:
        return const Color(0xFF2563EB); // Royal Blue
      case MedicationForm.liquid:
        return const Color(0xFF0284C7); // Cyan
      case MedicationForm.injection:
        return const Color(0xFFDC2626); // Crimson
      case MedicationForm.inhaler:
        return const Color(0xFF059669); // Mint
      case MedicationForm.drops:
        return const Color(0xFF0891B2); // Deep Cyan
      case MedicationForm.topical:
        return const Color(0xFFD97706); // Amber
      case MedicationForm.other:
        return const Color(0xFF475569); // Slate
    }
  }

  Color categoryBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return categoryColor.withValues(alpha: isDark ? 0.14 : 0.07);
  }

  /// Returns the clinical intake status for a specific dose time.
  DoseStatus getDoseStatus(DateTime date, String time) {
    final dateKey = _formatDateKey(date);
    final entries = doseLog[dateKey];
    if (entries == null || entries.isEmpty) return DoseStatus.pending;

    for (final entry in entries) {
      if (entry == time || entry == '$time:taken') {
        return DoseStatus.taken;
      }
      if (entry == '$time:delayed') {
        return DoseStatus.delayed;
      }
      if (entry == '$time:missed') {
        return DoseStatus.missed;
      }
      if (entry == '$time:notNeeded' || entry == '$time:not_needed' || entry == '$time:skipped') {
        return DoseStatus.notNeeded;
      }
      if (entry == '$time:takenEarly' || entry == '$time:early') {
        return DoseStatus.takenEarly;
      }
    }
    return DoseStatus.pending;
  }

  /// Calculates the most recent timestamp this medication was taken or delayed.
  DateTime? get lastTakenDateTime {
    DateTime? latest;
    for (final entry in doseLog.entries) {
      final dateParts = entry.key.split('-');
      if (dateParts.length != 3) continue;
      final y = int.tryParse(dateParts[0]);
      final m = int.tryParse(dateParts[1]);
      final d = int.tryParse(dateParts[2]);
      if (y == null || m == null || d == null) continue;

      for (final logItem in entry.value) {
        if (logItem.endsWith(':missed') || logItem.endsWith(':notNeeded') || logItem.endsWith(':not_needed')) {
          continue;
        }
        final timeStr = logItem.split(':').take(2).join(':');
        final timeParts = timeStr.split(':');
        final hr = timeParts.isNotEmpty ? (int.tryParse(timeParts[0]) ?? 0) : 0;
        final min = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;

        final dt = DateTime(y, m, d, hr, min);
        if (latest == null || dt.isAfter(latest)) {
          latest = dt;
        }
      }
    }
    return latest;
  }

  /// Returns total counts for adherence continuity calculations:
  /// {'taken': X, 'takenEarly': Y, 'delayed': Z, 'missed': W, 'notNeeded': V}
  Map<String, int> get continuityStats {
    int taken = 0;
    int takenEarly = 0;
    int delayed = 0;
    int missed = 0;
    int notNeeded = 0;

    for (final entries in doseLog.values) {
      for (final item in entries) {
        if (item.endsWith(':missed')) {
          missed++;
        } else if (item.endsWith(':delayed')) {
          delayed++;
        } else if (item.endsWith(':notNeeded') || item.endsWith(':not_needed')) {
          notNeeded++;
        } else if (item.endsWith(':takenEarly')) {
          takenEarly++;
          taken++;
        } else {
          taken++;
        }
      }
    }

    return {
      'taken': taken,
      'takenEarly': takenEarly,
      'delayed': delayed,
      'missed': missed,
      'notNeeded': notNeeded,
    };
  }

  bool isDoseTaken(DateTime date, String time) {
    final status = getDoseStatus(date, time);
    return status == DoseStatus.taken ||
        status == DoseStatus.delayed ||
        status == DoseStatus.takenEarly;
  }

  /// Returns true if this dose is resolved (taken, delayed, missed, or marked not needed).
  /// Only unresolved (pending) doses should count as upcoming or overdue.
  bool isDoseResolved(DateTime date, String time) {
    final status = getDoseStatus(date, time);
    return status != DoseStatus.pending;
  }

  static String _formatDateKey(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  Medication copyWith({
    String? id,
    String? name,
    String? dosage,
    MedicationForm? form,
    int? timesPerDay,
    List<String>? scheduledTimes,
    int? durationDays,
    DateTime? startDate,
    List<MedicationCondition>? preConditions,
    List<MedicationCondition>? postConditions,
    List<SideEffect>? sideEffects,
    int? refillsRemaining,
    int? refillAlertThreshold,
    String? doctorNotes,
    bool? isVerified,
    List<SafetyFlag>? safetyFlags,
    List<int>? daysOfWeek,
    ScheduleFrequency? scheduleFrequency,
    int? intervalDays,
    int? intervalWeeks,
    List<int>? monthlyDays,
    int? intervalMonths,
    String? category,
    int? packageSize,
    int? pillsRemaining,
    List<String>? foodRestrictions,
    List<String>? inactiveExcipients,
    String? mealCondition,
    NecessityLevel? necessityLevel,
    String? skipConsequences,
    bool? isDiligentReminder,
    DateTime? discontinuedDate,
    String? discontinuationReason,
    Map<String, List<String>>? doseLog,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      form: form ?? this.form,
      timesPerDay: timesPerDay ?? this.timesPerDay,
      scheduledTimes: scheduledTimes ?? this.scheduledTimes,
      durationDays: durationDays ?? this.durationDays,
      startDate: startDate ?? this.startDate,
      preConditions: preConditions ?? this.preConditions,
      postConditions: postConditions ?? this.postConditions,
      sideEffects: sideEffects ?? this.sideEffects,
      refillsRemaining: refillsRemaining ?? this.refillsRemaining,
      refillAlertThreshold: refillAlertThreshold ?? this.refillAlertThreshold,
      doctorNotes: doctorNotes ?? this.doctorNotes,
      isVerified: isVerified ?? this.isVerified,
      safetyFlags: safetyFlags ?? this.safetyFlags,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      scheduleFrequency: scheduleFrequency ?? this.scheduleFrequency,
      intervalDays: intervalDays ?? this.intervalDays,
      intervalWeeks: intervalWeeks ?? this.intervalWeeks,
      monthlyDays: monthlyDays ?? this.monthlyDays,
      intervalMonths: intervalMonths ?? this.intervalMonths,
      category: category ?? this.category,
      packageSize: packageSize ?? this.packageSize,
      pillsRemaining: pillsRemaining ?? this.pillsRemaining,
      foodRestrictions: foodRestrictions ?? this.foodRestrictions,
      inactiveExcipients: inactiveExcipients ?? this.inactiveExcipients,
      mealCondition: mealCondition ?? this.mealCondition,
      necessityLevel: necessityLevel ?? this.necessityLevel,
      skipConsequences: skipConsequences ?? this.skipConsequences,
      isDiligentReminder: isDiligentReminder ?? this.isDiligentReminder,
      discontinuedDate: discontinuedDate ?? this.discontinuedDate,
      discontinuationReason: discontinuationReason ?? this.discontinuationReason,
      doseLog: doseLog ?? this.doseLog,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'form': form.name,
      'timesPerDay': timesPerDay,
      'scheduledTimes': scheduledTimes,
      'durationDays': durationDays,
      'startDate': startDate.toIso8601String(),
      'preConditions': preConditions.map((c) => c.toJson()).toList(),
      'postConditions': postConditions.map((c) => c.toJson()).toList(),
      'sideEffects': sideEffects.map((s) => s.toJson()).toList(),
      'refillsRemaining': refillsRemaining,
      'refillAlertThreshold': refillAlertThreshold,
      'doctorNotes': doctorNotes,
      'isVerified': isVerified,
      'safetyFlags': safetyFlags.map((f) => f.toJson()).toList(),
      'daysOfWeek': daysOfWeek,
      'scheduleFrequency': scheduleFrequency.name,
      'intervalDays': intervalDays,
      'intervalWeeks': intervalWeeks,
      'monthlyDays': monthlyDays,
      'intervalMonths': intervalMonths,
      'category': category,
      'packageSize': packageSize,
      'pillsRemaining': pillsRemaining,
      'foodRestrictions': foodRestrictions,
      'inactiveExcipients': inactiveExcipients,
      'mealCondition': mealCondition,
      'necessityLevel': necessityLevel.name,
      'skipConsequences': skipConsequences,
      'isDiligentReminder': isDiligentReminder,
      'discontinuedDate': discontinuedDate?.toIso8601String(),
      'discontinuationReason': discontinuationReason,
      'doseLog': doseLog,
    };
  }

  factory Medication.fromJson(Map<dynamic, dynamic> json) {
    return Medication(
      id: json['id'] as String,
      name: json['name'] as String,
      dosage: json['dosage'] as String,
      form: MedicationForm.values.firstWhere(
        (e) => e.name == json['form'],
        orElse: () => MedicationForm.pill,
      ),
      timesPerDay: json['timesPerDay'] as int? ?? 1,
      scheduledTimes: (json['scheduledTimes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      durationDays: json['durationDays'] as int?,
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : DateTime.now(),
      preConditions: (json['preConditions'] as List<dynamic>?)
              ?.map((e) => MedicationCondition.fromJson(e as Map<dynamic, dynamic>))
              .toList() ??
          [],
      postConditions: (json['postConditions'] as List<dynamic>?)
              ?.map((e) => MedicationCondition.fromJson(e as Map<dynamic, dynamic>))
              .toList() ??
          [],
      sideEffects: (json['sideEffects'] as List<dynamic>?)
              ?.map((e) => SideEffect.fromJson(e as Map<dynamic, dynamic>))
              .toList() ??
          [],
      refillsRemaining: json['refillsRemaining'] as int?,
      refillAlertThreshold: json['refillAlertThreshold'] as int?,
      doctorNotes: json['doctorNotes'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      safetyFlags: (json['safetyFlags'] as List<dynamic>?)
              ?.map((e) => SafetyFlag.fromJson(e as Map<dynamic, dynamic>))
              .toList() ??
          [],
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [1, 2, 3, 4, 5, 6, 7],
      scheduleFrequency: ScheduleFrequency.values.firstWhere(
        (e) => e.name == json['scheduleFrequency'],
        orElse: () => ScheduleFrequency.daily,
      ),
      intervalDays: json['intervalDays'] as int?,
      intervalWeeks: json['intervalWeeks'] as int?,
      monthlyDays: (json['monthlyDays'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [1],
      intervalMonths: json['intervalMonths'] as int?,
      category: json['category'] as String?,
      packageSize: json['packageSize'] as int?,
      pillsRemaining: json['pillsRemaining'] as int?,
      foodRestrictions: (json['foodRestrictions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      inactiveExcipients: (json['inactiveExcipients'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      mealCondition: json['mealCondition'] as String?,
      necessityLevel: json['necessityLevel'] != null
          ? NecessityLevel.values.firstWhere(
              (e) => e.name == json['necessityLevel'],
              orElse: () => NecessityLevel.moderate,
            )
          : NecessityLevel.moderate,
      skipConsequences: json['skipConsequences'] as String?,
      isDiligentReminder: json['isDiligentReminder'] as bool? ?? false,
      discontinuedDate: json['discontinuedDate'] != null
          ? DateTime.parse(json['discontinuedDate'] as String)
          : null,
      discontinuationReason: json['discontinuationReason'] as String?,
      doseLog: (json['doseLog'] as Map<dynamic, dynamic>?)?.map(
            (k, v) => MapEntry(
              k.toString(),
              (v as List<dynamic>).map((e) => e.toString()).toList(),
            ),
          ) ??
          {},
    );
  }

  /// Rounder, softer iconography for modern, approachable medical UX
  IconData get icon {
    switch (form) {
      case MedicationForm.pill:
        return Icons.medication_rounded;
      case MedicationForm.capsule:
        return Icons.medication_liquid_rounded;
      case MedicationForm.liquid:
        return Icons.water_drop_rounded;
      case MedicationForm.injection:
        return Icons.vaccines_rounded;
      case MedicationForm.inhaler:
        return Icons.air_rounded;
      case MedicationForm.drops:
        return Icons.opacity_rounded;
      case MedicationForm.topical:
        return Icons.clean_hands_rounded;
      case MedicationForm.other:
        return Icons.healing_rounded;
    }
  }

  /// Alias for form-specific micro icon badge
  IconData get formIcon => icon;
}
