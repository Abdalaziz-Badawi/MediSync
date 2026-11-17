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
  // Days of week active: 1 = Monday, 2 = Tuesday, ..., 7 = Sunday. Defaults to all 7 days.
  final List<int> daysOfWeek;
  // Inactive excipients list (for food/additive cross-reference screening)
  final List<String> inactiveExcipients;
  // Meal sync info (e.g., 'after_breakfast', 'after_lunch', 'after_dinner', 'with_meal')
  final String? mealCondition;
  // Tracks doses taken: key is "yyyy-MM-dd", value is list of times taken (e.g. ["08:00"])
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
    this.inactiveExcipients = const [],
    this.mealCondition,
    this.doseLog = const {},
  });

  bool get isOngoing => durationDays == null;

  DateTime? get endDate {
    if (durationDays == null) return null;
    return startDate.add(Duration(days: durationDays!));
  }

  bool isActiveOn(DateTime date) {
    // 1. Day of week check
    if (daysOfWeek.isNotEmpty && !daysOfWeek.contains(date.weekday)) {
      return false;
    }

    // 2. Start date check
    final startOfCheck = DateTime(date.year, date.month, date.day);
    final startOfStart = DateTime(startDate.year, startDate.month, startDate.day);
    if (startOfCheck.isBefore(startOfStart)) return false;

    // 3. Duration / end date check
    if (durationDays != null) {
      final end = endDate!;
      final startOfEnd = DateTime(end.year, end.month, end.day);
      if (startOfCheck.isAfter(startOfEnd)) return false;
    }
    return true;
  }

  bool isDoseTaken(DateTime date, String time) {
    final dateKey = _formatDateKey(date);
    return doseLog[dateKey]?.contains(time) ?? false;
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
    List<String>? inactiveExcipients,
    String? mealCondition,
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
      inactiveExcipients: inactiveExcipients ?? this.inactiveExcipients,
      mealCondition: mealCondition ?? this.mealCondition,
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
      'inactiveExcipients': inactiveExcipients,
      'mealCondition': mealCondition,
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
      inactiveExcipients: (json['inactiveExcipients'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      mealCondition: json['mealCondition'] as String?,
      doseLog: (json['doseLog'] as Map<dynamic, dynamic>?)?.map(
            (k, v) => MapEntry(
              k.toString(),
              (v as List<dynamic>).map((e) => e.toString()).toList(),
            ),
          ) ??
          {},
    );
  }

  IconData get icon {
    switch (form) {
      case MedicationForm.pill:
        return Icons.medication;
      case MedicationForm.capsule:
        return Icons.medication_liquid;
      case MedicationForm.liquid:
        return Icons.water_drop;
      case MedicationForm.injection:
        return Icons.vaccines;
      case MedicationForm.inhaler:
        return Icons.air;
      case MedicationForm.drops:
        return Icons.opacity;
      case MedicationForm.topical:
        return Icons.clean_hands;
      case MedicationForm.other:
        return Icons.healing;
    }
  }
}
