import 'package:flutter/material.dart';
import 'package:medisync/core/models/medication.dart';

typedef ContinuityMilestone = StreakMilestone;
typedef ContinuityData = StreakData;
typedef ContinuityService = StreakService;

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
      id: 'vital_3',
      requiredDays: 3,
      title: '3-Day Vital Initiation',
      badgeEmoji: '🛡️',
      description: 'Established the initial baseline of your clinical routine.',
      accentColor: Color(0xFF0D9488), // Teal
    ),
    StreakMilestone(
      id: 'routine_7',
      requiredDays: 7,
      title: '7-Day Vital Equilibrium',
      badgeEmoji: '💎',
      description: 'One full week of continuous therapeutic adherence.',
      accentColor: Color(0xFF0284C7), // Sapphire Blue
    ),
    StreakMilestone(
      id: 'shield_14',
      requiredDays: 14,
      title: '14-Day Shield Sentinel',
      badgeEmoji: '🏅',
      description: 'Two consecutive weeks of uninterrupted plasma stability.',
      accentColor: Color(0xFF10B981), // Emerald
    ),
    StreakMilestone(
      id: 'fortress_30',
      requiredDays: 30,
      title: '30-Day Clinical Fortress',
      badgeEmoji: '🏆',
      description: 'A full month of proactive health protection and steady continuity.',
      accentColor: Color(0xFF06B6D4), // Cyan
    ),
    StreakMilestone(
      id: 'guardian_60',
      requiredDays: 60,
      title: '60-Day Diamond Guardian',
      badgeEmoji: '⭐',
      description: 'Two full months of unbreakable commitment to your well-being.',
      accentColor: Color(0xFF6366F1), // Royal Indigo
    ),
    StreakMilestone(
      id: 'legend_100',
      requiredDays: 100,
      title: '100-Day Master of Health',
      badgeEmoji: '👑',
      description: 'Centurion status. Medication adherence is now an effortless lifestyle.',
      accentColor: Color(0xFF8B5CF6), // Royal Violet
    ),
    StreakMilestone(
      id: 'titan_365',
      requiredDays: 365,
      title: '365-Day Lifelong Vital Shield',
      badgeEmoji: '✨',
      description: 'A full consecutive year of uncompromising health dedication and vital care.',
      accentColor: Color(0xFF14B8A6), // Mint Emerald
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

  // Vital Continuity Aliases
  int get protectedDays => currentStreak;
  int get longestProtectedDays => longestStreak;
  bool get isProtectedToday => isCompletedToday;

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

    // 2. Count consecutive protected days going backwards
    int streak = 0;

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
          // Missed dose halts unbroken continuity
          break;
        }
      } else {
        // Rest day / PRN day without scheduled doses preserves continuity
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
