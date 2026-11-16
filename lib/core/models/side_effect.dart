enum SideEffectType {
  drowsiness,
  stomachUpset,
  nausea,
  dizziness,
  insomnia,
  headache,
  dryMouth,
  custom,
}

enum ScheduleHint {
  scheduleNearBedtime,
  scheduleAfterMeal,
  scheduleMorning,
  avoidBeforeDriving,
  none,
}

class SideEffect {
  final SideEffectType type;
  final String description;
  final ScheduleHint scheduleHint;

  const SideEffect({
    required this.type,
    required this.description,
    this.scheduleHint = ScheduleHint.none,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'description': description,
      'scheduleHint': scheduleHint.name,
    };
  }

  factory SideEffect.fromJson(Map<dynamic, dynamic> json) {
    return SideEffect(
      type: SideEffectType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SideEffectType.custom,
      ),
      description: json['description'] as String? ?? '',
      scheduleHint: ScheduleHint.values.firstWhere(
        (e) => e.name == json['scheduleHint'],
        orElse: () => ScheduleHint.none,
      ),
    );
  }

  static ScheduleHint defaultHintFor(SideEffectType type) {
    switch (type) {
      case SideEffectType.drowsiness:
        return ScheduleHint.scheduleNearBedtime;
      case SideEffectType.stomachUpset:
      case SideEffectType.nausea:
        return ScheduleHint.scheduleAfterMeal;
      case SideEffectType.insomnia:
        return ScheduleHint.scheduleMorning;
      case SideEffectType.dizziness:
        return ScheduleHint.avoidBeforeDriving;
      default:
        return ScheduleHint.none;
    }
  }
}
