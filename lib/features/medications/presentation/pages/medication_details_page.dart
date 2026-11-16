import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/models/safety_flag.dart';
import 'package:medisync/core/theme/app_theme.dart';
import 'package:medisync/features/medications/presentation/pages/add_edit_medication_page.dart';

class MedicationDetailsPage extends ConsumerWidget {
  final Medication medication;

  const MedicationDetailsPage({super.key, required this.medication});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(medication.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AddEditMedicationPage(medicationToEdit: medication),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      medication.icon,
                      color: AppTheme.primaryTeal,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medication.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${medication.dosage} • ${medication.form.name.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Safety Flags
          if (medication.safetyFlags.isNotEmpty) ...[
            for (final flag in medication.safetyFlags)
              Card(
                color: flag.severity == FlagSeverity.critical
                    ? const Color(0xFFFFEBEE)
                    : const Color(0xFFFFF8E1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: flag.severity == FlagSeverity.critical
                            ? AppTheme.dangerRed
                            : AppTheme.warningAmber,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              flag.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: flag.severity == FlagSeverity.critical
                                    ? AppTheme.dangerRed
                                    : const Color(0xFF8D6E63),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              flag.message,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],

          // Timing & Schedule
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Schedule',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${medication.timesPerDay} time(s) a day',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: medication.scheduledTimes.map((time) {
                      return Chip(
                        avatar: const Icon(Icons.access_time, size: 16),
                        label: Text(
                          time,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Course Duration:'),
                      Text(
                        medication.isOngoing
                            ? 'Ongoing (Routine)'
                            : '${medication.durationDays} days',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (medication.refillsRemaining != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Refills Remaining:'),
                        Text(
                          '${medication.refillsRemaining}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Conditions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Usage Instructions & Conditions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (medication.preConditions.isEmpty &&
                      medication.postConditions.isEmpty)
                    const Text('No special conditions specified.',
                        style: TextStyle(color: Colors.grey)),
                  if (medication.preConditions.isNotEmpty) ...[
                    const Text(
                      'Before taking this medicine:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryTeal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final c in medication.preConditions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_right, color: AppTheme.primaryTeal),
                            Text(c.description),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                  if (medication.postConditions.isNotEmpty) ...[
                    const Text(
                      'After taking this medicine:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentCyan,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final c in medication.postConditions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_right, color: AppTheme.accentCyan),
                            Text(c.description),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Side Effects
          if (medication.sideEffects.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Known Side Effects',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: medication.sideEffects.map((s) {
                        return Chip(
                          backgroundColor: const Color(0xFFF1F5F9),
                          label: Text(s.description),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Doctor Notes
          if (medication.doctorNotes != null &&
              medication.doctorNotes!.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Doctor / Pharmacist Notes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      medication.doctorNotes!,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
