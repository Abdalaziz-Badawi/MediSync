enum ConditionTiming { before, after }

enum ConditionType {
  meal,
  emptyStomach,
  sleep,
  drinkWater,
  rest,
  avoidDriving,
  custom,
}

class MedicationCondition {
  final ConditionType type;
  final ConditionTiming timing;
  final int? delayMinutes;
  final String description;

  const MedicationCondition({
    required this.type,
    required this.timing,
    this.delayMinutes,
    required this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'timing': timing.name,
      'delayMinutes': delayMinutes,
      'description': description,
    };
  }

  factory MedicationCondition.fromJson(Map<dynamic, dynamic> json) {
    return MedicationCondition(
      type: ConditionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ConditionType.custom,
      ),
      timing: ConditionTiming.values.firstWhere(
        (e) => e.name == json['timing'],
        orElse: () => ConditionTiming.before,
      ),
      delayMinutes: json['delayMinutes'] as int?,
      description: json['description'] as String? ?? '',
    );
  }
}
