import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/models/safety_flag.dart';
import 'package:medisync/core/services/storage_service.dart';
import 'package:medisync/core/theme/app_theme.dart';
import 'package:medisync/features/medications/presentation/pages/add_edit_medication_page.dart';
import 'package:medisync/features/medications/presentation/pages/medication_details_page.dart';

class MedicationsListPage extends ConsumerWidget {
  const MedicationsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medications = ref.watch(medicationsNotifierProvider);
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Medications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary(context),
          ),
        ),
      ),
      body: medications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.medication_outlined,
                    size: 80,
                    color: AppTheme.textMuted(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No medications added yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the button below to add your first medicine',
                    style: TextStyle(color: AppTheme.textSecondary(context)),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddEditMedicationPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Medication'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: medications.length,
              itemBuilder: (context, index) {
                final med = medications[index];
                return _MedicationCard(medication: med);
              },
            ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 76),
        child: FloatingActionButton.extended(
          backgroundColor: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
          foregroundColor: isDark ? const Color(0xFF042F2E) : Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AddEditMedicationPage(),
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Medicine'),
        ),
      ),
    );
  }
}

class _MedicationCard extends ConsumerWidget {
  final Medication medication;

  const _MedicationCard({required this.medication});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = AppTheme.isDark(context);
    final hasCriticalFlag = medication.safetyFlags.any(
      (f) => f.severity == FlagSeverity.critical,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasCriticalFlag
              ? (isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed)
              : AppTheme.cardBorder(context),
          width: hasCriticalFlag ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MedicationDetailsPage(medication: medication),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row: Icon + Name/Dosage + More menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: hasCriticalFlag
                          ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2))
                          : AppTheme.surfaceVariant(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      medication.icon,
                      color: hasCriticalFlag
                          ? (isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed)
                          : (isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medication.name,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${medication.dosage} • ${medication.timesPerDay}x daily',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    color: AppTheme.cardColor(context),
                    onSelected: (val) {
                      if (val == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddEditMedicationPage(
                              medicationToEdit: medication,
                            ),
                          ),
                        );
                      } else if (val == 'delete') {
                        _showDeleteConfirm(context, ref);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit, size: 18),
                            const SizedBox(width: 8),
                            Text('Edit', style: TextStyle(color: AppTheme.textPrimary(context))),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: AppTheme.dangerRed, size: 18),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: AppTheme.dangerRed)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Allergy / Conflict notice
              if (hasCriticalFlag) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          medication.safetyFlags.first.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              // Scheduled dose times chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: medication.scheduledTimes.map((time) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant(context),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, size: 12, color: AppTheme.textMuted(context)),
                        const SizedBox(width: 4),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 10),
              // Conditions & Info summary
              Row(
                children: [
                  if (medication.preConditions.isNotEmpty ||
                      medication.postConditions.isNotEmpty) ...[
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: isDark ? AppTheme.secondaryCyanLight : AppTheme.secondaryCyan,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _buildConditionSummary(medication),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.secondaryCyanLight : AppTheme.secondaryCyan,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (medication.refillsRemaining != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: medication.refillsRemaining! <= 1
                            ? (isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7))
                            : AppTheme.surfaceVariant(context),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${medication.refillsRemaining} refills left',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: medication.refillsRemaining! <= 1
                              ? (isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber)
                              : AppTheme.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildConditionSummary(Medication med) {
    final parts = <String>[];
    for (final c in med.preConditions) {
      parts.add('Before: ${c.description}');
    }
    for (final c in med.postConditions) {
      parts.add('After: ${c.description}');
    }
    return parts.join(' • ');
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Medication?'),
        content: Text('Are you sure you want to remove ${medication.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () {
              ref
                  .read(medicationsNotifierProvider.notifier)
                  .remove(medication.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
