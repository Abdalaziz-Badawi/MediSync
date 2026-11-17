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
            isTaken: med.isDoseTaken(_selectedDate, time),
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

    final formattedHeaderDate = DateFormat('EEEE, MMMM d').format(_selectedDate);
    final weekDates = _getCurrentWeekDates();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formattedHeaderDate,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Hello, ${profile.name.split(' ').first}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary(context),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Add Medication',
            icon: Icon(
              Icons.add_circle,
              color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
              size: 28,
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
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Weekly Schedule Day Selector
          _buildWeeklyDaySelector(weekDates, now),
          const SizedBox(height: 16),

          // Allergy Alert Banner (if any)
          if (criticalFlags.isNotEmpty) ...[
            Card(
              color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                  width: 1.5,
                ),
              ),
              child: Padding(
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
            ),
            const SizedBox(height: 16),
          ],

          // Next Dose Countdown Widget (shown on current day)
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

          // Daily Progress Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0F766E), const Color(0xFF134E4A)]
                      : [const Color(0xFF0D9488), const Color(0xFF115E59)],
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
                      Text(
                        isToday ? "Today's Schedule" : DateFormat('EEEE Schedule').format(_selectedDate),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
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
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Companion Meal Coordination Banner (if applicable)
          if (mealLinkedDoses.isNotEmpty) ...[
            _buildMealCoordinationBanner(mealLinkedDoses, profile),
            const SizedBox(height: 20),
          ],

          // Timeline Header
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
              Text(
                'Sync: ${profile.useHealthApp ? 'Samsung Health' : 'Smart Local'}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dose Timeline Items
          if (selectedDayDoses.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 60,
                      color: AppTheme.textMuted(context),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No medication doses due on this day',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary(context),
                      ),
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
            for (final dose in selectedDayDoses)
              _DoseTimelineCard(
                dose: dose,
                date: _selectedDate,
                onToggle: () {
                  ref
                      .read(medicationsNotifierProvider.notifier)
                      .toggleDoseTaken(
                        dose.medication.id,
                        _selectedDate,
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

  // 7-Day Weekly Schedule Selector
  Widget _buildWeeklyDaySelector(List<DateTime> weekDates, DateTime now) {
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder(context)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: weekDates.map((date) {
          final isSelected = _isSameDay(date, _selectedDate);
          final isTodayDate = _isSameDay(date, now);
          final dayAbbr = DateFormat('E').format(date).substring(0, 3);
          final dayNum = date.day.toString();

          final activeColor = isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = date;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor
                    : (isTodayDate
                        ? (isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1))
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(14),
                border: isTodayDate && !isSelected
                    ? Border.all(color: activeColor, width: 1.5)
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
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? (isDark ? const Color(0xFF042F2E) : Colors.white)
                          : AppTheme.textPrimary(context),
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
  Widget _buildMealCoordinationBanner(List<DoseItem> mealDoses, dynamic profile) {
    final isDark = AppTheme.isDark(context);

    return Card(
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
    final isDark = AppTheme.isDark(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isTaken ? 0.5 : (isDark ? 2 : 1),
      color: isTaken
          ? (isDark ? const Color(0xFF141D2B) : const Color(0xFFF1F5F9))
          : AppTheme.cardColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.cardBorder(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Time Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isTaken
                    ? (isDark ? const Color(0xFF1E293B) : Colors.grey.shade300)
                    : (isDark
                        ? AppTheme.primaryTealLight.withValues(alpha: 0.18)
                        : const Color(0xFFCCFBF1)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                dose.time,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isTaken
                      ? AppTheme.textSecondary(context)
                      : (isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal),
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
                      decoration: isTaken ? TextDecoration.lineThrough : null,
                      color: isTaken
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

                  // Condition tags (e.g. After food, Before sleep)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final c in med.preConditions)
                        _buildTag(
                          context: context,
                          icon: _conditionIcon(c.type),
                          label: 'Before: ${c.description}',
                          isTaken: isTaken,
                        ),
                      for (final c in med.postConditions)
                        _buildTag(
                          context: context,
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
                isTaken ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isTaken
                    ? (isDark ? AppTheme.successGreenLight : AppTheme.successGreen)
                    : AppTheme.textMuted(context),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: tagBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: tagColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
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
