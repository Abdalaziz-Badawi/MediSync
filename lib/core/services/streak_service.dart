import 'package:flutter/material.dart';
import 'package:medisync/core/models/medication.dart';

class StreakMilestone {
  final String id;
  final int requiredDays;
  final String title;
  final String badgeEmoji;
  final String description;
  final Color accentColor;

  const StreakMilestone({
    required this.id,
    required this.requiredDays,
    required this.title,
    required this.badgeEmoji,
    required this.description,
    required this.accentColor,
  });

  static const List<StreakMilestone> all = allMilestones;
  static const List<StreakMilestone> allMilestones = [
    StreakMilestone(
      id: 'rookie_3',
      requiredDays: 3,
      title: '3-Day Spark',
      badgeEmoji: '🥉',
      description: 'Built the initial ignition of your medication routine.',
      accentColor: Color(0xFFF97316), // Orange
    ),
    StreakMilestone(
      id: 'habit_7',
      requiredDays: 7,
      title: '7-Day Habit Builder',
      badgeEmoji: '🥈',
      description: 'One full week of flawless consistency! The habit is forming.',
      accentColor: Color(0xFFEAB308), // Amber / Gold
    ),
    StreakMilestone(
      id: 'routine_14',
      requiredDays: 14,
      title: '14-Day Routine Master',
      badgeEmoji: '🥇',
      description: 'Two consecutive weeks of therapeutic plasma equilibrium.',
      accentColor: Color(0xFF10B981), // Emerald
    ),
    StreakMilestone(
      id: 'champion_30',
      requiredDays: 30,
      title: '30-Day Health Champion',
      badgeEmoji: '🏆',
      description: 'A full month of proactive health protection. Truly phenomenal.',
      accentColor: Color(0xFF06B6D4), // Cyan
    ),
    StreakMilestone(
      id: 'persistence_60',
      requiredDays: 60,
      title: '60-Day Diamond Persistence',
      badgeEmoji: '💎',
      description: 'Two full months of unbreakable commitment to your well-being.',
      accentColor: Color(0xFF6366F1), // Indigo
    ),
    StreakMilestone(
      id: 'legend_100',
      requiredDays: 100,
      title: '100-Day Centurion Legend',
      badgeEmoji: '👑',
      description: 'Centurion status. Medication adherence is now second nature.',
      accentColor: Color(0xFF8B5CF6), // Royal Violet
    ),
    StreakMilestone(
      id: 'titan_365',
      requiredDays: 365,
      title: '365-Day Immortal Titan',
      badgeEmoji: '🌟',
      description: 'A full consecutive year of uncompromising health dedication!',
      accentColor: Color(0xFFF59E0B), // Golden Amber
    ),
  ];
}

class DayStreakStatus {
  final String label; // 'M', 'T', 'W', etc.
  final DateTime date;
  final bool isCompleted;
  final bool isToday;
  final bool isFuture;

  const DayStreakStatus({
    required this.label,
    required this.date,
    required this.isCompleted,
    required this.isToday,
    required this.isFuture,
  });
}

class StreakData {
  final int currentStreak;
  final int longestStreak;
  final bool isCompletedToday;
  final int todayScheduledCount;
  final int todayResolvedCount;
  final int todayPendingCount;
  final List<DayStreakStatus> weeklyDayStatus;
  final int streakShields;
  final List<StreakMilestone> unlockedMilestones;
  final StreakMilestone? nextMilestone;
  final double progressToNext;

  const StreakData({
    required this.currentStreak,
    required this.longestStreak,
    required this.isCompletedToday,
    required this.todayScheduledCount,
    required this.todayResolvedCount,
    required this.todayPendingCount,
    required this.weeklyDayStatus,
    this.streakShields = 1,
    required this.unlockedMilestones,
    this.nextMilestone,
    required this.progressToNext,
  });
}

