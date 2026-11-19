import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/models/safety_flag.dart';
import 'package:medisync/core/services/device_integration_service.dart';
import 'package:medisync/core/services/scheduler_service.dart';
import 'package:medisync/core/services/storage_service.dart';
import 'package:medisync/core/theme/app_theme.dart';
import 'package:medisync/features/medications/presentation/pages/add_edit_medication_page.dart';

class MedicationDetailsPage extends ConsumerWidget {
  final Medication medication;

  const MedicationDetailsPage({super.key, required this.medication});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = AppTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;
    final allMeds = ref.watch(medicationsNotifierProvider);
    final currentMed = allMeds.firstWhere(
      (m) => m.id == medication.id,
      orElse: () => medication,
    );
    final profile = ref.watch(profileNotifierProvider);
    final allergyFlags = SchedulerService.getAllergyConflictsForMedication(
      medication: currentMed,
      profile: profile,
    );
    final hasAllergyConflict = allergyFlags.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentMed.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary(context),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sync to Phone Calendar',
            icon: Icon(
              Icons.calendar_today_rounded,
              color: primary,
              size: 20,
            ),
            onPressed: () => _syncToCalendar(context, ref, currentMed),
          ),
          IconButton(
            tooltip: 'Edit Medicine',
            icon: Icon(
              Icons.edit_outlined,
              color: primary,
            ),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AddEditMedicationPage(medicationToEdit: currentMed),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Manage / Discontinue',
            icon: const Icon(
              Icons.more_vert_rounded,
            ),
            onPressed: () => _showDiscontinueOrDeleteDialog(context, ref, currentMed),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Discontinued Alert Banner (if discontinued)
          if (currentMed.isDiscontinued) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.warningAmber.withValues(alpha: isDark ? 0.20 : 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.warningAmber,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pause_circle_filled_rounded, color: AppTheme.warningAmber, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Medication Discontinued',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.warningAmberLight : const Color(0xFFB45309),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          ref.read(medicationsNotifierProvider.notifier).resume(currentMed.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✓ Resumed active schedule for "${currentMed.name}"!'),
                              backgroundColor: primary,
                            ),
                          );
                        },
                        icon: const Icon(Icons.play_circle_filled_rounded, size: 16),
                        label: const Text('Resume', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Discontinued on ${DateFormat('EEEE, d MMMM yyyy').format(currentMed.discontinuedDate!)}. Future scheduled doses and notifications are paused. All prior logs and intake history remain preserved.',
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary(context), height: 1.3),
                  ),
                ],
              ),
            ),
          ],

          // RED FLAG: Allergy Trigger Alert Banner
          if (hasAllergyConflict) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                  width: 1.6,
                ),
                boxShadow: AppTheme.glowShadow(AppTheme.dangerRed, opacity: 0.16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.flag_rounded, color: AppTheme.dangerRed, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RED FLAG: ALLERGY TRIGGER DETECTED',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                          ),
                        ),
                        const SizedBox(height: 4),
                        for (final flag in allergyFlags)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '• ${flag.message}',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? const Color(0xFFFECACA) : const Color(0xFF7F1D1D),
                                height: 1.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
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

          const SizedBox(height: 16),

          // External Clinical Research & Database Reference (100% Privacy-Preserving)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.cardBorder(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.travel_explore_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Online Medical Reference & Monograph',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Access official FDA drug monographs, clinical trial data, and pharmacological details on trusted online medical databases.',
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary(context), height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      ref.read(deviceIntegrationServiceProvider).openOnlineDrugMonograph(medication.name);
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: Text('Search "${medication.name}" Online Monograph'),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_rounded, size: 14, color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Strict Privacy Guarantee: Only the public drug name is searched. Zero personal health info, logs, or identities are transmitted.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary(context),
                              fontWeight: FontWeight.w500,
                            ),
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

          // Quick Actions: Calendar Sync & Manage Discontinuation
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.cardBorder(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device & Schedule Actions',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _syncToCalendar(context, ref, currentMed),
                          icon: Icon(Icons.sync_rounded, color: primary, size: 18),
                          label: Text(
                            'Sync Calendar',
                            style: TextStyle(color: primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                              color: currentMed.isDiscontinued ? primary : AppTheme.warningAmber,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            if (currentMed.isDiscontinued) {
                              ref.read(medicationsNotifierProvider.notifier).resume(currentMed.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✓ Resumed "${currentMed.name}"!'),
                                  backgroundColor: primary,
                                ),
                              );
                            } else {
                              _showDiscontinueOrDeleteDialog(context, ref, currentMed);
                            }
                          },
                          icon: Icon(
                            currentMed.isDiscontinued ? Icons.play_arrow_rounded : Icons.pause_circle_outline_rounded,
                            color: currentMed.isDiscontinued ? primary : AppTheme.warningAmber,
                            size: 18,
                          ),
                          label: Text(
                            currentMed.isDiscontinued ? 'Resume Active' : 'Discontinue',
                            style: TextStyle(
                              color: currentMed.isDiscontinued ? primary : AppTheme.warningAmber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _syncToCalendar(BuildContext context, WidgetRef ref, Medication currentMed) async {
    final res = await ref.read(deviceIntegrationServiceProvider).syncMedicationsToCalendar([currentMed]);
    if (!context.mounted) return;

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Successfully synced ${res.eventsCreated} dose event(s) to phone calendar!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
    }
  }

  void _showDiscontinueOrDeleteDialog(BuildContext context, WidgetRef ref, Medication currentMed) {
    final isDark = AppTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;

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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Manage "${currentMed.name}"',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(ctx),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Similar to calendar events, decide whether to stop this medication going forward while keeping your historical log, or purge it entirely:',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary(ctx), height: 1.3),
                ),
                const SizedBox(height: 18),

                // Option 1: Discontinue from Today Forward
                InkWell(
                  onTap: () {
                    ref.read(medicationsNotifierProvider.notifier).discontinue(currentMed.id);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✓ Discontinued "${currentMed.name}". Past records are preserved in history.'),
                        backgroundColor: AppTheme.warningAmber,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.warningAmber.withValues(alpha: isDark ? 0.16 : 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.warningAmber.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.warningAmber.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.pause_circle_filled_rounded, color: AppTheme.warningAmber, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Discontinue from Today Forward',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary(ctx),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Recommended',
                                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: primary),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Stops future scheduled doses & alarms. All past intake logs, taken doses, and adherence continuity records are safely preserved.',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(ctx), height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Option 2: Delete Entire Medication & All Records
                InkWell(
                  onTap: () {
                    ref.read(medicationsNotifierProvider.notifier).remove(currentMed.id);
                    Navigator.pop(ctx);
                    Navigator.pop(context); // Also pop details page
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✓ Permanently deleted "${currentMed.name}".'),
                        backgroundColor: AppTheme.dangerRed,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerRed.withValues(alpha: isDark ? 0.14 : 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.dangerRed.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerRed.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.delete_forever_rounded, color: AppTheme.dangerRed, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delete Entire Medication & History',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.dangerRed,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Irreversibly removes this medication and purges all historical intake logs from on-device storage.',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(ctx), height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
