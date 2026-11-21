import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medisync/core/data/medicines_database.dart';
import 'package:medisync/core/models/condition.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/models/safety_flag.dart';
import 'package:medisync/core/services/device_integration_service.dart';
import 'package:medisync/core/services/scheduler_service.dart';
import 'package:medisync/core/services/storage_service.dart';
import 'package:medisync/core/services/streak_service.dart';
import 'package:medisync/core/theme/app_theme.dart';
import 'package:medisync/features/homeboard/presentation/widgets/next_dose_countdown_card.dart';
import 'package:medisync/features/homeboard/presentation/widgets/expandable_add_medication_fab.dart';
import 'package:medisync/features/homeboard/presentation/widgets/missed_dose_guidance_sheet.dart';
import 'package:medisync/features/medications/presentation/pages/add_edit_medication_page.dart';
import 'package:medisync/features/medications/presentation/widgets/medication_clinical_guide_modal.dart';
import 'package:medisync/features/profile/presentation/widgets/emergency_health_card.dart';

class DoseItem {
  final Medication medication;
  final String time;
  final DoseStatus status;

  DoseItem({
    required this.medication,
    required this.time,
    required this.status,
  });

  bool get isTaken => status == DoseStatus.taken || status == DoseStatus.delayed;
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late DateTime _selectedDate;
  int _weekOffset = 0; // -1 = Previous week, 0 = Current week, 1 = Next week

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLockscreenLaunch();
    });
  }

  Future<void> _checkLockscreenLaunch() async {
    final action = await ref.read(deviceIntegrationServiceProvider).getInitialLockscreenAction();
    if (action != null && mounted) {
      final profile = ref.read(profileNotifierProvider);
      final meds = ref.read(medicationsNotifierProvider);
      showEmergencyCardDialog(context, profile: profile, medications: meds);
    }
  }

  // Calculate week's dates (Monday to Sunday) factoring in _weekOffset (-1, 0, 1)
  List<DateTime> _getCurrentWeekDates() {
    final now = DateTime.now();
    final currentWeekday = now.weekday; // 1 = Monday, 7 = Sunday
    final targetMonday = now.subtract(Duration(days: currentWeekday - 1)).add(Duration(days: _weekOffset * 7));

    return List.generate(7, (index) {
      final day = targetMonday.add(Duration(days: index));
      return DateTime(day.year, day.month, day.day);
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final medications = ref.watch(medicationsNotifierProvider);
    final profile = ref.watch(profileNotifierProvider);
    final now = DateTime.now();
    final isToday = _isSameDay(_selectedDate, now);
    final isDark = AppTheme.isDark(context);

    // Collect all doses for the selected day of the week
    final selectedDayDoses = <DoseItem>[];
    for (final med in medications) {
      if (med.isActiveOn(_selectedDate)) {
        for (final time in med.scheduledTimes) {
          selectedDayDoses.add(DoseItem(
            medication: med,
            time: time,
            status: med.getDoseStatus(_selectedDate, time),
          ));
        }
      }
    }

    // Sort chronologically by time
    selectedDayDoses.sort((a, b) => a.time.compareTo(b.time));

    final totalDoses = selectedDayDoses.length;
    final takenCount = selectedDayDoses.where((d) => d.status == DoseStatus.taken || d.status == DoseStatus.takenEarly).length;
    final delayedCount = selectedDayDoses.where((d) => d.status == DoseStatus.delayed).length;
    final missedCount = selectedDayDoses.where((d) => d.status == DoseStatus.missed).length;
    final notNeededCount = selectedDayDoses.where((d) => d.status == DoseStatus.notNeeded).length;
    final pendingCount = selectedDayDoses.where((d) => d.status == DoseStatus.pending).length;
    final progress = totalDoses == 0 ? 0.0 : ((takenCount + delayedCount + notNeededCount) / totalDoses).clamp(0.0, 1.0);
    final nextPendingDose = selectedDayDoses.where((d) => d.status == DoseStatus.pending).firstOrNull;

    // Check for critical safety flags
    final criticalFlags = <SafetyFlag>[];
    for (final m in medications) {
      for (final f in m.safetyFlags) {
        if (f.severity == FlagSeverity.critical) {
          criticalFlags.add(f);
        }
      }
    }

    // Companion meal alignments for selected day
    final mealLinkedDoses = selectedDayDoses.where((d) {
      final med = d.medication;
      return med.preConditions.any((c) => c.type == ConditionType.meal) ||
          med.postConditions.any((c) => c.type == ConditionType.meal) ||
          med.mealCondition != null;
    }).toList();

    final formattedScheduleTitle =
        isToday ? "Today's Schedule" : "${DateFormat('EEEE, MMM d').format(_selectedDate)} Schedule";
    final weekDates = _getCurrentWeekDates();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(74),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            boxShadow: [
              ...AppTheme.glowShadow(Theme.of(context).colorScheme.primary, opacity: 0.10),
              ...AppTheme.softShadow(context),
            ],
            border: Border(
              bottom: BorderSide(
                color: AppTheme.cardBorder(context),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Hello, ${profile.name.split(' ').first}',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Emergency Medical ID',
                        icon: const Icon(
                          Icons.contact_emergency_rounded,
                          color: Color(0xFFDC2626),
                          size: 26,
                        ),
                        onPressed: () => showEmergencyCardDialog(
                          context,
                          profile: profile,
                          medications: medications,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. Weekly Schedule Day Selector with Field of Depth
          _buildWeeklyDaySelector(weekDates, now, medications),
          const SizedBox(height: 16),

          // 2. Critical Allergy Alert Banner (if flagged)
          if (criticalFlags.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                  width: 1.5,
                ),
                boxShadow: AppTheme.glowShadow(AppTheme.dangerRed, opacity: 0.2),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_rounded,
                    color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Critical Allergy Alert Flagged',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          criticalFlags.first.message,
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
            const SizedBox(height: 16),
          ],

          // 3. Hero Next Dose Countdown Widget (shown on current day)
          if (isToday) ...[
            NextDoseCountdownCard(
              medications: medications,
              onMarkTaken: (medId, date, time) {
                ref
                    .read(medicationsNotifierProvider.notifier)
                    .toggleDoseTaken(medId, date, time);
              },
            ),
            const SizedBox(height: 16),
          ],

          // 4. Daily Adherence Progress Card (Dynamic Enhanced Height & Breakdown)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.90),
                        Theme.of(context).colorScheme.secondary.withValues(alpha: 0.80),
                      ]
                    : [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: AppTheme.glowShadow(
                Theme.of(context).colorScheme.primary,
                opacity: 0.28,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.event_note_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              formattedScheduleTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${(progress * 100).toInt()}% Done',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
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
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? Theme.of(context).colorScheme.secondary : const Color(0xFF5EEAD4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Dynamic Status Breakdown Chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildAdherencePill('✓ $takenCount Taken', Colors.white.withValues(alpha: 0.22)),
                    if (pendingCount > 0)
                      _buildAdherencePill('⏳ $pendingCount Due', Colors.white.withValues(alpha: 0.22)),
                    if (delayedCount > 0)
                      _buildAdherencePill('⏱ $delayedCount Delayed', const Color(0xFFFDE68A).withValues(alpha: 0.35)),
                    if (missedCount > 0)
                      _buildAdherencePill('⚠ $missedCount Missed', const Color(0xFFFCA5A5).withValues(alpha: 0.35)),
                    if (notNeededCount > 0)
                      _buildAdherencePill('🛡 $notNeededCount As-Needed', Colors.white.withValues(alpha: 0.22)),
                  ],
                ),
                const SizedBox(height: 12),

                // Next Due Preview or Completion Message
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        totalDoses == 0
                            ? Icons.bedtime_rounded
                            : (pendingCount == 0
                                ? Icons.stars_rounded
                                : Icons.alarm_rounded),
                        color: Colors.white.withValues(alpha: 0.95),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          totalDoses == 0
                              ? 'No medications scheduled for this day.'
                              : (pendingCount == 0
                                  ? 'Outstanding! All scheduled doses completed.'
                                  : 'Next Due: ${nextPendingDose!.medication.name} (${nextPendingDose.medication.dosage}) at ${nextPendingDose.time}'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 5. Smart Companion Meal Coordination Banner
          if (mealLinkedDoses.isNotEmpty) ...[
            _buildMealCoordinationBanner(mealLinkedDoses),
            const SizedBox(height: 20),
          ],

          // 6. Timeline Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Dose Timeline',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorder(context)),
                ),
                child: Text(
                  'Local Safe Storage',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Date Locking Notice for past or future days
          if (!isToday) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.cardBorder(context)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_clock_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedDate.isAfter(DateTime.now())
                          ? 'Viewing future schedule (${DateFormat('EEEE, d MMM').format(_selectedDate)}). Doses are locked and cannot be logged ahead of time.'
                          : 'Viewing historical schedule (${DateFormat('EEEE, d MMM').format(_selectedDate)}). Past records are locked in read-only mode.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 7. Dose Timeline Items
          if (selectedDayDoses.isEmpty) ...[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 20),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.cardColor(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.cardBorder(context)),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 54,
                      color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No medication doses due on this day',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Select another day on the calendar or add a new schedule.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
                    ),
                    const SizedBox(height: 14),
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
            for (final dose in selectedDayDoses)
              _DoseTimelineCard(
                dose: dose,
                date: _selectedDate,
                isLocked: !isToday,
                onUpdateStatus: (newStatus) {
                  ref
                      .read(medicationsNotifierProvider.notifier)
                      .setDoseStatus(
                        dose.medication.id,
                        _selectedDate,
                        dose.time,
                        newStatus,
                      );
                },
              ),
          ],
          // Extra bottom padding to ensure content is fully clear of the floating bottom bar
          const SizedBox(height: 90),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: const Padding(
        padding: EdgeInsets.only(bottom: 84),
        child: ExpandableAddMedicationFab(),
      ),
    );
  }

  Widget _buildAdherencePill(String label, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 7-Day Weekly Schedule Selector with Active Day Dot Indicators & Merged Vital Continuity Shield
  Widget _buildWeeklyDaySelector(
    List<DateTime> weekDates,
    DateTime now,
    List<Medication> medications,
  ) {
    final isDark = AppTheme.isDark(context);
    final activeColor = Theme.of(context).colorScheme.primary;
    final streakData = StreakService.computeStreakData(medications);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.cardBorder(context)),
        boxShadow: [
          ...AppTheme.softShadow(context),
          if (streakData.currentStreak > 0)
            ...AppTheme.glowShadow(const Color(0xFF0D9488), opacity: 0.14),
        ],
      ),
      child: Column(
        children: [
          // Top Row: 3-Week Navigator & Merged Vital Continuity Shield Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Previous Week Arrow Button
                    InkWell(
                      onTap: _weekOffset > -1
                          ? () {
                              setState(() {
                                _weekOffset--;
                                _selectedDate = _getCurrentWeekDates().first;
                              });
                            }
                          : null,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 20,
                          color: _weekOffset > -1
                              ? activeColor
                              : AppTheme.textSecondary(context).withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _weekOffset = 0;
                            _selectedDate = now;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            _weekOffset == 0
                                ? 'This Week'
                                : (_weekOffset == -1 ? 'Prev Week' : 'Next Week'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    // Next Week Arrow Button
                    InkWell(
                      onTap: _weekOffset < 1
                          ? () {
                              setState(() {
                                _weekOffset++;
                                _selectedDate = _getCurrentWeekDates().first;
                              });
                            }
                          : null,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: _weekOffset < 1
                              ? activeColor
                              : AppTheme.textSecondary(context).withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    if (!_isSameDay(_selectedDate, now)) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => setState(() {
                          _weekOffset = 0;
                          _selectedDate = now;
                        }),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: activeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Today',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: activeColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Glowing Animated Vital Continuity Shield Chip
              GestureDetector(
                onTap: () => _showStreakMilestonesSheet(context, streakData),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D9488).withValues(alpha: isDark ? 0.45 : 0.35),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_rounded, color: Colors.white, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        streakData.currentStreak > 0
                            ? '${streakData.currentStreak}d Protected'
                            : 'Shield Active',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 9),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppTheme.cardBorder(context).withValues(alpha: 0.7)),
          const SizedBox(height: 10),

          // 7-Day Day Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekDates.map((date) {
              final isSelected = _isSameDay(date, _selectedDate);
              final isTodayDate = _isSameDay(date, now);
              final dayAbbr = DateFormat('E').format(date).substring(0, 3);
              final dayNum = date.day.toString();

              // Check if any medication is active on this day
              final hasMeds = medications.any((m) => m.isActiveOn(date));

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? activeColor
                          : (isTodayDate
                              ? activeColor.withValues(alpha: isDark ? 0.25 : 0.15)
                              : Colors.transparent),
                      borderRadius: BorderRadius.circular(16),
                      border: isTodayDate && !isSelected
                          ? Border.all(color: activeColor, width: 1.5)
                          : null,
                      boxShadow: isSelected
                          ? AppTheme.glowShadow(activeColor, opacity: 0.3)
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          dayAbbr,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dayNum,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Dose Indicator Dot
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasMeds
                                ? (isSelected
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.secondary)
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showStreakMilestonesSheet(BuildContext context, StreakData streakData) {
    final isDark = AppTheme.isDark(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF5722), Color(0xFFFF9800)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text('🔥', style: TextStyle(fontSize: 26)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${streakData.currentStreak} Day Adherence Streak!',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary(ctx),
                              ),
                            ),
                            Text(
                              streakData.currentStreak > 0
                                  ? 'Consistency protects your health. Keep going!'
                                  : 'Take your doses on time today to ignite your streak.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.textSecondary(ctx),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (streakData.nextMilestone != null) ...[
                    Builder(builder: (ctx) {
                      final daysAway = (streakData.nextMilestone!.requiredDays - streakData.currentStreak).clamp(0, 999);
                      return Text(
                        'Next Milestone: ${streakData.nextMilestone!.title} ($daysAway days away)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary(ctx),
                        ),
                      );
                    }),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: streakData.progressToNext,
                        minHeight: 8,
                        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF9800)),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  Text(
                    'Milestone Trophies',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(ctx),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: StreakMilestone.all.map((m) {
                      final isUnlocked = streakData.unlockedMilestones.any((u) => u.id == m.id);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isUnlocked
                              ? const Color(0xFFFFF7ED)
                              : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isUnlocked ? const Color(0xFFFF9800) : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(m.badgeEmoji, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Text(
                              '${m.title} (${m.requiredDays}d)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
                                color: isUnlocked
                                    ? const Color(0xFFC2410C)
                                    : AppTheme.textMuted(ctx),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Back to Today Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Meal Coordination Companion Card
  Widget _buildMealCoordinationBanner(List<DoseItem> mealDoses) {
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFBBF7D0),
        ),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.restaurant_menu,
                size: 20,
                color: isDark ? AppTheme.successGreenLight : AppTheme.successGreen,
              ),
              const SizedBox(width: 8),
              Text(
                'Smart Meal Coordination',
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
            'Your medications are arranged 20 minutes after your meal routine to protect your stomach and ensure seamless absorption without life interruption:',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary(context),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: mealDoses.map((d) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF243048) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.alarm,
                      size: 13,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${d.medication.name} at ${d.time} (post-meal)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DoseTimelineCard extends ConsumerWidget {
  final DoseItem dose;
  final DateTime date;
  final bool isLocked;
  final ValueChanged<DoseStatus> onUpdateStatus;

  const _DoseTimelineCard({
    required this.dose,
    required this.date,
    this.isLocked = false,
    required this.onUpdateStatus,
  });

  void _showStatusPicker(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final med = dose.medication;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF151E2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Record Dose: ${med.name} (${dose.time})',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary(ctx),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Record whether you took this medication on time, delayed, or missed the dosing window:',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(ctx)),
                ),
                const SizedBox(height: 16),
                _buildStatusOption(
                  ctx: ctx,
                  status: DoseStatus.taken,
                  title: 'Taken On Time',
                  subtitle: 'Taken as scheduled within optimal therapeutic window',
                  icon: Icons.check_circle_rounded,
                  color: isDark ? AppTheme.successGreenLight : AppTheme.successGreen,
                ),
                const SizedBox(height: 8),
                _buildStatusOption(
                  ctx: ctx,
                  status: DoseStatus.takenEarly,
                  title: 'Taken Early',
                  subtitle: 'Administered in advance ahead of the scheduled time slot',
                  icon: Icons.alarm_on_rounded,
                  color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488),
                ),
                const SizedBox(height: 8),
                _buildStatusOption(
                  ctx: ctx,
                  status: DoseStatus.delayed,
                  title: 'Taken Delayed / Late',
                  subtitle: 'Taken late after the scheduled time',
                  icon: Icons.schedule_rounded,
                  color: isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber,
                ),
                const SizedBox(height: 8),
                _buildStatusOption(
                  ctx: ctx,
                  status: DoseStatus.missed,
                  title: 'Missed Window',
                  subtitle: 'Window expired or unable to take dose safely',
                  icon: Icons.cancel_rounded,
                  color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                ),
                if (med.scheduleFrequency == ScheduleFrequency.asNeeded) ...[
                  const SizedBox(height: 8),
                  _buildStatusOption(
                    ctx: ctx,
                    status: DoseStatus.notNeeded,
                    title: 'Not Needed (As Needed / PRN)',
                    subtitle: 'Symptoms absent or medication was not required today',
                    icon: Icons.remove_circle_outline_rounded,
                    color: isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade700,
                  ),
                ],
                const SizedBox(height: 8),
                _buildStatusOption(
                  ctx: ctx,
                  status: DoseStatus.pending,
                  title: 'Reset to Pending',
                  subtitle: 'Clear intake log for this time slot',
                  icon: Icons.restore_rounded,
                  color: AppTheme.textMuted(ctx),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLockedToast(BuildContext context, bool isFuture) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isFuture
                    ? 'Future dates are locked. Doses can only be logged on today\'s schedule.'
                    : 'Past records are locked. Historical records are view-only.',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.textPrimary(context),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildStatusOption({
    required BuildContext ctx,
    required DoseStatus status,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = dose.status == status;

    return InkWell(
      onTap: () {
        if (status == DoseStatus.missed) {
          Navigator.pop(ctx);
          showMissedDoseGuidanceSheet(
            ctx,
            medication: dose.medication,
            scheduledTime: dose.time,
            onSelectStatus: onUpdateStatus,
          );
        } else {
          onUpdateStatus(status);
          Navigator.pop(ctx);
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : AppTheme.surfaceVariant(ctx),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : AppTheme.cardBorder(ctx),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.textPrimary(ctx),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary(ctx),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final med = dose.medication;
    final isDark = AppTheme.isDark(context);
    final status = dose.status;
    final profile = ref.watch(profileNotifierProvider);
    final allergyFlags = SchedulerService.getAllergyConflictsForMedication(
      medication: med,
      profile: profile,
    );
    final hasAllergyConflict = allergyFlags.isNotEmpty;

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final cardMidnight = DateTime(date.year, date.month, date.day);
    final isFuture = cardMidnight.isAfter(todayMidnight);

    // Food restrictions (from med or template)
    final foodWarnings = med.foodRestrictions.isNotEmpty
        ? med.foodRestrictions
        : (MedicinesDatabase.findByName(med.name)?.foodRestrictions ?? const []);

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case DoseStatus.taken:
        statusColor = isDark ? AppTheme.successGreenLight : AppTheme.successGreen;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Taken';
        break;
      case DoseStatus.takenEarly:
        statusColor = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488);
        statusIcon = Icons.alarm_on_rounded;
        statusLabel = 'Taken Early';
        break;
      case DoseStatus.delayed:
        statusColor = isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber;
        statusIcon = Icons.schedule_rounded;
        statusLabel = 'Delayed';
        break;
      case DoseStatus.missed:
        statusColor = isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed;
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Missed';
        break;
      case DoseStatus.notNeeded:
        statusColor = isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade700;
        statusIcon = Icons.remove_circle_outline_rounded;
        statusLabel = 'Not Needed';
        break;
      case DoseStatus.pending:
        statusColor = AppTheme.textMuted(context);
        statusIcon = Icons.radio_button_unchecked_rounded;
        statusLabel = 'Pending';
        break;
    }

    final isResolved = status == DoseStatus.taken ||
        status == DoseStatus.takenEarly ||
        status == DoseStatus.delayed ||
        status == DoseStatus.notNeeded;

    return Dismissible(
      key: Key('dose_${med.id}_${dose.time}_${date.toIso8601String()}'),
      direction: isLocked ? DismissDirection.none : DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe Right: Mark Taken
          onUpdateStatus(DoseStatus.taken);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ ${med.name} marked as Taken!'),
              duration: const Duration(seconds: 2),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        } else {
          // Swipe Left: Show status options (Missed / Delayed)
          _showStatusPicker(context);
        }
        return false; // Do not dismiss from tree
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: isDark ? AppTheme.successGreenLight : AppTheme.successGreen,
              size: 26,
            ),
            const SizedBox(width: 8),
            Text(
              'Mark Taken',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? AppTheme.successGreenLight : AppTheme.successGreen,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delayed / Missed',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? AppTheme.warningAmberLight : const Color(0xFFB45309),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.schedule_rounded,
              color: isDark ? AppTheme.warningAmberLight : const Color(0xFFB45309),
              size: 26,
            ),
          ],
        ),
      ),
      child: Opacity(
        opacity: isLocked ? 0.62 : 1.0,
        child: InkWell(
          onTap: isLocked
              ? () => _showLockedToast(context, isFuture)
              : () => _showStatusPicker(context),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isResolved
                  ? (isDark ? const Color(0xFF141D2B) : const Color(0xFFF1F5F9))
                  : (status == DoseStatus.missed
                      ? (isDark ? const Color(0xFF261014) : const Color(0xFFFFF1F2))
                      : AppTheme.cardColor(context)),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: hasAllergyConflict
                    ? (isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed)
                    : (status == DoseStatus.missed
                        ? (isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed)
                        : AppTheme.cardBorder(context)),
                width: hasAllergyConflict ? 1.6 : 1,
              ),
              boxShadow: isResolved
                  ? null
                  : (hasAllergyConflict
                      ? AppTheme.glowShadow(AppTheme.dangerRed, opacity: 0.16)
                      : AppTheme.softShadow(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Time & Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: status == DoseStatus.taken
                          ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                          : (status == DoseStatus.delayed
                              ? (isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7))
                              : (status == DoseStatus.missed
                                  ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2))
                                  : Theme.of(context).colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.12))),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dose.time,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Med Info & Condition Badges
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                med.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  decoration: isResolved ? TextDecoration.lineThrough : null,
                                  color: isResolved
                                      ? AppTheme.textMuted(context)
                                      : AppTheme.textPrimary(context),
                                ),
                              ),
                            ),
                            if (isLocked)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceVariant(context),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.cardBorder(context)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock_rounded, size: 10, color: AppTheme.textMuted(context)),
                                    const SizedBox(width: 3),
                                    Text(
                                      isFuture ? 'Locked • Scheduled' : 'Locked • History',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textMuted(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${med.dosage} • ${med.form.name}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),

                        // Prominent Red Flag Allergy Warning
                        if (hasAllergyConflict) ...[
                          Container(
                            margin: const EdgeInsets.only(top: 6, bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.flag_rounded, size: 12, color: AppTheme.dangerRed),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'RED FLAG: ALLERGY TRIGGER (${allergyFlags.first.relatedAllergy ?? "Trigger"})',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),

                        // Food Restriction Warnings (if any)
                        if (foodWarnings.isNotEmpty) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF3B1D0B) : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.restaurant_menu_rounded,
                                  size: 12,
                                  color: isDark ? AppTheme.warningAmberLight : const Color(0xFFB45309),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    foodWarnings.first,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppTheme.warningAmberLight : const Color(0xFF92400E),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Pre/Post Condition tags
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final c in med.preConditions)
                              _buildTag(
                                context: context,
                                icon: _conditionIcon(c.type),
                                label: 'Before: ${c.description}',
                                isTaken: isResolved,
                              ),
                            for (final c in med.postConditions)
                              _buildTag(
                                context: context,
                                icon: _conditionIcon(c.type),
                                label: 'After: ${c.description}',
                                isTaken: isResolved,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Clinical Information & Cautions Button
                  IconButton(
                    tooltip: 'Clinical Information & Cautions',
                    icon: Icon(
                      Icons.info_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    onPressed: () => showMedicationClinicalGuide(
                      context,
                      medicationName: med.name,
                      medication: med,
                    ),
                  ),

                  // Interactive Status Button
                  IconButton(
                    tooltip: isLocked ? 'Locked for this date' : 'Tap to change intake status',
                    icon: Icon(
                      isLocked ? Icons.lock_outline_rounded : statusIcon,
                      color: isLocked ? AppTheme.textMuted(context) : statusColor,
                      size: isLocked ? 22 : 28,
                    ),
                    onPressed: isLocked
                        ? () => _showLockedToast(context, isFuture)
                        : () => _showStatusPicker(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isTaken,
  }) {
    final isDark = AppTheme.isDark(context);
    final tagBg = isTaken
        ? (isDark ? const Color(0xFF1E293B) : Colors.grey.shade200)
        : (isDark ? const Color(0xFF0C4A6E) : const Color(0xFFE0F2FE));
    final tagColor = isTaken
        ? AppTheme.textMuted(context)
        : (isDark ? AppTheme.secondaryCyanLight : AppTheme.secondaryCyan);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: tagBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: tagColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: tagColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  IconData _conditionIcon(ConditionType type) {
    switch (type) {
      case ConditionType.meal:
        return Icons.restaurant_rounded;
      case ConditionType.emptyStomach:
        return Icons.no_food_rounded;
      case ConditionType.sleep:
        return Icons.bedtime_rounded;
      case ConditionType.drinkWater:
        return Icons.water_drop_rounded;
      case ConditionType.rest:
        return Icons.weekend_rounded;
      case ConditionType.avoidDriving:
        return Icons.no_crash_rounded;
      case ConditionType.custom:
        return Icons.info_rounded;
    }
  }
}
