import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medisync/core/models/condition.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/models/safety_flag.dart';
import 'package:medisync/core/services/storage_service.dart';
import 'package:medisync/core/theme/app_theme.dart';
import 'package:medisync/features/homeboard/presentation/widgets/next_dose_countdown_card.dart';
import 'package:medisync/features/medications/presentation/pages/add_edit_medication_page.dart';

class DoseItem {
  final Medication medication;
  final String time;
  final bool isTaken;

  DoseItem({
    required this.medication,
    required this.time,
    required this.isTaken,
  });
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medications = ref.watch(medicationsNotifierProvider);
    final profile = ref.watch(profileNotifierProvider);
    final now = DateTime.now();

    // Collect all doses for today
    final todayDoses = <DoseItem>[];
    for (final med in medications) {
      if (med.isActiveOn(now)) {
        for (final time in med.scheduledTimes) {
          todayDoses.add(DoseItem(
            medication: med,
            time: time,
            isTaken: med.isDoseTaken(now, time),
          ));
        }
      }
    }

    // Sort chronologically by time
    todayDoses.sort((a, b) => a.time.compareTo(b.time));

    final totalDoses = todayDoses.length;
    final takenCount = todayDoses.where((d) => d.isTaken).length;
    final progress = totalDoses == 0 ? 0.0 : (takenCount / totalDoses);

    // Check for any critical safety flags across all medications
    final criticalFlags = <SafetyFlag>[];
    for (final m in medications) {
      for (final f in m.safetyFlags) {
        if (f.severity == FlagSeverity.critical) {
          criticalFlags.add(f);
        }
      }
    }

    final formattedDate = DateFormat('EEEE, MMMM d').format(now);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formattedDate,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            Text(
              'Hello, ${profile.name.split(' ').first}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Add Medication',
            icon: const Icon(Icons.add_circle, color: AppTheme.primaryTeal, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddEditMedicationPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Allergy Alert Banner (if any)
          if (criticalFlags.isNotEmpty) ...[
            Card(
              color: const Color(0xFFFFEBEE),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.dangerRed, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_rounded,
                      color: AppTheme.dangerRed,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Allergy Warning Flagged',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.dangerRed,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            criticalFlags.first.message,
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

          // Next Dose Countdown Widget
          NextDoseCountdownCard(
            medications: medications,
            onMarkTaken: (medId, date, time) {
              ref
                  .read(medicationsNotifierProvider.notifier)
                  .toggleDoseTaken(medId, date, time);
            },
          ),
          const SizedBox(height: 16),

          // Daily Progress Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF00796B), Color(0xFF004D40)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Today's Schedule",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$takenCount / $totalDoses Taken',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Color(0xFF80CBC4)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    totalDoses == 0
                        ? 'No medications scheduled for today.'
                        : progress == 1.0
                            ? 'Great job! All doses taken for today.'
                            : '${totalDoses - takenCount} dose(s) remaining today.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Timeline Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Dose Timeline',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'Routine Sync: ${profile.useHealthApp ? 'Samsung Health' : 'Manual'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dose Timeline Items
          if (todayDoses.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 60,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No medication doses due today',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddEditMedicationPage(),
                          ),
                        );
                      },
                      child: const Text('Add a Medicine'),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            for (final dose in todayDoses)
              _DoseTimelineCard(
                dose: dose,
                date: now,
                onToggle: () {
                  ref
                      .read(medicationsNotifierProvider.notifier)
                      .toggleDoseTaken(
                        dose.medication.id,
                        now,
                        dose.time,
                      );
                },
              ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _DoseTimelineCard extends StatelessWidget {
  final DoseItem dose;
  final DateTime date;
  final VoidCallback onToggle;

  const _DoseTimelineCard({
    required this.dose,
    required this.date,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final med = dose.medication;
    final isTaken = dose.isTaken;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isTaken ? 0.5 : 2,
      color: isTaken ? const Color(0xFFF1F5F9) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Time Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isTaken
                    ? Colors.grey.shade300
                    : const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                dose.time,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isTaken ? Colors.grey.shade700 : AppTheme.primaryTeal,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Med Info & Condition Badges
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    med.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration:
                          isTaken ? TextDecoration.lineThrough : null,
                      color: isTaken
                          ? Colors.grey.shade600
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${med.dosage} • ${med.form.name}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 6),

                  // Condition tags (e.g. After food, Before sleep)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final c in med.preConditions)
                        _buildTag(
                          icon: _conditionIcon(c.type),
                          label: 'Before: ${c.description}',
                          isTaken: isTaken,
                        ),
                      for (final c in med.postConditions)
                        _buildTag(
                          icon: _conditionIcon(c.type),
                          label: 'After: ${c.description}',
                          isTaken: isTaken,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Checkbox Button
            IconButton(
              icon: Icon(
                isTaken
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: isTaken ? AppTheme.successGreen : Colors.grey.shade400,
                size: 28,
              ),
              onPressed: onToggle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag({
    required IconData icon,
    required String label,
    required bool isTaken,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isTaken ? Colors.grey.shade200 : const Color(0xFFE0F7FA),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: isTaken ? Colors.grey.shade600 : const Color(0xFF00838F),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isTaken ? Colors.grey.shade600 : const Color(0xFF00838F),
            ),
          ),
        ],
      ),
    );
  }

  IconData _conditionIcon(ConditionType type) {
    switch (type) {
      case ConditionType.meal:
        return Icons.restaurant;
      case ConditionType.emptyStomach:
        return Icons.no_food;
      case ConditionType.sleep:
        return Icons.bedtime;
      case ConditionType.drinkWater:
        return Icons.water_drop;
      case ConditionType.rest:
        return Icons.weekend;
      case ConditionType.avoidDriving:
        return Icons.no_crash;
      case ConditionType.custom:
        return Icons.info;
    }
  }
}
