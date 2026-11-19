import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medisync/core/models/condition.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/models/side_effect.dart';
import 'package:medisync/core/services/scheduler_service.dart';
import 'package:medisync/core/services/storage_service.dart';
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

class NextDoseCountdownCard extends ConsumerStatefulWidget {
  final List<Medication> medications;
  final Function(String medId, DateTime date, String time) onMarkTaken;

  const NextDoseCountdownCard({
    super.key,
    required this.medications,
    required this.onMarkTaken,
  });

  @override
  ConsumerState<NextDoseCountdownCard> createState() => _NextDoseCountdownCardState();
}

class _NextDoseCountdownCardState extends ConsumerState<NextDoseCountdownCard> {
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

    for (final med in widget.medications) {
      if (med.isActiveOn(now)) {
        for (final t in med.scheduledTimes) {
          final isResolved = med.isDoseResolved(now, t);
          if (!isResolved) {
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
    }

    if (todayList.isNotEmpty) {
      todayList.sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));

      final upcomingToday = todayList
          .where((d) => d.scheduledDateTime
              .isAfter(now.subtract(const Duration(minutes: 60))))
          .toList();
      if (upcomingToday.isNotEmpty) {
        return upcomingToday.first;
      }
      return todayList.first;
    }

    // Do NOT show tomorrow's medication as the active next dose when today is finished!
    return null;
  }

  List<UpcomingDose> _getTomorrowDoses() {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowList = <UpcomingDose>[];

    for (final med in widget.medications) {
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
    tomorrowList.sort((a, b) => a.timeString.compareTo(b.timeString));
    return tomorrowList;
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
      if (widget.medications.isEmpty) {
        return const SizedBox.shrink();
      }

      final now = DateTime.now();
      int todayTotalScheduled = 0;
      for (final med in widget.medications) {
        if (med.isActiveOn(now)) {
          todayTotalScheduled += med.scheduledTimes.length;
        }
      }

      final tomorrowDoses = _getTomorrowDoses();
      return _buildTodayCompletedCard(context, todayTotalScheduled, tomorrowDoses);
    }

    final med = nextDose.medication;
    final profile = ref.watch(profileNotifierProvider);
    final allergyFlags = SchedulerService.getAllergyConflictsForMedication(
      medication: med,
      profile: profile,
    );
    final hasAllergyConflict = allergyFlags.isNotEmpty;

    final diff = nextDose.remainingDuration;
    final countdownText = _formatCountdown(diff);
    final isOverdue = diff.isNegative && diff.abs().inMinutes >= 15;
    final isDueSoon = !diff.isNegative && diff.inMinutes <= 45;

    final isDark = AppTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;

    final preConditions = med.preConditions;
    final postConditions = med.postConditions;
    final sideEffects = med.sideEffects;

    final cardBgStart = isDark
        ? (isOverdue ? const Color(0xFF451A03) : primary.withValues(alpha: 0.22))
        : (isOverdue ? const Color(0xFFFEF3C7) : primary.withValues(alpha: 0.12));
    final cardBgEnd = AppTheme.cardColor(context);

    final glowColor = isOverdue
        ? (isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber)
        : (isDueSoon ? secondary : primary);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          // 360-degree surrounding ambient glow aura
          BoxShadow(
            color: glowColor.withValues(alpha: isDark ? 0.35 : 0.22),
            blurRadius: 26,
            spreadRadius: 2,
            offset: Offset.zero,
          ),
          ...AppTheme.softShadow(context),
        ],
      ),
      child: Card(
        elevation: isDark ? 2 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isOverdue
                ? (isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber)
                : (isDueSoon
                    ? secondary
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
                        Icons.timer_rounded,
                        size: 18,
                        color: isOverdue
                            ? (isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber)
                            : primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'NEXT MEDICATION',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isOverdue
                              ? (isDark ? AppTheme.warningAmberLight : const Color(0xFFB45309))
                              : primary,
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
                          : primary.withValues(alpha: isDark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      countdownText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isOverdue
                            ? (isDark ? AppTheme.warningAmberLight : const Color(0xFF92400E))
                            : primary,
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
                      color: primary,
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
                      widget.onMarkTaken(med.id, DateTime.now(), nextDose.timeString);
                    },
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Take'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
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

              // Allergy Red Flag Alert on Countdown Card
              if (hasAllergyConflict) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                      width: 1.4,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flag_rounded, color: AppTheme.dangerRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'RED FLAG: ALLERGY TRIGGER (${allergyFlags.first.relatedAllergy ?? "Conflict"})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

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
                      Icon(Icons.check_circle_outline_rounded, size: 16, color: AppTheme.textMuted(context)),
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
                      badgeColor: secondary,
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
                      badgeColor: primary,
                      title: _conditionTitle(post),
                      subtitle: post.description,
                    ),
                ],

              // Side Effects & Cautions
              if (sideEffects.isNotEmpty) ...[
                for (final effect in sideEffects)
                  _buildConditionTile(
                    context: context,
                    icon: Icons.info_rounded,
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
                    Icon(Icons.note_alt_rounded, size: 16, color: AppTheme.textMuted(context)),
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

  Widget _buildTodayCompletedCard(
    BuildContext context,
    int todayTotalScheduled,
    List<UpcomingDose> tomorrowDoses,
  ) {
    final isDark = AppTheme.isDark(context);
    final successColor =
        isDark ? AppTheme.successGreenLight : AppTheme.successGreen;
    final primary = Theme.of(context).colorScheme.primary;

    final cardBgStart = isDark
        ? const Color(0xFF064E3B).withValues(alpha: 0.28)
        : const Color(0xFFDCFCE7).withValues(alpha: 0.6);
    final cardBgEnd = AppTheme.cardColor(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: successColor.withValues(alpha: isDark ? 0.32 : 0.20),
            blurRadius: 26,
            spreadRadius: 2,
            offset: Offset.zero,
          ),
          ...AppTheme.softShadow(context),
        ],
      ),
      child: Card(
        elevation: isDark ? 2 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: successColor.withValues(alpha: 0.5),
            width: 1.5,
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
              // Celebration Top Banner
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF064E3B)
                          : const Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                      border: Border.all(color: successColor, width: 2),
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: successColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Today We're Done!",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.check_circle_rounded,
                                size: 18, color: successColor),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          todayTotalScheduled > 0
                              ? 'All $todayTotalScheduled scheduled dose${todayTotalScheduled == 1 ? '' : 's'} completed for today.'
                              : 'No remaining doses for today. All caught up!',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          successColor.withValues(alpha: isDark ? 0.22 : 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: successColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: successColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Divider(height: 1, color: AppTheme.cardBorder(context)),
              const SizedBox(height: 14),

              // Tomorrow's Medication Summary Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.wb_sunny_rounded,
                        size: 17,
                        color: primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "TOMORROW'S SCHEDULE SUMMARY",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: isDark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${tomorrowDoses.length} Dose${tomorrowDoses.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Tomorrow's doses summary list
              if (tomorrowDoses.isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder(context)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_available_rounded,
                          size: 18, color: AppTheme.textMuted(context)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No medications scheduled for tomorrow.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                for (final td in tomorrowDoses)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorder(context)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            td.medication.icon,
                            size: 18,
                            color: primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                td.medication.name,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                              Text(
                                td.medication.dosage,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: AppTheme.cardBorder(context)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                td.timeString,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
