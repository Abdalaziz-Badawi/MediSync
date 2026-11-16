enum FlagSeverity { info, warning, critical }

class SafetyFlag {
  final FlagSeverity severity;
  final String title;
  final String message;
  final String? relatedAllergy;
  final String? relatedMedicationName;

  const SafetyFlag({
    required this.severity,
    required this.title,
    required this.message,
    this.relatedAllergy,
    this.relatedMedicationName,
  });

  Map<String, dynamic> toJson() {
    return {
      'severity': severity.name,
      'title': title,
      'message': message,
      'relatedAllergy': relatedAllergy,
      'relatedMedicationName': relatedMedicationName,
    };
  }

  factory SafetyFlag.fromJson(Map<dynamic, dynamic> json) {
    return SafetyFlag(
      severity: FlagSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => FlagSeverity.warning,
      ),
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      relatedAllergy: json['relatedAllergy'] as String?,
      relatedMedicationName: json['relatedMedicationName'] as String?,
    );
  }
}
