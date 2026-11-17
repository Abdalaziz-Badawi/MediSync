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
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          medication.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary(context),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
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
                      color: AppTheme.surfaceVariant(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.cardBorder(context)),
                    ),
                    child: Icon(
                      medication.icon,
                      color: Theme.of(context).colorScheme.primary,
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
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${medication.dosage} • ${medication.form.name.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary(context),
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
                    ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2))
                    : (isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: flag.severity == FlagSeverity.critical
                        ? (isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed)
                        : (isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: flag.severity == FlagSeverity.critical
                            ? (isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed)
                            : (isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber),
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
                                    ? (isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed)
                                    : (isDark ? AppTheme.warningAmberLight : const Color(0xFFB45309)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              flag.message,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textPrimary(context),
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
          ],

          // Weekly Active Days
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Days of Week',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildDayIndicator(context, 'M', 1),
                      _buildDayIndicator(context, 'T', 2),
                      _buildDayIndicator(context, 'W', 3),
                      _buildDayIndicator(context, 'T', 4),
                      _buildDayIndicator(context, 'F', 5),
                      _buildDayIndicator(context, 'S', 6),
                      _buildDayIndicator(context, 'S', 7),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Schedule Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dose Schedule (${medication.timesPerDay}x daily)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: medication.scheduledTimes.map((t) {
                      return Chip(
                        avatar: Icon(
                          Icons.access_time,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        label: Text(
                          t,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        backgroundColor: AppTheme.surfaceVariant(context),
                        side: BorderSide(color: AppTheme.cardBorder(context)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Conditions & Instructions
          if (medication.preConditions.isNotEmpty ||
              medication.postConditions.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conditions & Instructions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final c in medication.preConditions)
                      _buildConditionRow(context, 'Before Taking', c.description, Icons.timer_outlined),
                    for (final c in medication.postConditions)
                      _buildConditionRow(context, 'After Taking', c.description, Icons.check_circle_outline),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Side Effects
          if (medication.sideEffects.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Side Effects & Advisory',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: medication.sideEffects.map((s) {
                        return Chip(
                          label: Text(s.description),
                          labelStyle: TextStyle(color: AppTheme.textPrimary(context)),
                          backgroundColor: AppTheme.surfaceVariant(context),
                          side: BorderSide(color: AppTheme.cardBorder(context)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Notes
          if (medication.doctorNotes != null &&
              medication.doctorNotes!.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Doctor / Pharmacist Notes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      medication.doctorNotes!,
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textSecondary(context),
                      ),
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

  Widget _buildDayIndicator(BuildContext context, String label, int day) {
    final isActive = medication.daysOfWeek.contains(day);
    final isDark = AppTheme.isDark(context);
    final activeColor = Theme.of(context).colorScheme.primary;

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: isActive ? activeColor : AppTheme.surfaceVariant(context),
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? activeColor : AppTheme.cardBorder(context),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: isActive
              ? (isDark ? const Color(0xFF042F2E) : Colors.white)
              : AppTheme.textMuted(context),
        ),
      ),
    );
  }

  Widget _buildConditionRow(BuildContext context, String prefix, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textPrimary(context),
                ),
                children: [
                  TextSpan(
                    text: '$prefix: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