class StreakService {
  static StreakData computeStreakData(
    List<Medication> medications, {
    int storedLongestStreak = 0,
  }) {
    if (medications.isEmpty) {
      return StreakData(
        currentStreak: 0,
        longestStreak: storedLongestStreak,
        isCompletedToday: false,
        todayScheduledCount: 0,
        todayResolvedCount: 0,
        todayPendingCount: 0,
        weeklyDayStatus: _buildWeeklyStatus(medications, DateTime.now()),
        streakShields: 1,
        unlockedMilestones: const [],
        nextMilestone: StreakMilestone.allMilestones.first,
        progressToNext: 0.0,
      );
    }

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    // 1. Evaluate today's dose metrics
    int todayScheduled = 0;
    int todayResolved = 0;
    int todayPending = 0;

    for (final med in medications) {
      if (med.isActiveOn(todayMidnight)) {
        for (final time in med.scheduledTimes) {
          todayScheduled++;
          if (med.isDoseResolved(todayMidnight, time)) {
            todayResolved++;
          } else {
            todayPending++;
          }
        }
      }
    }

    final bool isCompletedToday =
        todayScheduled > 0 && todayPending == 0 && todayResolved == todayScheduled;

    // 2. Count consecutive streak days going backwards
    int streak = 0;

    // Start with today if completed
    if (isCompletedToday) {
      streak = 1;
    }

    // Check past days (offset 1 through 90)
    for (int offset = 1; offset <= 90; offset++) {
      final pastDate = todayMidnight.subtract(Duration(days: offset));
      bool hadScheduledMeds = false;
      bool allDosesResolved = true;

      for (final med in medications) {
        if (med.isActiveOn(pastDate)) {
          hadScheduledMeds = true;
          for (final time in med.scheduledTimes) {
            final status = med.getDoseStatus(pastDate, time);
            if (status == DoseStatus.missed || status == DoseStatus.pending) {
              allDosesResolved = false;
              break;
            }
          }
        }
        if (!allDosesResolved) break;
      }

      if (hadScheduledMeds) {
        if (allDosesResolved) {
          streak++;
        } else {
          // Missed dose terminates unbroken streak
          break;
        }
      } else {
        // Rest day / PRN day without scheduled doses: preserves streak
        continue;
      }
    }

    final int longestStreak = streak > storedLongestStreak ? streak : storedLongestStreak;

    // 3. Compute milestones
    final unlocked = <StreakMilestone>[];
    StreakMilestone? next;

    for (final milestone in StreakMilestone.allMilestones) {
      if (streak >= milestone.requiredDays) {
        unlocked.add(milestone);
      } else {
        next ??= milestone;
      }
    }

    double progress = 1.0;
    if (next != null) {
      final prevRequired = unlocked.isEmpty ? 0 : unlocked.last.requiredDays;
      final span = next.requiredDays - prevRequired;
      final currentInSpan = (streak - prevRequired).clamp(0, span);
      progress = span > 0 ? (currentInSpan / span).clamp(0.0, 1.0) : 0.0;
    }

    return StreakData(
      currentStreak: streak,
      longestStreak: longestStreak,
      isCompletedToday: isCompletedToday,
      todayScheduledCount: todayScheduled,
      todayResolvedCount: todayResolved,
      todayPendingCount: todayPending,
      weeklyDayStatus: _buildWeeklyStatus(medications, todayMidnight),
      streakShields: 1,
      unlockedMilestones: unlocked,
      nextMilestone: next,
      progressToNext: progress,
    );
  }

  static List<DayStreakStatus> _buildWeeklyStatus(
    List<Medication> medications,
    DateTime todayMidnight,
  ) {
    // Current week starting Monday (weekday = 1) to Sunday (weekday = 7)
    final currentWeekday = todayMidnight.weekday; // 1 = Mon, 7 = Sun
    final monday = todayMidnight.subtract(Duration(days: currentWeekday - 1));

    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final result = <DayStreakStatus>[];

    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      final isToday = date.year == todayMidnight.year &&
          date.month == todayMidnight.month &&
          date.day == todayMidnight.day;
      final isFuture = date.isAfter(todayMidnight);

      bool isCompleted = false;
      if (!isFuture) {
        int sched = 0;
        int resolved = 0;
        for (final med in medications) {
          if (med.isActiveOn(date)) {
            for (final time in med.scheduledTimes) {
              sched++;
              if (med.isDoseResolved(date, time)) {
                resolved++;
              }
            }
          }
        }
        isCompleted = sched > 0 && resolved == sched;
      }

      result.add(DayStreakStatus(
        label: dayLabels[i],
        date: date,
        isCompleted: isCompleted,
        isToday: isToday,
        isFuture: isFuture,
      ));
    }

    return result;
  }
}
