import 'package:flutter/material.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/theme/app_theme.dart';

/// Interactive clinical guidance sheet presented when a user marks a medication dose as missed.
/// Embodies evidence-based decision support: Halfway Rule + Never Double Up.
void showMissedDoseGuidanceSheet(
  BuildContext context, {
  required Medication medication,
  required String scheduledTime,
  required ValueChanged<DoseStatus> onSelectStatus,
}) {
  final isDark = AppTheme.isDark(context);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? const Color(0xFF151E2E) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.healing_rounded,
                      color: Color(0xFFF59E0B),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Missed Dose Clinical Guidance',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(ctx),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${medication.name} (${medication.dosage}) • Scheduled $scheduledTime',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary(ctx),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Life-Critical / High Necessity Danger Callout
              if (medication.necessityLevel == NecessityLevel.critical ||
                  medication.necessityLevel == NecessityLevel.vital) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: medication.necessityLevel.color.withValues(alpha: isDark ? 0.20 : 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: medication.necessityLevel.color.withValues(alpha: 0.6),
                      width: 1.4,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            medication.necessityLevel.icon,
                            size: 18,
                            color: medication.necessityLevel.color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              medication.necessityLevel == NecessityLevel.critical
                                  ? '🚨 LIFE-CRITICAL MEDICATION — DO NOT SKIP'
                                  : '⚠️ VITAL DAILY MEDICATION — ESSENTIAL DOSE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: medication.necessityLevel.color,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        medication.skipConsequences ??
                            'Skipping or missing this dose can trigger severe complications or sudden medical emergencies.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Specific Clinical Advice Callout
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF3C7).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.medical_information_rounded, size: 16, color: Color(0xFFD97706)),
                        SizedBox(width: 6),
                        Text(
                          'RECOMMENDED ACTION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD97706),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      medication.missedDoseAdvice,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Halfway Rule Explainer
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder(ctx)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.rule_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Halfway Rule: If you remember in the first half of your dosing interval, take it late now. If closer to your next scheduled dose, skip it. NEVER take two doses at once to make up for a missed dose.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary(ctx),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Action Options
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFFD97706)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        onSelectStatus(DoseStatus.delayed);
                      },
                      child: Text(
                        'Take Now (Late)',
                        style: TextStyle(
                          color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        backgroundColor: AppTheme.dangerRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (medication.necessityLevel == NecessityLevel.critical ||
                            medication.necessityLevel == NecessityLevel.vital) {
                          final confirmed = await showDialog<bool>(
                            context: ctx,
                            builder: (dCtx) => AlertDialog(
                              title: Row(
                                children: [
                                  Icon(
                                    medication.necessityLevel.icon,
                                    color: medication.necessityLevel.color,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Danger: Skip Dose?',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                    ),
                                  ),
                                ],
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${medication.name} is designated as ${medication.necessityLevel.label}. Skipping can have serious consequences:',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: medication.necessityLevel.color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      medication.skipConsequences ??
                                          'Missing this medication can trigger acute medical complications.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: medication.necessityLevel.color,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Are you sure you want to proceed and mark this dose as skipped?',
                                    style: TextStyle(fontSize: 12.5),
                                  ),
                                ],
                              ),
                              actions: [
                                OutlinedButton(
                                  onPressed: () => Navigator.pop(dCtx, false),
                                  child: const Text('Cancel (Keep Dose)'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.dangerRed,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => Navigator.pop(dCtx, true),
                                  child: const Text('Confirm Skip'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                        }

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        onSelectStatus(DoseStatus.missed);
                      },
                      child: const Text(
                        'Skip Dose (Missed)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
