import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/services/device_integration_service.dart';
import 'package:medisync/core/services/storage_service.dart';
import 'package:medisync/core/theme/app_theme.dart';
import 'package:medisync/features/homeboard/presentation/widgets/adherence_streak_card.dart';

class RecordsPage extends ConsumerStatefulWidget {
  const RecordsPage({super.key});

  @override
  ConsumerState<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends ConsumerState<RecordsPage> {
  String? _selectedMedId; // null = all medications
  String _statusFilter = 'all'; // 'all', 'active', 'discontinued'
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
          if (status == DoseStatus.taken || status == DoseStatus.takenEarly) hasTaken = true;
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
          // 0. Unified Vital Continuity & Adherence Dashboard
          AdherenceStreakCard(medications: medications),
          const SizedBox(height: 18),

          // 1. Interactive Calendar Widget (Days & Weeks with Adherence Indicators)
          _buildInteractiveCalendarWidget(medications, isDark, primary, secondary),
          const SizedBox(height: 20),

          // 2. Medication Filter Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Per-Medicine Continuity Rates',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          // Status Filters: All | Active Only | Discontinued Only
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                ChoiceChip(
                  avatar: Icon(Icons.list_alt_rounded, size: 15, color: _statusFilter == 'all' ? Colors.white : AppTheme.textSecondary(context)),
                  label: Text('All (${medications.length})'),
                  selected: _statusFilter == 'all',
                  selectedColor: primary,
                  backgroundColor: AppTheme.surfaceVariant(context),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _statusFilter == 'all' ? FontWeight.bold : FontWeight.w500,
                    color: _statusFilter == 'all' ? Colors.white : AppTheme.textPrimary(context),
                  ),
                  onSelected: (_) => setState(() {
                    _statusFilter = 'all';
                    _selectedMedId = null;
                  }),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: Icon(Icons.check_circle_outline_rounded, size: 15, color: _statusFilter == 'active' ? Colors.white : const Color(0xFF0D9488)),
                  label: Text('Active (${medications.where((m) => !m.isDiscontinued).length})'),
                  selected: _statusFilter == 'active',
                  selectedColor: const Color(0xFF0D9488),
                  backgroundColor: AppTheme.surfaceVariant(context),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _statusFilter == 'active' ? FontWeight.bold : FontWeight.w500,
                    color: _statusFilter == 'active' ? Colors.white : AppTheme.textPrimary(context),
                  ),
                  onSelected: (_) => setState(() {
                    _statusFilter = 'active';
                    _selectedMedId = null;
                  }),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: Icon(Icons.history_toggle_off_rounded, size: 15, color: _statusFilter == 'discontinued' ? Colors.white : const Color(0xFF64748B)),
                  label: Text('Discontinued (${medications.where((m) => m.isDiscontinued).length})'),
                  selected: _statusFilter == 'discontinued',
                  selectedColor: const Color(0xFF475569),
                  backgroundColor: AppTheme.surfaceVariant(context),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _statusFilter == 'discontinued' ? FontWeight.bold : FontWeight.w500,
                    color: _statusFilter == 'discontinued' ? Colors.white : AppTheme.textPrimary(context),
                  ),
                  onSelected: (_) => setState(() {
                    _statusFilter = 'discontinued';
                    _selectedMedId = null;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Per-Medicine Specific Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All In Filter'),
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
                ...medications.where((m) {
                  if (_statusFilter == 'active' && m.isDiscontinued) return false;
                  if (_statusFilter == 'discontinued' && !m.isDiscontinued) return false;
                  return true;
                }).map((med) {
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
          ...(() {
            final filteredMeds = medications.where((m) {
              if (_statusFilter == 'active' && m.isDiscontinued) return false;
              if (_statusFilter == 'discontinued' && !m.isDiscontinued) return false;
              if (_selectedMedId != null && m.id != _selectedMedId) return false;
              return true;
            }).toList();

            if (filteredMeds.isEmpty) {
              return [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.filter_alt_off_rounded, size: 40, color: AppTheme.textMuted(context)),
                      const SizedBox(height: 8),
                      Text(
                        'No medications matching "$_statusFilter" filter.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ];
            }

            return filteredMeds.map((med) => _buildContinuityCard(med, isDark, primary));
          })(),

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
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        headerMonthYear,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
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
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                _buildLegendDot(isDark ? AppTheme.successGreenLight : AppTheme.successGreen, 'Taken'),
                _buildLegendDot(isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber, 'Delayed'),
                _buildLegendDot(isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed, 'Missed'),
                _buildLegendDot(isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade600, 'Not Needed'),
              ],
            ),
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

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDate = date;
            _focusedDate = date;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 8),
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
        color: med.isDiscontinued
            ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
            : AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: med.isDiscontinued
              ? (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))
              : AppTheme.cardBorder(context),
          width: 1.2,
        ),
        boxShadow: med.isDiscontinued ? [] : AppTheme.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: med.isDiscontinued
                    ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                    : activeColor.withValues(alpha: isDark ? 0.25 : 0.15),
                child: Icon(
                  med.isDiscontinued ? Icons.history_toggle_off_rounded : med.icon,
                  size: 18,
                  color: med.isDiscontinued
                      ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                      : activeColor,
                ),
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
                        color: med.isDiscontinued
                            ? (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))
                            : AppTheme.textPrimary(context),
                      ),
                    ),
                    Text(
                      med.isDiscontinued
                          ? 'DISCONTINUED • Form: ${med.form.name.toUpperCase()}'
                          : 'Form: ${med.form.name.toUpperCase()} • ${med.scheduleFrequency.name}',
                      style: TextStyle(
                        fontSize: 11,
                        color: med.isDiscontinued ? const Color(0xFF64748B) : AppTheme.textSecondary(context),
                        fontWeight: med.isDiscontinued ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (med.isDiscontinued)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_toggle_off_rounded,
                        size: 12,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Discontinued',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                )
              else
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
    final isDark = AppTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;
    var currentFormat = ReportExportFormat.text;
    var isMarkdownRenderedView = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF151E2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (bottomSheetContext, setModalState) {
            final reportContent = integrationService.generateContinuityReportFormatted(
              medications: medications,
              profile: profile,
              format: currentFormat,
            );

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.88,
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Continuity Clinical Record',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary(ctx),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '100% On-Device • Multi-Format Export',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(ctx)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Format Selector Chips (Text, Markdown, PDF)
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: ReportExportFormat.values.map((fmt) {
                                  final isSelected = currentFormat == fmt;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(fmt.label),
                                      selected: isSelected,
                                      selectedColor: primary.withValues(alpha: isDark ? 0.35 : 0.20),
                                      side: BorderSide(
                                        color: isSelected ? primary : AppTheme.cardBorder(ctx),
                                      ),
                                      labelStyle: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? primary : AppTheme.textSecondary(ctx),
                                      ),
                                      onSelected: (val) {
                                        if (val) {
                                          setModalState(() {
                                            currentFormat = fmt;
                                          });
                                        }
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Optional Markdown View Mode Switcher (Rendered vs Raw Monospace)
                      if (currentFormat == ReportExportFormat.markdown) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Markdown Viewer:',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondary(ctx),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => setModalState(() => isMarkdownRenderedView = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isMarkdownRenderedView
                                      ? primary.withValues(alpha: isDark ? 0.35 : 0.20)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isMarkdownRenderedView ? primary : AppTheme.cardBorder(ctx),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.visibility_rounded, size: 14, color: isMarkdownRenderedView ? primary : AppTheme.textSecondary(ctx)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Rendered Document',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isMarkdownRenderedView ? FontWeight.bold : FontWeight.normal,
                                        color: isMarkdownRenderedView ? primary : AppTheme.textSecondary(ctx),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => setModalState(() => isMarkdownRenderedView = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: !isMarkdownRenderedView
                                      ? primary.withValues(alpha: isDark ? 0.35 : 0.20)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: !isMarkdownRenderedView ? primary : AppTheme.cardBorder(ctx),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.code_rounded, size: 14, color: !isMarkdownRenderedView ? primary : AppTheme.textSecondary(ctx)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Raw Monospace',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: !isMarkdownRenderedView ? FontWeight.bold : FontWeight.normal,
                                        color: !isMarkdownRenderedView ? primary : AppTheme.textSecondary(ctx),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),

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
                            child: (currentFormat == ReportExportFormat.pdf || (currentFormat == ReportExportFormat.markdown && isMarkdownRenderedView))
                                ? _buildMarkdownRenderedContent(reportContent, isDark, primary, ctx)
                                : SelectableText(
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

                      // Action Buttons: Share & Copy
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: reportContent));
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('✓ Copied ${currentFormat.label} report to clipboard!'),
                                    backgroundColor: primary,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: const Text('Copy Text'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () async {
                                if (currentFormat == ReportExportFormat.pdf) {
                                  final title = 'MediSync_Continuity_Report_${profile.name}.pdf';
                                  await integrationService.sharePdfReport(
                                    title: title,
                                    patientName: profile.name,
                                    content: reportContent,
                                  );
                                  return;
                                }
                                final title = 'MediSync_Continuity_Report_${profile.name}${currentFormat.fileExtension}';
                                await integrationService.shareReport(
                                  text: reportContent,
                                  title: title,
                                  mimeType: currentFormat.mimeType,
                                );
                              },
                              icon: const Icon(Icons.share_rounded, size: 16),
                              label: Text('Share ${currentFormat.fileExtension}'),
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
      },
    );
  }

  /// Visual Markdown Renderer: Converts GFM markdown text into rich Flutter UI widgets.
  Widget _buildMarkdownRenderedContent(String markdown, bool isDark, Color primary, BuildContext ctx) {
    final lines = markdown.split('\n');
    final widgets = <Widget>[];

    int i = 0;
    while (i < lines.length) {
      final line = lines[i].trimRight();

      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        i++;
        continue;
      }

      // 1. Horizontal Rules
      if (line.trim() == '---' || line.trim() == '***') {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ));
        i++;
        continue;
      }

      // 2. Blockquotes / Callout Cards (starts with '>')
      if (line.startsWith('>')) {
        final bLines = <String>[];
        bool isAlert = false;
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          final clean = lines[i].replaceFirst(RegExp(r'^>\s?'), '').trim();
          if (clean.contains('[!IMPORTANT]') || clean.contains('[!WARNING]')) {
            isAlert = true;
          } else if (clean.isNotEmpty) {
            bLines.add(clean);
          }
          i++;
        }
        widgets.add(Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isAlert
                ? (isDark ? const Color(0xFF451A03).withValues(alpha: 0.35) : const Color(0xFFFFFBEB))
                : (isDark ? const Color(0xFF0F2926) : const Color(0xFFF0FDFA)),
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(
                color: isAlert ? const Color(0xFFF59E0B) : const Color(0xFF0D9488),
                width: 4,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: bLines.map((l) => _buildFormattedText(l, isDark, primary, fontSize: 11.5)).toList(),
          ),
        ));
        continue;
      }

      // 3. Markdown Tables (starts with '|')
      if (line.startsWith('|') && line.endsWith('|')) {
        final tableLines = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('|') && lines[i].trim().endsWith('|')) {
          tableLines.add(lines[i].trim());
          i++;
        }
        if (tableLines.length >= 2) {
          final headerCells = tableLines[0]
              .split('|')
              .where((c) => c.isNotEmpty)
              .map((c) => c.trim())
              .toList();
          final dataRows = <List<String>>[];
          for (int r = 1; r < tableLines.length; r++) {
            if (tableLines[r].contains('---') || tableLines[r].contains(':---')) continue;
            final cells = tableLines[r]
                .split('|')
                .where((c) => c.isNotEmpty)
                .map((c) => c.trim())
                .toList();
            dataRows.add(cells);
          }

          widgets.add(Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  ),
                  headingTextStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                  dataTextStyle: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  columns: headerCells.map((h) => DataColumn(label: Text(h))).toList(),
                  rows: dataRows.map((row) {
                    return DataRow(
                      cells: List.generate(headerCells.length, (colIdx) {
                        final val = colIdx < row.length ? row[colIdx] : '';
                        return DataCell(_buildFormattedText(val, isDark, primary, fontSize: 11));
                      }),
                    );
                  }).toList(),
                ),
              ),
            ),
          ));
        }
        continue;
      }

      // 4. Headers (#, ##, ###, ####)
      if (line.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            line.substring(2).trim(),
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: primary),
          ),
        ));
      } else if (line.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            line.substring(3).trim(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ));
      } else if (line.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Text(
            line.substring(4).trim(),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF0369A1),
            ),
          ),
        ));
      } else if (line.startsWith('#### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(
            line.substring(5).trim(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
            ),
          ),
        ));
      } else if (line.startsWith('* ') || line.startsWith('- ')) {
        // 5. Bullet Lists
        final itemText = line.substring(2).trim();
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: primary)),
              Expanded(child: _buildFormattedText(itemText, isDark, primary, fontSize: 11.5)),
            ],
          ),
        ));
      } else {
        // 6. Regular Paragraphs
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _buildFormattedText(line, isDark, primary, fontSize: 11.5),
        ));
      }

      i++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Parses inline markdown formatting (bold `**`, code `` ` ``) into a RichText widget.
  Widget _buildFormattedText(String text, bool isDark, Color primary, {double fontSize = 11.5}) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'(\*\*.*?\*\*|`.*?`)');
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: TextStyle(
            fontSize: fontSize,
            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
          ),
        ));
      }
      final matched = match.group(0)!;
      if (matched.startsWith('**') && matched.endsWith('**')) {
        spans.add(TextSpan(
          text: matched.substring(2, matched.length - 2),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ));
      } else if (matched.startsWith('`') && matched.endsWith('`')) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              matched.substring(1, matched.length - 1),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: fontSize - 0.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
              ),
            ),
          ),
        ));
      }
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: TextStyle(
          fontSize: fontSize,
          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }
}
