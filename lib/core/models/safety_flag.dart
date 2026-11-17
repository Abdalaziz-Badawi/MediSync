enum FlagSeverity { info, warning, critical }

enum AlertTier {
  tier1HardStop,     // Critical Red - Anaphylaxis, direct match, parenteral excipient
  tier2HighAdvisory, // High Orange - Significant class cross-reactivity, prominent excipient
  tier3Caution,      // Amber/Yellow - Low cross-reactivity, mild intolerance
  tier4Info,         // Slate/Blue - Educational note, routine condition
}

class SafetyFlag {
  final FlagSeverity severity;
  final AlertTier tier;
  final String title;
  final String message;
  final String? relatedAllergy;
  final String? relatedExcipient;
  final String? relatedMedicationName;
  final String? clinicalRationale;

  const SafetyFlag({
    required this.severity,
    this.tier = AlertTier.tier2HighAdvisory,
    required this.title,
    required this.message,
    this.relatedAllergy,
    this.relatedExcipient,
    this.relatedMedicationName,
    this.clinicalRationale,
  });

  Map<String, dynamic> toJson() {
    return {
      'severity': severity.name,
      'tier': tier.name,
      'title': title,
      'message': message,
      'relatedAllergy': relatedAllergy,
      'relatedExcipient': relatedExcipient,
      'relatedMedicationName': relatedMedicationName,
      'clinicalRationale': clinicalRationale,
    };
  }

  factory SafetyFlag.fromJson(Map<dynamic, dynamic> json) {
    final sevName = json['severity'] as String? ?? 'warning';
    final sev = FlagSeverity.values.firstWhere(
      (e) => e.name == sevName,
      orElse: () => FlagSeverity.warning,
    );

    final tierName = json['tier'] as String?;
    final alertTier = tierName != null
        ? AlertTier.values.firstWhere(
            (e) => e.name == tierName,
            orElse: () => sev == FlagSeverity.critical
                ? AlertTier.tier1HardStop
                : AlertTier.tier3Caution,
          )
        : (sev == FlagSeverity.critical
            ? AlertTier.tier1HardStop
            : AlertTier.tier3Caution);

    return SafetyFlag(
      severity: sev,
      tier: alertTier,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      relatedAllergy: json['relatedAllergy'] as String?,
      relatedExcipient: json['relatedExcipient'] as String?,
      relatedMedicationName: json['relatedMedicationName'] as String?,
      clinicalRationale: json['clinicalRationale'] as String?,
    );
  }
}
