import 'dart:async';
import 'package:flutter/material.dart';
import 'package:medisync/core/models/condition.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/models/side_effect.dart';
import 'package:medisync/core/theme/app_theme.dart';

class UpcomingDose {
  final Medication medication;
  final DateTime scheduledDateTime;
  final String timeString; // "HH:mm"
  final bool isTomorrow;

  UpcomingDose({
    required this.medication,
    required this.scheduledDateTime,
    required this.timeString,
    this.isTomorrow = false,
  });

  Duration get remainingDuration => scheduledDateTime.difference(DateTime.now());
}

class NextDoseCountdownCard extends StatefulWidget {
  final List<Medication> medications;
  final Function(String medId, DateTime date, String time) onMarkTaken;

  const NextDoseCountdownCard({
    super.key,
    required this.medications,
    required this.onMarkTaken,
  });

  @override
  State<NextDoseCountdownCard> createState() => _NextDoseCountdownCardState();
}

class _NextDoseCountdownCardState extends State<NextDoseCountdownCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Refresh countdown every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  UpcomingDose? _findNextUpcomingDose() {
    final now = DateTime.now();
    final todayList = <UpcomingDose>[];
    final tomorrowList = <UpcomingDose>[];

    final tomorrow = now.add(const Duration(days: 1));

    for (final med in widget.medications) {
      if (med.isActiveOn(now)) {
        for (final t in med.scheduledTimes) {
          final isTaken = med.isDoseTaken(now, t);
          if (!isTaken) {
            final dt = _parseDateTimeFor(now, t);
            todayList.add(UpcomingDose(
              medication: med,
              scheduledDateTime: dt,
              timeString: t,
              isTomorrow: false,
            ));
          }
        }
      }

      if (med.isActiveOn(tomorrow)) {
        for (final t in med.scheduledTimes) {
          final dt = _parseDateTimeFor(tomorrow, t);
          tomorrowList.add(UpcomingDose(
            medication: med,
            scheduledDateTime: dt,
            timeString: t,
            isTomorrow: true,
          ));
        }
      }
    }

