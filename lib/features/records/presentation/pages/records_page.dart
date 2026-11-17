import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/services/device_integration_service.dart';
import 'package:medisync/core/services/storage_service.dart';
import 'package:medisync/core/theme/app_theme.dart';

class RecordsPage extends ConsumerStatefulWidget {
  const RecordsPage({super.key});

  @override
  ConsumerState<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends ConsumerState<RecordsPage> {
  String? _selectedMedId; // null = all medications
  late DateTime _selectedDate;
  late DateTime _focusedDate;
  bool _isMonthViewExpanded = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _focusedDate = DateTime(now.year, now.month, now.day);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _weekStartDate(DateTime date) {
    final currentWeekday = date.weekday; // 1 = Monday, 7 = Sunday
    final monday = date.subtract(Duration(days: currentWeekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  List<DateTime> _getWeekDates(DateTime weekStart) {
    return List.generate(7, (index) {
      return weekStart.add(Duration(days: index));
    });
  }

  int _calculateAdherenceStreak(List<Medication> medications) {
    if (medications.isEmpty) return 0;
    final now = DateTime.now();
    int streak = 0;

    for (int dayOffset = 0; dayOffset < 60; dayOffset++) {
      final checkDate = now.subtract(Duration(days: dayOffset));
      bool hadScheduledMeds = false;
      bool allTakenOrNotNeeded = true;

      for (final med in medications) {
        if (med.isActiveOn(checkDate)) {
          hadScheduledMeds = true;
          for (final time in med.scheduledTimes) {
            final status = med.getDoseStatus(checkDate, time);
            if (status == DoseStatus.missed) {
              allTakenOrNotNeeded = false;
              break;
            }
            if (dayOffset > 0 && status == DoseStatus.pending) {
              allTakenOrNotNeeded = false;
              break;
            }
          }
        }
        if (!allTakenOrNotNeeded) break;
      }

      if (hadScheduledMeds) {
        if (allTakenOrNotNeeded) {
          streak++;
        } else {
          if (dayOffset == 0) continue;
          break;
        }
      }
    }
    return streak;
  }

  Color _getDayStatusColor(DateTime date, List<Medication> medications, bool isDark) {
    bool hasMissed = false;
    bool hasDelayed = false;
    bool hasTaken = false;
    bool hasNotNeeded = false;
    int totalDoses = 0;

    for (final med in medications) {
      if (_selectedMedId != null && med.id != _selectedMedId) continue;
      if (med.isActiveOn(date)) {
        for (final time in med.scheduledTimes) {
          totalDoses++;
          final status = med.getDoseStatus(date, time);
          if (status == DoseStatus.missed) hasMissed = true;
          if (status == DoseStatus.delayed) hasDelayed = true;
          if (status == DoseStatus.taken) hasTaken = true;
          if (status == DoseStatus.notNeeded) hasNotNeeded = true;
        }
      }
    }

    if (totalDoses == 0) return Colors.transparent;
    if (hasMissed) return isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed;
    if (hasDelayed) return isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber;
    if (hasTaken) return isDark ? AppTheme.successGreenLight : AppTheme.successGreen;
    if (hasNotNeeded) return isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade600;
    return AppTheme.textMuted(context);
  }

  @override
  Widget build(BuildContext context) {
    final medications = ref.watch(medicationsNotifierProvider);
    final profile = ref.watch(profileNotifierProvider);
    final isDark = AppTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Continuity & Intake Log',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary(context),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Export Continuity Report (Consented)',
            icon: const Icon(Icons.description_rounded),
            onPressed: () => _showExportConsentDialog(medications, profile),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Overall Continuity Dashboard (Top Hero Card)
          _buildOverallContinuityDashboard(medications, isDark, primary, secondary),
          const SizedBox(height: 18),

          // 2. Interactive Calendar Widget (Days & Weeks with Adherence Indicators)
          _buildInteractiveCalendarWidget(medications, isDark, primary, secondary),
          const SizedBox(height: 18),

          // 3. Daily Intake Log for Selected Date
          _buildDailyIntakeLogSection(medications, isDark, primary),
          const SizedBox(height: 20),

          // 4. Medication Filter Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Per-Medicine Continuity Rates',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              if (_selectedMedId != null)
                TextButton(
                  onPressed: () => setState(() => _selectedMedId = null),
                  child: const Text('Show All', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All Medications'),
                    selected: _selectedMedId == null,
                    selectedColor: primary,
                    backgroundColor: AppTheme.surfaceVariant(context),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: _selectedMedId == null ? FontWeight.bold : FontWeight.normal,
                      color: _selectedMedId == null
                          ? Colors.white
                          : AppTheme.textPrimary(context),
                    ),
                    onSelected: (_) => setState(() => _selectedMedId = null),
                  ),
                ),
                ...medications.map((med) {
                  final isSel = _selectedMedId == med.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(med.name),
                      selected: isSel,
                      selectedColor: primary,
                      backgroundColor: AppTheme.surfaceVariant(context),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel
                            ? Colors.white
                            : AppTheme.textPrimary(context),
                      ),
                      onSelected: (_) => setState(() => _selectedMedId = med.id),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 5. Individual Medication Continuity Cards
          ...medications
              .where((m) => _selectedMedId == null || m.id == _selectedMedId)
              .map((med) => _buildContinuityCard(med, isDark, primary)),

          const SizedBox(height: 20),

          // 6. Consent-Gated Export Call-to-Action Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.cardBorder(context)),
              boxShadow: AppTheme.softShadow(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, color: primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Physician Continuity Report',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Compile a structured clinical report of all doses taken, delayed, missed, and not needed since medication start. Requires verified patient consent before export.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showExportConsentDialog(medications, profile),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Export Continuity Record (Consent Required)'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 7. Strict Privacy & Local-First Shield Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1E2E) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFDCFCE7),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: 20,
                  color: isDark ? AppTheme.successGreenLight : AppTheme.successGreen,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '100% On-Device Medical Confidentiality',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.successGreenLight : AppTheme.successGreen,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'All timestamps and continuity logs are kept locally on your phone. No data leaves without your manual action.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary(context),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 90),
        ],
      ),
    );
  }

