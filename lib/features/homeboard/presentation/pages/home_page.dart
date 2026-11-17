import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medisync/core/data/medicines_database.dart';
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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  // Calculate current week's dates (Monday to Sunday)
  List<DateTime> _getCurrentWeekDates() {
    final now = DateTime.now();
    final currentWeekday = now.weekday; // 1 = Monday, 7 = Sunday
    final monday = now.subtract(Duration(days: currentWeekday - 1));

    return List.generate(7, (index) {
      final day = monday.add(Duration(days: index));
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
    final takenCount = selectedDayDoses.where((d) => d.isTaken).length;
    final progress = totalDoses == 0 ? 0.0 : (takenCount / totalDoses);

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

    // Human-readable date string avoiding intl specifier issues
    final formattedHeaderDate = DateFormat('EEEE, MMMM d').format(_selectedDate);
    final formattedScheduleTitle =
        isToday ? "Today's Schedule" : "${DateFormat('EEEE, MMM d').format(_selectedDate)} Schedule";
    final weekDates = _getCurrentWeekDates();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            boxShadow: AppTheme.softShadow(context),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        formattedHeaderDate,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary(context),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hello, ${profile.name.split(' ').first}',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Add Medication',
                    icon: Icon(
                      Icons.add_circle,
                      color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                      size: 30,
                    ),
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

          // 4. Daily Adherence Progress Card (Layered Gradient & Glow)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0F766E), const Color(0xFF134E4A)]
                    : [const Color(0xFF0D9488), const Color(0xFF115E59)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: AppTheme.glowShadow(
                isDark ? const Color(0xFF14B8A6) : const Color(0xFF0D9488),
                opacity: 0.22,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formattedScheduleTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$takenCount / $totalDoses Taken',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5EEAD4)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  totalDoses == 0
                      ? 'No medications scheduled for this day.'
                      : progress == 1.0
                          ? 'Outstanding! All scheduled doses taken.'
                          : '${totalDoses - takenCount} dose(s) remaining for this day.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.94),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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
              Text(
                'Dose Timeline',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                ),
              ),
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
    );
  }

  // 7-Day Weekly Schedule Selector with Active Day Dot Indicators
  Widget _buildWeeklyDaySelector(
    List<DateTime> weekDates,
    DateTime now,
    List<Medication> medications,
  ) {
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder(context)),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: weekDates.map((date) {
          final isSelected = _isSameDay(date, _selectedDate);
          final isTodayDate = _isSameDay(date, now);
          final dayAbbr = DateFormat('E').format(date).substring(0, 3);
          final dayNum = date.day.toString();

          // Check if any medication is active on this day
          final hasMeds = medications.any((m) => m.isActiveOn(date));
          final activeColor = isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = date;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor
                    : (isTodayDate
                        ? (isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1))
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
                          ? (isDark ? const Color(0xFF042F2E) : Colors.white)
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
                          ? (isDark ? const Color(0xFF042F2E) : Colors.white)
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
                              ? (isDark ? const Color(0xFF042F2E) : Colors.white)
                              : (isDark ? AppTheme.secondaryCyanLight : AppTheme.secondaryCyan))
                          : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
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
                      color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
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

class _DoseTimelineCard extends StatelessWidget {
  final DoseItem dose;
  final DateTime date;
  final ValueChanged<DoseStatus> onUpdateStatus;

  const _DoseTimelineCard({
    required this.dose,
    required this.date,
    required this.onUpdateStatus,
  });

  void _showStatusPicker(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final med = dose.medication;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF151E2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
        onUpdateStatus(status);
        Navigator.pop(ctx);
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
  Widget build(BuildContext context) {
    final med = dose.medication;
    final isDark = AppTheme.isDark(context);
    final status = dose.status;

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
      case DoseStatus.pending:
        statusColor = AppTheme.textMuted(context);
        statusIcon = Icons.radio_button_unchecked_rounded;
        statusLabel = 'Pending';
        break;
    }

    final isResolved = status == DoseStatus.taken || status == DoseStatus.delayed;

    return Dismissible(
      key: Key('dose_${med.id}_${dose.time}_${date.toIso8601String()}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe Right: Mark Taken
          onUpdateStatus(DoseStatus.taken);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ ${med.name} marked as Taken!'),
              duration: const Duration(seconds: 2),
              backgroundColor: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
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
      child: InkWell(
        onTap: () => _showStatusPicker(context),
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
              color: status == DoseStatus.missed
                  ? (isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed)
                  : AppTheme.cardBorder(context),
            ),
            boxShadow: isResolved ? null : AppTheme.softShadow(context),
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
                                : (isDark
                                    ? AppTheme.primaryTealLight.withValues(alpha: 0.18)
                                    : const Color(0xFFCCFBF1)))),
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
                      Text(
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
                      const SizedBox(height: 2),
                      Text(
                        '${med.dosage} • ${med.form.name}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
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

                // Interactive Status Button
                IconButton(
                  tooltip: 'Tap to change intake status',
                  icon: Icon(
                    statusIcon,
                    color: statusColor,
                    size: 28,
                  ),
                  onPressed: () => _showStatusPicker(context),
                ),
              ],
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
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: tagColor,
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