    if (todayList.isNotEmpty) {
      todayList.sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));

      final upcomingToday = todayList.where((d) => d.scheduledDateTime.isAfter(now.subtract(const Duration(minutes: 60)))).toList();
      if (upcomingToday.isNotEmpty) {
        return upcomingToday.first;
      }
      return todayList.first;
    }

    if (tomorrowList.isNotEmpty) {
      tomorrowList.sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));
      return tomorrowList.first;
    }

    return null;
  }

  DateTime _parseDateTimeFor(DateTime date, String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return DateTime(date.year, date.month, date.day, h, m);
  }

  String _formatCountdown(Duration diff) {
    if (diff.isNegative) {
      final abs = diff.abs();
      if (abs.inMinutes < 1) return 'Due right now';
      if (abs.inHours < 1) return 'Due ${abs.inMinutes}m ago';
      return 'Due ${abs.inHours}h ${abs.inMinutes % 60}m ago';
    }

    if (diff.inMinutes < 1) {
      return 'Due right now';
    } else if (diff.inHours < 1) {
      return 'In ${diff.inMinutes} minutes';
    } else if (diff.inHours < 24) {
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      return minutes > 0 ? 'In ${hours}h ${minutes}m' : 'In $hours hours';
    } else {
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      return 'In ${days}d ${hours}h';
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextDose = _findNextUpcomingDose();

    if (nextDose == null) {
      return const SizedBox.shrink();
    }

    final med = nextDose.medication;
    final diff = nextDose.remainingDuration;
    final countdownText = _formatCountdown(diff);
    final isOverdue = diff.isNegative && diff.abs().inMinutes >= 15;
    final isDueSoon = !diff.isNegative && diff.inMinutes <= 45;

    final isDark = AppTheme.isDark(context);
    final preConditions = med.preConditions;
    final postConditions = med.postConditions;
    final sideEffects = med.sideEffects;

    final cardBgStart = isDark
        ? (isOverdue ? const Color(0xFF451A03) : const Color(0xFF134E4A))
        : (isOverdue ? const Color(0xFFFEF3C7) : const Color(0xFFCCFBF1));
    final cardBgEnd = AppTheme.cardColor(context);

    return Card(
      elevation: isDark ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isOverdue
              ? (isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber)
              : (isDueSoon
                  ? (isDark ? AppTheme.secondaryCyanLight : AppTheme.secondaryCyan)
                  : AppTheme.cardBorder(context)),
          width: isOverdue || isDueSoon ? 2 : 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [cardBgStart, cardBgEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Label + Countdown Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: isOverdue
                          ? (isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber)
                          : (isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      nextDose.isTomorrow ? 'NEXT DOSE (TOMORROW)' : 'NEXT MEDICATION',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isOverdue
                            ? (isDark ? AppTheme.warningAmberLight : const Color(0xFFB45309))
                            : (isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? (isDark
                            ? AppTheme.warningAmberLight.withValues(alpha: 0.25)
                            : const Color(0xFFFDE68A))
                        : (isDark
                            ? AppTheme.primaryTealLight.withValues(alpha: 0.2)
                            : AppTheme.primaryTeal.withValues(alpha: 0.12)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    countdownText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isOverdue
                          ? (isDark ? AppTheme.warningAmberLight : const Color(0xFF92400E))
                          : (isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Med info row
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cardBorder(context)),
                  ),
                  child: Icon(
                    med.icon,
                    size: 28,
                    color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.name,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${med.dosage} • Scheduled for ${nextDose.timeString}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final targetDate = nextDose.isTomorrow
                        ? DateTime.now().add(const Duration(days: 1))
                        : DateTime.now();
                    widget.onMarkTaken(med.id, targetDate, nextDose.timeString);
                  },
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Take'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                    foregroundColor: isDark ? const Color(0xFF042F2E) : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            Divider(height: 1, color: AppTheme.cardBorder(context)),
            const SizedBox(height: 12),

            // Conditions Surrounding This Medication
            Text(
              'Required Conditions & Instructions:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),

            if (preConditions.isEmpty && postConditions.isEmpty && sideEffects.isEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorder(context)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: AppTheme.textMuted(context)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No special pre/post conditions. Take with a standard glass of water.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Pre-conditions (What to do before taking)
              if (preConditions.isNotEmpty) ...[
                for (final pre in preConditions)
                  _buildConditionTile(
                    context: context,
                    icon: _conditionIcon(pre.type),
                    badge: 'BEFORE',
                    badgeColor: isDark ? AppTheme.secondaryCyanLight : const Color(0xFF0284C7),
                    title: _conditionTitle(pre),
                    subtitle: pre.description,
                  ),
              ],

              // Post-conditions (What to do after taking)
              if (postConditions.isNotEmpty) ...[
                for (final post in postConditions)
                  _buildConditionTile(
                    context: context,
                    icon: _conditionIcon(post.type),
                    badge: 'AFTER',
                    badgeColor: isDark ? AppTheme.primaryTealLight : const Color(0xFF0D9488),
                    title: _conditionTitle(post),
                    subtitle: post.description,
                  ),
              ],

              // Side Effects & Cautions
              if (sideEffects.isNotEmpty) ...[
                for (final effect in sideEffects)
                  _buildConditionTile(
                    context: context,
                    icon: Icons.info_outline,
                    badge: 'CAUTION',
                    badgeColor: isDark ? AppTheme.warningAmberLight : const Color(0xFFD97706),
                    title: 'Known effect: ${effect.description}',
                    subtitle: _hintExplanation(effect.scheduleHint),
                  ),
              ],
            ],

            // Doctor instructions (if any)
            if (med.doctorNotes != null && med.doctorNotes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorder(context)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.note_alt_outlined, size: 16, color: AppTheme.textMuted(context)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Note: ${med.doctorNotes}',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConditionTile({
    required BuildContext context,
    required IconData icon,
    required String badge,
    required Color badgeColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: badgeColor),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: badgeColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                if (subtitle.isNotEmpty && subtitle != title) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _conditionTitle(MedicationCondition c) {
    switch (c.type) {
      case ConditionType.meal:
        return c.timing == ConditionTiming.before
            ? 'Eat Food First (20-30 mins before)'
            : 'Take 20 mins After Your Meal';
      case ConditionType.emptyStomach:
        return 'Empty Stomach (1 hr before or 2 hrs after eating)';
      case ConditionType.sleep:
        return c.timing == ConditionTiming.before
            ? 'Take Right Before Bedtime'
            : 'Go to Sleep / Rest Immediately';
      case ConditionType.drinkWater:
        return 'Drink a Full Glass of Water';
      case ConditionType.rest:
        return 'Rest or Lie Down for 20-30 Minutes';
      case ConditionType.avoidDriving:
        return 'Do Not Drive or Operate Machinery';
      case ConditionType.custom:
        return c.description;
    }
  }

  String _hintExplanation(ScheduleHint hint) {
    switch (hint) {
      case ScheduleHint.scheduleNearBedtime:
        return 'May cause drowsiness or sleepiness.';
      case ScheduleHint.scheduleAfterMeal:
        return 'May cause stomach irritation or nausea if taken without food.';
      case ScheduleHint.scheduleMorning:
        return 'May cause alertness or interfere with sleep if taken late.';
      case ScheduleHint.avoidBeforeDriving:
        return 'May cause dizziness or slowed reflexes.';
      case ScheduleHint.none:
        return '';
    }
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
        return Icons.hotel;
      case ConditionType.avoidDriving:
        return Icons.no_crash;
      case ConditionType.custom:
        return Icons.info_outline;
    }
  }
}
