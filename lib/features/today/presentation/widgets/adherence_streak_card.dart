import 'package:flutter/material.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/services/streak_service.dart';
import 'package:medisync/core/theme/app_theme.dart';

class AdherenceStreakCard extends StatelessWidget {
  final List<Medication> medications;
  final VoidCallback? onTap;

  const AdherenceStreakCard({
    super.key,
    required this.medications,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final streakData = StreakService.computeStreakData(medications);

    final flameColorStart = const Color(0xFF0D9488); // Medical Teal
    final flameColorEnd = const Color(0xFF0284C7);   // Sapphire Blue

    int totalTaken = 0;
    int totalDelayed = 0;
    int totalMissed = 0;
    int totalNotNeeded = 0;

    for (final med in medications) {
      final stats = med.continuityStats;
      totalTaken += stats['taken'] ?? 0;
      totalDelayed += stats['delayed'] ?? 0;
      totalMissed += stats['missed'] ?? 0;
      totalNotNeeded += stats['notNeeded'] ?? 0;
    }

    final totalLogged = totalTaken + totalDelayed + totalMissed;
    final adherenceRate = totalLogged > 0 ? ((totalTaken / totalLogged) * 100).round() : 100;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: streakData.currentStreak > 0
              ? flameColorStart.withValues(alpha: isDark ? 0.45 : 0.35)
              : AppTheme.cardBorder(context),
          width: streakData.currentStreak > 0 ? 1.5 : 1,
        ),
        boxShadow: streakData.currentStreak > 0
            ? [
                BoxShadow(
                  color: flameColorStart.withValues(alpha: isDark ? 0.20 : 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : AppTheme.softShadow(context),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showStreakMilestonesSheet(context, streakData),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Shield Icon + Protected Days + Milestone Badge
                Row(
                  children: [
                    // Glowing Shield Icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [flameColorStart, flameColorEnd],
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: flameColorStart.withValues(alpha: 0.40),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.shield_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${streakData.currentStreak} Protected Day${streakData.currentStreak == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary(context),
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (streakData.isCompletedToday) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified_user_rounded, size: 11, color: Color(0xFF10B981)),
                                      SizedBox(width: 3),
                                      Text(
                                        'Protected',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (totalLogged > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (adherenceRate >= 80 ? const Color(0xFF10B981) : AppTheme.warningAmber).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$adherenceRate% Adherence',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: adherenceRate >= 80 ? const Color(0xFF10B981) : AppTheme.warningAmber,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            streakData.isCompletedToday
                                ? "Vital continuity secured for today."
                                : (streakData.todayPendingCount > 0
                                    ? "${streakData.todayPendingCount} dose(s) remaining today to maintain continuity."
                                    : "Take today's doses to activate your protection shield."),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textMuted(context),
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Intake Breakdown Metric Chips (Taken, Delayed, Missed, PRN)
                Row(
                  children: [
                    _buildIntakeMetric(
                      context: context,
                      label: 'Taken',
                      count: totalTaken,
                      color: isDark ? AppTheme.successGreenLight : AppTheme.successGreen,
                      icon: Icons.check_circle_rounded,
                    ),
                    const SizedBox(width: 6),
                    _buildIntakeMetric(
                      context: context,
                      label: 'Delayed',
                      count: totalDelayed,
                      color: isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber,
                      icon: Icons.schedule_rounded,
                    ),
                    const SizedBox(width: 6),
                    _buildIntakeMetric(
                      context: context,
                      label: 'Missed',
                      count: totalMissed,
                      color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                      icon: Icons.cancel_rounded,
                    ),
                    const SizedBox(width: 6),
                    _buildIntakeMetric(
                      context: context,
                      label: 'PRN',
                      count: totalNotNeeded,
                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                      icon: Icons.remove_circle_outline_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 7-Day Flame Track (Duolingo Style M - T - W - T - F - S - S)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.cardBorder(context)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: streakData.weeklyDayStatus.map((day) {
                      return _buildDayChip(context, day, isDark, flameColorStart, flameColorEnd);
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntakeMetric({
    required BuildContext context,
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    final isDark = AppTheme.isDark(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.14 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.35 : 0.20),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 11, color: color),
                const SizedBox(width: 3),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayChip(
    BuildContext context,
    DayStreakStatus day,
    bool isDark,
    Color flameStart,
    Color flameEnd,
  ) {
    if (day.isCompleted) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [flameStart, flameEnd],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.shield_rounded, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            day.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
            ),
          ),
        ],
      );
    }

    if (day.isToday) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: flameStart,
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.hourglass_top_rounded,
                size: 14,
                color: flameStart,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            day.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: flameStart,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppTheme.textMuted(context),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          day.label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted(context),
          ),
        ),
      ],
    );
  }

  void _showStreakMilestonesSheet(BuildContext context, StreakData streakData) {
    final isDark = AppTheme.isDark(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF151E2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_rounded, color: Color(0xFF0D9488), size: 26),
                        const SizedBox(width: 8),
                        Text(
                          'Vital Continuity & Milestones',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(ctx),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Maintaining continuous medication adherence preserves steady therapeutic plasma equilibrium and shields against health complications.',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary(ctx), height: 1.3),
                ),
                const SizedBox(height: 18),

                // Streak Stats Grid
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant(ctx),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.cardBorder(ctx)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.shield_rounded, color: Color(0xFF0D9488), size: 22),
                            const SizedBox(height: 4),
                            Text(
                              '${streakData.currentStreak}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary(ctx),
                              ),
                            ),
                            Text(
                              'Protected Days',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(ctx)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant(ctx),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.cardBorder(ctx)),
                        ),
                        child: Column(
                          children: [
                            const Text('⚡', style: TextStyle(fontSize: 22)),
                            const SizedBox(height: 4),
                            Text(
                              '${streakData.longestStreak}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary(ctx),
                              ),
                            ),
                            Text(
                              'Best Streak',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(ctx)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant(ctx),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.cardBorder(ctx)),
                        ),
                        child: Column(
                          children: [
                            const Text('🛡️', style: TextStyle(fontSize: 22)),
                            const SizedBox(height: 4),
                            Text(
                              '${streakData.streakShields}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary(ctx),
                              ),
                            ),
                            Text(
                              'Streak Shield',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(ctx)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Next Milestone Progress
                if (streakData.nextMilestone != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          streakData.nextMilestone!.accentColor.withValues(alpha: isDark ? 0.25 : 0.12),
                          streakData.nextMilestone!.accentColor.withValues(alpha: isDark ? 0.08 : 0.04),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: streakData.nextMilestone!.accentColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(streakData.nextMilestone!.badgeEmoji, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Next: ${streakData.nextMilestone!.title} (${streakData.nextMilestone!.requiredDays} Days)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppTheme.textPrimary(ctx),
                                ),
                              ),
                            ),
                            Text(
                              '${(streakData.progressToNext * 100).toInt()}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: streakData.nextMilestone!.accentColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: streakData.progressToNext,
                            minHeight: 8,
                            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(streakData.nextMilestone!.accentColor),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${streakData.nextMilestone!.requiredDays - streakData.currentStreak} day(s) until your next milestone reward!',
                          style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary(ctx)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Milestones Badges List
                Text(
                  'Milestones & Trophy Badges',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(ctx),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: StreakMilestone.allMilestones.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final m = StreakMilestone.allMilestones[idx];
                      final isUnlocked = streakData.currentStreak >= m.requiredDays;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isUnlocked
                              ? m.accentColor.withValues(alpha: isDark ? 0.18 : 0.08)
                              : AppTheme.surfaceVariant(ctx),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isUnlocked ? m.accentColor : AppTheme.cardBorder(ctx),
                            width: isUnlocked ? 1.4 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(m.badgeEmoji, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: isUnlocked ? AppTheme.textPrimary(ctx) : AppTheme.textMuted(ctx),
                                    ),
                                  ),
                                  Text(
                                    m.description,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isUnlocked ? AppTheme.textSecondary(ctx) : AppTheme.textMuted(ctx),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isUnlocked)
                              Icon(Icons.check_circle_rounded, color: m.accentColor, size: 20)
                            else
                              Text(
                                '${m.requiredDays}d',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.textMuted(ctx),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
