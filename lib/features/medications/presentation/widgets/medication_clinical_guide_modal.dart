import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medisync/core/data/medicines_database.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/services/storage_service.dart';
import 'package:medisync/core/theme/app_theme.dart';

void showMedicationClinicalGuide(
  BuildContext context, {
  required String medicationName,
  Medication? medication,
  MedicineTemplate? template,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ClinicalGuideBottomSheet(
      medicationName: medicationName,
      medication: medication,
      template: template,
    ),
  );
}

class _ClinicalGuideBottomSheet extends ConsumerWidget {
  final String medicationName;
  final Medication? medication;
  final MedicineTemplate? template;

  const _ClinicalGuideBottomSheet({
    required this.medicationName,
    this.medication,
    this.template,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = AppTheme.isDark(context);
    final userProfile = ref.watch(profileNotifierProvider);
    final tmpl = template ?? MedicinesDatabase.findByName(medicationName);

    // Extract details from template or fallback to medication model
    final genericName = tmpl?.genericName ?? medication?.name ?? medicationName;
    final drugClass = tmpl?.drugClass ?? 'Pharmaceutical Agent';
    final dangerLevel = tmpl?.dangerLevel ?? DangerLevel.low;
    final rxRequirement = tmpl?.prescriptionRequirement ??
        (medication?.doctorNotes != null && medication!.doctorNotes!.isNotEmpty
            ? PrescriptionRequirement.prescription
            : PrescriptionRequirement.otc);

    final activeIngredients = tmpl?.activeIngredients.isNotEmpty == true
        ? tmpl!.activeIngredients
        : [
            if (medication != null)
              '${medication!.name} (${medication!.dosage})'
            else
              medicationName
          ];

    final cautions = tmpl?.administrationCautions.isNotEmpty == true
        ? tmpl!.administrationCautions
        : [
            '❌ NEVER crush, chew, or turn tablets into powder unless explicitly directed by a pharmacist. Swallow whole with a full glass of water.',
            '❌ Never exceed the maximum prescribed or packaged daily dosage.',
            '⚠️ Avoid consuming alcohol while taking medications unless cleared by your physician.',
          ];

    final emergencySigns = tmpl?.emergencySigns.isNotEmpty == true
        ? tmpl!.emergencySigns
        : [
            'Difficulty breathing, facial or throat swelling, severe skin rash, yellowing of skin/eyes, or sudden extreme dizziness.',
          ];

    final excipients = tmpl?.inactiveExcipients ?? (medication?.inactiveExcipients ?? []);
    final foodRules = tmpl?.foodRestrictions ?? (medication?.foodRestrictions ?? []);
    final storage = tmpl?.storageInstructions ?? 'Store below 25°C in a dry place away from direct sunlight.';
    final recovery = tmpl?.afterEffectsAndRecovery.isNotEmpty == true
        ? tmpl!.afterEffectsAndRecovery
        : 'Active therapeutic window follows standard clinical pharmacokinetic elimination.';

    // Check allergy conflict
    final cleanAllergies = userProfile.allergies.map((a) => a.trim().toLowerCase()).toList();
    final triggers = tmpl?.allergenTriggers ?? [];
    final hasAllergyConflict = triggers.any((t) => cleanAllergies.contains(t.toLowerCase())) ||
        cleanAllergies.any((a) =>
            medicationName.toLowerCase().contains(a) || genericName.toLowerCase().contains(a));

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Title Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getDangerColor(dangerLevel, isDark).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _getDangerIcon(dangerLevel),
                        color: _getDangerColor(dangerLevel, isDark),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            medicationName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                          Text(
                            genericName != medicationName
                                ? 'Generic: $genericName • $drugClass'
                                : drugClass,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      color: AppTheme.textSecondary(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Scrollable Clinical Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    // Allergy Red Flag Alert (if conflict detected)
                    if (hasAllergyConflict) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                            width: 1.5,
                          ),
                          boxShadow: AppTheme.glowShadow(AppTheme.dangerRed, opacity: 0.25),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('🚩', style: TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CRITICAL ALLERGY CONFLICT DETECTED',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'This medication or its active class matches your recorded allergy profile (${userProfile.allergies.join(", ")}). Consult your doctor or pharmacist before intake.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textPrimary(context),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Danger Level & Rx Requirement Status Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildBadgeCard(
                            context,
                            icon: _getDangerIcon(dangerLevel),
                            title: 'Safety Level',
                            subtitle: _getDangerLabel(dangerLevel),
                            color: _getDangerColor(dangerLevel, isDark),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildBadgeCard(
                            context,
                            icon: Icons.assignment_outlined,
                            title: 'Prescription',
                            subtitle: _getRxLabel(rxRequirement),
                            color: _getRxColor(rxRequirement, isDark),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // CRITICAL ADMINISTRATION CAUTIONS (DO NOTs)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFFDE68A),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Important Cautions & Dosing Rules',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...cautions.map((caution) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '• ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isDark ? Colors.amber.shade300 : const Color(0xFFB45309),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      caution,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Active Ingredients & Excipients
                    _buildSectionHeader(context, 'Active Ingredients & Formulation', Icons.biotech_outlined),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.cardBorder(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: activeIngredients.map((ing) {
                              return Chip(
                                avatar: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.teal),
                                label: Text(ing, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                backgroundColor: isDark ? const Color(0xFF134E4A) : const Color(0xFFE0F2F1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              );
                            }).toList(),
                          ),
                          if (excipients.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Inactive Excipients & Additives:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary(context)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              excipients.join(', '),
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Dietary & Meal Directives
                    if (foodRules.isNotEmpty) ...[
                      _buildSectionHeader(context, 'Dietary & Meal Rules', Icons.restaurant_outlined),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.cardBorder(context)),
                        ),
                        child: Column(
                          children: foodRules.map((rule) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.dining_rounded, size: 18, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      rule,
                                      style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(context), height: 1.35),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Emergency Symptoms (Seek ER)
                    _buildSectionHeader(context, '🚨 Emergency Signs — Seek Immediate Medical Care', Icons.emergency_outlined),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2D1515) : const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: emergencySigns.map((sign) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.local_hospital_rounded, size: 18, color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  sign,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.red.shade200 : const Color(0xFF991B1B),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Pharmacokinetics & Safe Storage
                    _buildSectionHeader(context, 'Duration, Clearance & Storage', Icons.inventory_2_outlined),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.cardBorder(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.timelapse_rounded, size: 18, color: Colors.blueAccent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Duration & Recovery: $recovery',
                                  style: TextStyle(fontSize: 12.5, color: AppTheme.textPrimary(context), height: 1.35),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.thermostat_outlined, size: 18, color: Colors.blueAccent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Storage: $storage',
                                  style: TextStyle(fontSize: 12.5, color: AppTheme.textPrimary(context), height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Missed Dose Guidance Section
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.cardBorder(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.help_outline_rounded, size: 18, color: Color(0xFF0284C7)),
                              const SizedBox(width: 8),
                              Text(
                                'Missed Dose Safety Protocol',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            medication?.missedDoseAdvice ??
                                'If within the first half of your dosing interval, take now. Never take a double dose to make up for a missed dose.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary(context),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Dismiss Button
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Noted', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadgeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary(context)),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary(context),
          ),
        ),
      ],
    );
  }

  Color _getDangerColor(DangerLevel level, bool isDark) {
    switch (level) {
      case DangerLevel.low:
        return isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
      case DangerLevel.moderate:
        return isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
      case DangerLevel.high:
        return isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
      case DangerLevel.critical:
        return isDark ? const Color(0xFFC084FC) : const Color(0xFF7E22CE);
    }
  }

  IconData _getDangerIcon(DangerLevel level) {
    switch (level) {
      case DangerLevel.low:
        return Icons.verified_user_outlined;
      case DangerLevel.moderate:
        return Icons.medical_services_outlined;
      case DangerLevel.high:
        return Icons.warning_amber_rounded;
      case DangerLevel.critical:
        return Icons.gpp_bad_outlined;
    }
  }

  String _getDangerLabel(DangerLevel level) {
    switch (level) {
      case DangerLevel.low:
        return 'Low • OTC Safe';
      case DangerLevel.moderate:
        return 'Moderate • Rx Directed';
      case DangerLevel.high:
        return 'High • Strict Adherence';
      case DangerLevel.critical:
        return 'Critical • Controlled Rx';
    }
  }

  Color _getRxColor(PrescriptionRequirement req, bool isDark) {
    switch (req) {
      case PrescriptionRequirement.otc:
        return isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
      case PrescriptionRequirement.prescription:
        return isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706);
      case PrescriptionRequirement.specialistControlled:
        return isDark ? const Color(0xFFE879F9) : const Color(0xFFA21CAF);
    }
  }

  String _getRxLabel(PrescriptionRequirement req) {
    switch (req) {
      case PrescriptionRequirement.otc:
        return 'OTC (Self-Care)';
      case PrescriptionRequirement.prescription:
        return 'Doctor Rx Required';
      case PrescriptionRequirement.specialistControlled:
        return 'Specialist Controlled';
    }
  }
}