  // ==========================================
  // TOP OVERALL CONTINUITY DASHBOARD
  // ==========================================
  Widget _buildOverallContinuityDashboard(
    List<Medication> medications,
    bool isDark,
    Color primary,
    Color secondary,
  ) {
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
    final streakDays = _calculateAdherenceStreak(medications);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  primary.withValues(alpha: 0.88),
                  secondary.withValues(alpha: 0.75),
                ]
              : [
                  primary,
                  secondary,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          ...AppTheme.glowShadow(primary, opacity: isDark ? 0.35 : 0.24),
          ...AppTheme.elevatedShadow(context),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.analytics_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'CONTINUITY DASHBOARD',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$adherenceRate% Adherence',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      streakDays > 0
                          ? '🔥 $streakDays-day consecutive adherence streak'
                          : '${medications.length} active medication regimen(s)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.22),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                ),
                child: Center(
                  child: Icon(
                    adherenceRate >= 80 ? Icons.verified_rounded : Icons.healing_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 4-Stat Metric Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDashboardMetric(
                  label: 'Taken',
                  count: totalTaken,
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF6EE7B7),
                ),
                _buildMetricDivider(),
                _buildDashboardMetric(
                  label: 'Delayed',
                  count: totalDelayed,
                  icon: Icons.schedule_rounded,
                  color: const Color(0xFFFDE047),
                ),
                _buildMetricDivider(),
                _buildDashboardMetric(
                  label: 'Missed',
                  count: totalMissed,
                  icon: Icons.cancel_rounded,
                  color: const Color(0xFFFCA5A5),
                ),
                _buildMetricDivider(),
                _buildDashboardMetric(
                  label: 'Not Needed',
                  count: totalNotNeeded,
                  icon: Icons.remove_circle_outline_rounded,
                  color: const Color(0xFFE2E8F0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      width: 1,
      height: 26,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  Widget _buildDashboardMetric({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // INTERACTIVE CALENDAR WIDGET (DAYS & WEEKS)
  // ==========================================
  Widget _buildInteractiveCalendarWidget(
    List<Medication> medications,
    bool isDark,
    Color primary,
    Color secondary,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = _weekStartDate(_focusedDate);
    final weekDates = _getWeekDates(weekStart);
    final headerMonthYear = DateFormat('MMMM yyyy').format(_focusedDate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder(context)),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Month, Year, Arrows, Today jump, & Expand toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    headerMonthYear,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Jump to Today Button
                  InkWell(
                    onTap: () {
                      setState(() {
                        _focusedDate = today;
                        _selectedDate = today;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: isDark ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Month View Extend Toggle
                  IconButton(
                    tooltip: _isMonthViewExpanded ? 'Collapse to Week' : 'Expand Month',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      _isMonthViewExpanded ? Icons.view_week_rounded : Icons.calendar_view_month_rounded,
                      size: 20,
                      color: primary,
                    ),
                    onPressed: () {
                      setState(() {
                        _isMonthViewExpanded = !_isMonthViewExpanded;
                      });
                    },
                  ),
                  // Prev Week / Month
                  IconButton(
                    tooltip: _isMonthViewExpanded ? 'Previous Month' : 'Previous Week',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chevron_left_rounded, size: 22),
                    onPressed: () {
                      setState(() {
                        if (_isMonthViewExpanded) {
                          _focusedDate = DateTime(_focusedDate.year, _focusedDate.month - 1, 1);
                        } else {
                          _focusedDate = _focusedDate.subtract(const Duration(days: 7));
                        }
                      });
                    },
                  ),
                  // Next Week / Month
                  IconButton(
                    tooltip: _isMonthViewExpanded ? 'Next Month' : 'Next Week',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chevron_right_rounded, size: 22),
                    onPressed: () {
                      setState(() {
                        if (_isMonthViewExpanded) {
                          _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + 1, 1);
                        } else {
                          _focusedDate = _focusedDate.add(const Duration(days: 7));
                        }
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // View Content: Week Strip or Extended Month Grid
          if (!_isMonthViewExpanded)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weekDates.map((date) {
                return _buildCalendarDayItem(
                  date: date,
                  today: today,
                  medications: medications,
                  isDark: isDark,
                  primary: primary,
                );
              }).toList(),
            )
          else
            _buildExtendedMonthGrid(medications, isDark, primary, today),

          const SizedBox(height: 12),
          // Adherence Indicator Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendDot(isDark ? AppTheme.successGreenLight : AppTheme.successGreen, 'Taken'),
              const SizedBox(width: 14),
              _buildLegendDot(isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber, 'Delayed'),
              const SizedBox(width: 14),
              _buildLegendDot(isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed, 'Missed'),
              const SizedBox(width: 14),
              _buildLegendDot(isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade600, 'Not Needed'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondary(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarDayItem({
    required DateTime date,
    required DateTime today,
    required List<Medication> medications,
    required bool isDark,
    required Color primary,
  }) {
    final isSelected = _isSameDay(date, _selectedDate);
    final isTodayDate = _isSameDay(date, today);
    final dayAbbr = DateFormat('E').format(date).substring(0, 3);
    final dayNum = date.day.toString();
    final dotColor = _getDayStatusColor(date, medications, isDark);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = date;
          _focusedDate = date;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primary
              : (isTodayDate
                  ? primary.withValues(alpha: isDark ? 0.25 : 0.15)
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(16),
          border: isTodayDate && !isSelected
              ? Border.all(color: primary, width: 1.5)
              : null,
          boxShadow: isSelected
              ? AppTheme.glowShadow(primary, opacity: 0.3)
              : null,
        ),
        child: Column(
          children: [
            Text(
              dayAbbr,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textSecondary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dayNum,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: 4),
            // Dose Status Dot
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Colors.white
                    : dotColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtendedMonthGrid(
    List<Medication> medications,
    bool isDark,
    Color primary,
    DateTime today,
  ) {
    final year = _focusedDate.year;
    final month = _focusedDate.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leadingEmptyDays = firstDayOfMonth.weekday - 1; // 1 = Monday

    final totalCells = leadingEmptyDays + daysInMonth;
    final totalRows = (totalCells / 7).ceil();

    return Column(
      children: [
        // Weekday header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) {
            return SizedBox(
              width: 36,
              child: Text(
                d,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMuted(context),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        // Day cells
        for (int r = 0; r < totalRows; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (c) {
                final cellIndex = r * 7 + c;
                final dayNum = cellIndex - leadingEmptyDays + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const SizedBox(width: 36, height: 36);
                }
                final date = DateTime(year, month, dayNum);
                final isSelected = _isSameDay(date, _selectedDate);
                final isTodayDate = _isSameDay(date, today);
                final dotColor = _getDayStatusColor(date, medications, isDark);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                    });
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primary
                          : (isTodayDate
                              ? primary.withValues(alpha: isDark ? 0.25 : 0.15)
                              : Colors.transparent),
                      shape: BoxShape.circle,
                      border: isTodayDate && !isSelected
                          ? Border.all(color: primary, width: 1.5)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected || isTodayDate ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textPrimary(context),
                          ),
                        ),
                        if (dotColor != Colors.transparent)
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.only(top: 1),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? Colors.white : dotColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  // ==========================================
  // DAILY INTAKE LOG SECTION FOR SELECTED DATE
  // ==========================================
  Widget _buildDailyIntakeLogSection(List<Medication> medications, bool isDark, Color primary) {
    final formattedDateTitle = DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate);

    final dayDoses = <Map<String, dynamic>>[];
    for (final med in medications) {
      if (_selectedMedId != null && med.id != _selectedMedId) continue;
      if (med.isActiveOn(_selectedDate)) {
        for (final time in med.scheduledTimes) {
          final status = med.getDoseStatus(_selectedDate, time);
          dayDoses.add({
            'med': med,
            'time': time,
            'status': status,
          });
        }
      }
    }

    dayDoses.sort((a, b) => (a['time'] as String).compareTo(b['time'] as String));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Intake Log',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  Text(
                    formattedDateTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBorder(context)),
              ),
              child: Text(
                '${dayDoses.length} dose${dayDoses.length == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (dayDoses.isEmpty)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder(context)),
            ),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.event_available_rounded, size: 36, color: AppTheme.textMuted(context)),
                const SizedBox(height: 8),
                Text(
                  'No medication doses logged or scheduled for $formattedDateTitle.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary(context)),
                ),
              ],
            ),
          )
        else
          ...dayDoses.map((doseItem) {
            final med = doseItem['med'] as Medication;
            final time = doseItem['time'] as String;
            final status = doseItem['status'] as DoseStatus;
            return _buildDailyDoseTile(med, time, status, isDark);
          }),
      ],
    );
  }

  Widget _buildDailyDoseTile(
    Medication med,
    String time,
    DoseStatus status,
    bool isDark,
  ) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case DoseStatus.taken:
        statusColor = isDark ? AppTheme.successGreenLight : AppTheme.successGreen;
        statusLabel = 'Taken On Time';
        statusIcon = Icons.check_circle_rounded;
        break;
      case DoseStatus.delayed:
        statusColor = isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber;
        statusLabel = 'Taken Delayed';
        statusIcon = Icons.schedule_rounded;
        break;
      case DoseStatus.missed:
        statusColor = isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed;
        statusLabel = 'Missed Window';
        statusIcon = Icons.cancel_rounded;
        break;
      case DoseStatus.notNeeded:
        statusColor = isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade700;
        statusLabel = 'Not Needed (PRN)';
        statusIcon = Icons.remove_circle_outline_rounded;
        break;
      case DoseStatus.pending:
        statusColor = AppTheme.textSecondary(context);
        statusLabel = 'Pending';
        statusIcon = Icons.hourglass_empty_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder(context)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 20, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${med.name} • ${med.dosage}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                Text(
                  'Scheduled for $time',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PER-MEDICATION CONTINUITY CARD
  // ==========================================
  Widget _buildContinuityCard(Medication med, bool isDark, Color activeColor) {
    final stats = med.continuityStats;
    final total = stats['taken']! + stats['delayed']! + stats['missed']!;
    final rate = total > 0 ? (stats['taken']! / total * 100).round() : 100;
    final lastTaken = med.lastTakenDateTime;
    final lastTakenStr = lastTaken != null
        ? DateFormat('MMM d, hh:mm a').format(lastTaken)
        : 'No doses logged yet';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder(context)),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: activeColor.withValues(alpha: isDark ? 0.25 : 0.15),
                child: Icon(med.icon, size: 18, color: activeColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${med.name} (${med.dosage})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    Text(
                      'Form: ${med.form.name.toUpperCase()} • ${med.scheduleFrequency.name}',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: rate >= 80
                      ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5))
                      : (isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$rate% On-Time',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: rate >= 80
                        ? (isDark ? AppTheme.successGreenLight : AppTheme.successGreen)
                        : (isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppTheme.cardBorder(context)),
          const SizedBox(height: 10),

          // Start Date & Last Taken Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Started On',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MMM dd, yyyy').format(med.startDate),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Taken',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastTakenStr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Intake Statistics Breakdown Pills
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildStatPill(
                label: 'Taken: ${stats['taken']}',
                color: isDark ? AppTheme.successGreenLight : AppTheme.successGreen,
                bgColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
                icon: Icons.check_circle_rounded,
              ),
              _buildStatPill(
                label: 'Delayed: ${stats['delayed']}',
                color: isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber,
                bgColor: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
                icon: Icons.schedule_rounded,
              ),
              _buildStatPill(
                label: 'Missed: ${stats['missed']}',
                color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                bgColor: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                icon: Icons.cancel_rounded,
              ),
              if (stats['notNeeded']! > 0 || med.scheduleFrequency == ScheduleFrequency.asNeeded)
                _buildStatPill(
                  label: 'Not Needed: ${stats['notNeeded']}',
                  color: isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade700,
                  bgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  icon: Icons.remove_circle_outline_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill({
    required String label,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // EXPORT CONTINUITY CONSENT DIALOG
  // ==========================================
  void _showExportConsentDialog(List<Medication> medications, dynamic profile) {
    final isDark = AppTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;
    bool isConsentChecked = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF151E2E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              title: Row(
                children: [
                  Icon(
                    Icons.security_rounded,
                    color: primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Patient Consent Required',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(ctx),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MediSync enforces absolute local privacy. Your medical history cannot leave this device without your explicit call to action.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(ctx), height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant(ctx),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Report Contents:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary(ctx),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('• Start and latest intake timestamps', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(ctx))),
                          Text('• Complete on-time, delayed, missed & PRN stats', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(ctx))),
                          Text('• Recorded drug allergies and dietary advisories', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(ctx))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isConsentChecked,
                      onChanged: (val) {
                        setDialogState(() {
                          isConsentChecked = val ?? false;
                        });
                      },
                      title: Text(
                        'I explicitly consent to generate an unencrypted patient continuity file on this device.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary(ctx),
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isConsentChecked
                      ? () {
                          Navigator.pop(ctx);
                          _generateAndDisplayReport(medications, profile);
                        }
                      : null,
                  child: const Text('Authorize & Generate'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _generateAndDisplayReport(List<Medication> medications, dynamic profile) {
    final integrationService = ref.read(deviceIntegrationServiceProvider);
    final reportContent = integrationService.generateContinuityReport(
      medications: medications,
      profile: profile,
    );

    final isDark = AppTheme.isDark(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF151E2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (dCtx, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Continuity Clinical Record',
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
                    'Generated on-device with verified patient consent.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(ctx)),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.cardBorder(ctx)),
                      ),
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: SelectableText(
                          reportContent,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: AppTheme.textPrimary(ctx),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Continuity report generated successfully on device.'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                          label: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
