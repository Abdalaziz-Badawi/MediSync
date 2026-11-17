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
                    Icons.medication_liquid_rounded,
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
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Medication'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 165),
              itemCount: medications.length,
              itemBuilder: (context, index) {
                final med = medications[index];
                return _MedicationCard(medication: med);
              },
            ),
      // Smart Clearance Floating Action Button (Cleanly positioned above the floating Bottom Navigation Bar)
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 92, right: 8),
          child: FloatingActionButton.extended(
            elevation: 4,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddEditMedicationPage(),
                ),
              );
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Medicine'),
          ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasCriticalFlag
              ? (isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed)
              : AppTheme.cardBorder(context),
          width: hasCriticalFlag ? 1.5 : 1,
        ),
        boxShadow: hasCriticalFlag
            ? AppTheme.glowShadow(AppTheme.dangerRed, opacity: 0.18)
            : AppTheme.softShadow(context),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
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
                          : Theme.of(context).colorScheme.primary,
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
                            const Icon(Icons.edit_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text('Edit', style: TextStyle(color: AppTheme.textPrimary(context))),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, color: AppTheme.dangerRed, size: 18),
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
                        Icon(Icons.access_time_rounded, size: 12, color: AppTheme.textMuted(context)),
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

              // Excipients & Clinical Considerations preview if available
              if (medication.inactiveExcipients.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.science_rounded,
                      size: 12,
                      color: AppTheme.textSecondary(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Excipients: ${medication.inactiveExcipients.take(3).join(', ')}${medication.inactiveExcipients.length > 3 ? '...' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Medication?'),
        content: Text('Are you sure you want to delete ${medication.name}? This will cancel all its scheduled notifications.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () {
              ref.read(medicationsNotifierProvider.notifier).remove(medication.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
