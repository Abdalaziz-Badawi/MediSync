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
        title: const Text('My Medications'),
      ),
      body: medications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.medication_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No medications added yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the button below to add your first medicine',
                    style: TextStyle(color: Colors.grey),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: medications.length,
              itemBuilder: (context, index) {
                final med = medications[index];
                return _MedicationCard(medication: med);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryTeal,
        foregroundColor: Colors.white,
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
    );
  }
}

class _MedicationCard extends ConsumerWidget {
  final Medication medication;

  const _MedicationCard({required this.medication});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCriticalFlag = medication.safetyFlags.any(
      (f) => f.severity == FlagSeverity.critical,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: hasCriticalFlag
            ? const BorderSide(color: AppTheme.dangerRed, width: 1.5)
            : BorderSide.none,
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
                          ? const Color(0xFFFFEBEE)
                          : const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      medication.icon,
                      color: hasCriticalFlag
                          ? AppTheme.dangerRed
                          : AppTheme.primaryTeal,
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
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${medication.dosage} • ${medication.timesPerDay}x daily',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
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
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
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
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppTheme.dangerRed, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          medication.safetyFlags.first.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.dangerRed,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          time,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
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
                    const Icon(Icons.info_outline, size: 14, color: AppTheme.accentCyan),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _buildConditionSummary(medication),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF00838F),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (medication.refillsRemaining != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: medication.refillsRemaining! <= 1
                            ? const Color(0xFFFFF3E0)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${medication.refillsRemaining} refills left',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: medication.refillsRemaining! <= 1
                              ? AppTheme.warningAmber
                              : Colors.grey.shade700,
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
