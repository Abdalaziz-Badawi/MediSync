import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medisync/core/data/medicines_database.dart';
import 'package:medisync/core/models/condition.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/models/safety_flag.dart';
import 'package:medisync/core/models/user_profile.dart';
import 'package:medisync/core/services/device_integration_service.dart';
import 'package:medisync/core/services/notification_service.dart';
import 'package:medisync/core/services/scheduler_service.dart';
import 'package:medisync/core/services/storage_service.dart';
import 'package:medisync/core/services/streak_service.dart';
import 'package:medisync/core/theme/app_theme.dart';
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

class RoutineSlotGroup {
  final String key;
  final String title;
  final IconData icon;
  final List<DoseItem> doses;
  final List<ClinicalSlotConflict> conflicts;

  const RoutineSlotGroup({
    required this.key,
    required this.title,
    required this.icon,
    required this.doses,
    required this.conflicts,
  });

  int get pendingCount => doses.where((d) => d.status == DoseStatus.pending).length;
  bool get allTaken => doses.isNotEmpty && doses.every((d) => d.status == DoseStatus.taken || d.status == DoseStatus.takenEarly);
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late DateTime _selectedDate;
  int _weekOffset = 0; // -1 = Previous week, 0 = Current week, 1 = Next week
  Timer? _countdownTimer;
  StreamSubscription<NotificationResponse>? _notifSubscription;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkLockscreenLaunch();
      _checkNotificationLaunch();
      _syncEmergencyCard();
    });

    ref.read(deviceIntegrationServiceProvider).onEmergencyCardRequested = () {
      if (mounted) {
        final profile = ref.read(profileNotifierProvider);
        final meds = ref.read(medicationsNotifierProvider);
        showEmergencyCardDialog(context, profile: profile, medications: meds);
      }
    };

    // Listen to actionable direct notification button taps ([✓ Taken], [⏰ Snooze], [⚠️ Skip])
    try {
      _notifSubscription = ref.read(notificationServiceProvider).onNotificationResponse.listen((response) {
        if (mounted) _handleNotificationResponse(response);
      });
    } catch (_) {}

    // Update countdown every 30 seconds
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _notifSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkNotificationLaunch() async {
    if (!mounted) return;
    try {
      final notif = ref.read(notificationServiceProvider);
      final launchDetails = await notif.getNotificationAppLaunchDetails();
      if (!mounted) return;
      if (launchDetails != null && launchDetails.didNotificationLaunchApp && launchDetails.notificationResponse != null) {
        _handleNotificationResponse(launchDetails.notificationResponse!);
      }
    } catch (_) {}
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payloadStr = response.payload;
    if (payloadStr == null || payloadStr.isEmpty) return;

    if (payloadStr == 'emergency_card') {
      final profile = ref.read(profileNotifierProvider);
      final meds = ref.read(medicationsNotifierProvider);
      showEmergencyCardDialog(context, profile: profile, medications: meds);
      return;
    }

    try {
      final data = jsonDecode(payloadStr) as Map<String, dynamic>;
      final actionId = response.actionId;
      final medId = data['medId'] as String?;
      final time = data['time'] as String?;
      final medName = (data['medName'] as String?) ?? 'Medication';
      final dosage = (data['dosage'] as String?) ?? '';
      final necessity = (data['necessity'] as String?) ?? 'medium';

      if (medId == null || time == null) return;

      if (actionId == 'action_taken' || actionId == 'action_take_early') {
        final status = actionId == 'action_take_early' ? DoseStatus.takenEarly : DoseStatus.taken;
        ref.read(medicationsNotifierProvider.notifier).setDoseStatus(medId, DateTime.now(), time, status);
        _syncEmergencyCard();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Marked $medName ($dosage) as Taken!'),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (actionId == 'action_snooze') {
        ref.read(notificationServiceProvider).scheduleSnoozeNotification(
          medId: medId,
          medName: medName,
          dosage: dosage,
          time: time,
          minutes: 15,
          necessity: necessity,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⏰ Snoozed $medName reminder for 15 minutes.'),
            backgroundColor: const Color(0xFFD97706),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (actionId == 'action_skip') {
        if (necessity == 'critical' || necessity == 'vital') {
          _showSkipWarningDialog(medName, dosage, medId, time);
        } else {
          ref.read(medicationsNotifierProvider.notifier).setDoseStatus(medId, DateTime.now(), time, DoseStatus.notNeeded);
          _syncEmergencyCard();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Skipped $medName ($dosage) dose.'),
              backgroundColor: const Color(0xFF64748B),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error handling actionable notification response: $e');
    }
  }

  Future<void> _showSkipWarningDialog(String medName, String dosage, String medId, String time) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Clinical Safety Warning',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
              ),
              child: Text(
                '⚠️ $medName ($dosage) is clinically classified as High Necessity / Vital. Skipping doses can cause serious therapeutic regression or adverse complications.',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFFDC2626)),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Always consult your physician or pharmacist before intentionally omitting a dose.\n\nDo you still wish to record this dose as skipped?',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, false);
              ref.read(medicationsNotifierProvider.notifier).setDoseStatus(medId, DateTime.now(), time, DoseStatus.taken);
              _syncEmergencyCard();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✓ Wise decision! Marked $medName as Taken.'),
                  backgroundColor: const Color(0xFF059669),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            child: const Text('Take Dose Now', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF64748B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Skip'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(medicationsNotifierProvider.notifier).setDoseStatus(medId, DateTime.now(), time, DoseStatus.notNeeded);
      _syncEmergencyCard();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Skipped $medName ($dosage) dose.'),
          backgroundColor: const Color(0xFF64748B),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _checkLockscreenLaunch() async {
    if (!mounted) return;
    try {
      final action = await ref.read(deviceIntegrationServiceProvider).getInitialLockscreenAction();
      if (!mounted) return;
      if (action != null) {
        final profile = ref.read(profileNotifierProvider);
        final meds = ref.read(medicationsNotifierProvider);
        showEmergencyCardDialog(context, profile: profile, medications: meds);
      }
    } catch (_) {}
  }

  Future<void> _syncEmergencyCard() async {
    if (!mounted) return;
    try {
      final profile = ref.read(profileNotifierProvider);
      final meds = ref.read(medicationsNotifierProvider).where((m) => !m.isDiscontinued).toList();
      await ref.read(deviceIntegrationServiceProvider).syncEmergencyData(
        profile: profile,
        medications: meds,
      );
    } catch (_) {}
  }

  List<RoutineSlotGroup> _groupDosesBySlot(List<DoseItem> doses) {
    final morning = <DoseItem>[];
    final lunch = <DoseItem>[];
    final evening = <DoseItem>[];
    final bedtime = <DoseItem>[];

    for (final dose in doses) {
      final parts = dose.time.split(':');
      final hr = int.tryParse(parts[0]) ?? 8;
      final min = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      final totalMins = hr * 60 + min;

      if (totalMins >= 300 && totalMins <= 690) {
        morning.add(dose);
      } else if (totalMins > 690 && totalMins <= 990) {
        lunch.add(dose);
      } else if (totalMins > 990 && totalMins <= 1260) {
        evening.add(dose);
      } else {
        bedtime.add(dose);
      }
    }

    final groups = <RoutineSlotGroup>[];

    if (morning.isNotEmpty) {
      final meds = morning.map((d) => d.medication).toSet().toList();
      groups.add(RoutineSlotGroup(
        key: 'morning',
        title: 'Morning Routine (Wake & Breakfast)',
        icon: Icons.wb_sunny_rounded,
        doses: morning,
        conflicts: SchedulerService.checkSlotConflicts(meds),
      ));
    }

    if (lunch.isNotEmpty) {
      final meds = lunch.map((d) => d.medication).toSet().toList();
      groups.add(RoutineSlotGroup(
        key: 'lunch',
        title: 'Midday Routine (Lunch)',
        icon: Icons.restaurant_rounded,
        doses: lunch,
        conflicts: SchedulerService.checkSlotConflicts(meds),
      ));
    }

    if (evening.isNotEmpty) {
      final meds = evening.map((d) => d.medication).toSet().toList();
      groups.add(RoutineSlotGroup(
        key: 'evening',
        title: 'Evening Routine (Dinner)',
        icon: Icons.dinner_dining_rounded,
        doses: evening,
        conflicts: SchedulerService.checkSlotConflicts(meds),
      ));
    }

    if (bedtime.isNotEmpty) {
      final meds = bedtime.map((d) => d.medication).toSet().toList();
      groups.add(RoutineSlotGroup(
        key: 'bedtime',
        title: 'Night & Bedtime Routine',
        icon: Icons.bedtime_rounded,
        doses: bedtime,
        conflicts: SchedulerService.checkSlotConflicts(meds),
      ));
    }

    return groups;
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
    ref.listen<UserProfile>(profileNotifierProvider, (previous, next) {
      _syncEmergencyCard();
    });
    ref.listen<List<Medication>>(medicationsNotifierProvider, (previous, next) {
      _syncEmergencyCard();
    });

    final medications = ref.watch(medicationsNotifierProvider);
    final profile = ref.watch(profileNotifierProvider);
    final now = DateTime.now();
    final isToday = _isSameDay(_selectedDate, now);
    final isDark = AppTheme.isDark(context);

    // Collect all doses for the selected day of the week
    final selectedDayDoses = <DoseItem>[];
    for (final med in medications) {
      if (!med.isDiscontinued && med.isActiveOn(_selectedDate)) {
        if (med.scheduleFrequency != ScheduleFrequency.asNeeded) {
          for (final time in med.scheduledTimes) {
            selectedDayDoses.add(DoseItem(
              medication: med,
              time: time,
              status: med.getDoseStatus(_selectedDate, time),
            ));
          }
        }
      } else if (med.isDiscontinued) {
        // Discontinued medication: NEVER show pending or delayed doses on the schedule.
        // Only show historical doses that were ACTUALLY taken before discontinuation.
        for (final time in med.scheduledTimes) {
          final status = med.getDoseStatus(_selectedDate, time);
          if (status == DoseStatus.taken || status == DoseStatus.takenEarly) {
            selectedDayDoses.add(DoseItem(
              medication: med,
              time: time,
              status: status,
            ));
          }
        }
      }
    }

    // Sort chronologically by time
    selectedDayDoses.sort((a, b) => a.time.compareTo(b.time));

    final prnMeds = medications.where((m) => m.scheduleFrequency == ScheduleFrequency.asNeeded && !m.isDiscontinued).toList();
    final todayKey = "${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
    final unloggedPrnMeds = prnMeds.where((m) {
      final logs = m.doseLog[todayKey] ?? [];
      return logs.isEmpty;
    }).toList();

    int prnTakenCount = 0;
    int prnNotNeededCount = 0;
    for (final med in prnMeds) {
      final logs = med.doseLog[todayKey] ?? [];
      prnTakenCount += logs.where((e) => !e.endsWith(':missed') && !e.endsWith(':notNeeded') && !e.endsWith(':not_needed')).length;
      if (logs.any((e) => e.endsWith(':notNeeded') || e.endsWith(':not_needed'))) {
        prnNotNeededCount++;
      }
    }

    final totalDoses = selectedDayDoses.length + prnMeds.length;
    final takenCount = selectedDayDoses.where((d) => d.status == DoseStatus.taken || d.status == DoseStatus.takenEarly).length + prnTakenCount;
    final delayedCount = selectedDayDoses.where((d) => d.status == DoseStatus.delayed).length;
    final missedCount = selectedDayDoses.where((d) => d.status == DoseStatus.missed).length;
    final notNeededCount = selectedDayDoses.where((d) => d.status == DoseStatus.notNeeded).length + prnNotNeededCount;
    final pendingCount = selectedDayDoses.where((d) => d.status == DoseStatus.pending).length + unloggedPrnMeds.length;
    final progress = totalDoses == 0 ? 0.0 : ((takenCount + delayedCount + notNeededCount) / totalDoses).clamp(0.0, 1.0);
    final nextPendingDose = selectedDayDoses.where((d) => !d.medication.isDiscontinued && d.status == DoseStatus.pending).firstOrNull;

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

          // 3. Unified Hero: Today's Schedule & Next Dose
          _buildUnifiedTodayScheduleHero(
            context: context,
            isDark: isDark,
            isToday: isToday,
            formattedScheduleTitle: formattedScheduleTitle,
            progress: progress,
            takenCount: takenCount,
            pendingCount: pendingCount,
            delayedCount: delayedCount,
            missedCount: missedCount,
            notNeededCount: notNeededCount,
            totalDoses: totalDoses,
            nextPendingDose: nextPendingDose,
            profile: profile,
          ),
          const SizedBox(height: 20),

          // 4. End-of-Day As-Needed (PRN) Check Banner (Triggered in evening/night for unlogged PRNs)
          if (isToday && unloggedPrnMeds.isNotEmpty && (now.hour >= 17 || now.hour < 4)) ...[
            _buildEndOfDayPrnCheckBanner(context, unloggedPrnMeds),
            const SizedBox(height: 20),
          ],

          // 5. Smart Companion Meal Coordination Banner
          if (mealLinkedDoses.isNotEmpty) ...[
            _buildMealCoordinationBanner(mealLinkedDoses),
            const SizedBox(height: 20),
          ],

          // 6. As-Needed (PRN) Medications Section
          if (prnMeds.isNotEmpty) ...[
            _buildPrnMedicationsSection(context, prnMeds, isToday, _selectedDate),
            const SizedBox(height: 20),
          ],

          // 7. Scheduled Routine Timeline Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Scheduled Routine Timeline',
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
            Builder(
              builder: (ctx) {
                final slotGroups = _groupDosesBySlot(selectedDayDoses);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final group in slotGroups) ...[
                      _RoutineSlotHeader(
                        group: group,
                        isToday: isToday,
                        onTakeAll: () {
                          for (final dose in group.doses) {
                            if (dose.status == DoseStatus.pending) {
                              ref
                                  .read(medicationsNotifierProvider.notifier)
                                  .setDoseStatus(
                                    dose.medication.id,
                                    _selectedDate,
                                    dose.time,
                                    DoseStatus.taken,
                                  );
                            }
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✓ Marked all ${group.title} doses as Taken!'),
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        onAutoSpaceConflict: (conflict) {
                          final medToShift = conflict.medicationB;
                          final currentTimes = List<String>.from(medToShift.scheduledTimes);
                          final conflictingDose = group.doses.firstWhere(
                            (d) => d.medication.id == medToShift.id,
                            orElse: () => group.doses.first,
                          );
                          final idx = currentTimes.indexOf(conflictingDose.time);
                          if (idx != -1) {
                            final newTime = SchedulerService.autoSpaceTime(
                              conflictingDose.time,
                              conflict.requiredSpacingHours,
                            );
                            currentTimes[idx] = newTime;
                            final updatedMed = medToShift.copyWith(scheduledTimes: currentTimes);
                            ref.read(medicationsNotifierProvider.notifier).addOrUpdate(updatedMed);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('⚡ Auto-spaced ${medToShift.name} to $newTime (+${conflict.requiredSpacingHours}h separation)'),
                                backgroundColor: const Color(0xFFD97706),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                      ),
                      for (final dose in group.doses)
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
                          onEvaluateIntake: (status) {
                            _evaluateDoseIntakeTiming(
                              context: context,
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
                            );
                          },
                        ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ],
          // Generous bottom buffer ensuring content is completely clear of elevated FAB and floating nav bar
          const SizedBox(height: 140),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: const SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: 96, right: 8),
          child: ExpandableAddMedicationFab(),
        ),
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

  DateTime _parseDoseDateTime(DateTime date, String hhmm) {
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
      return 'In ${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      return minutes > 0 ? 'In ${hours}h ${minutes}m' : 'In ${hours}h';
    } else {
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      return 'In ${days}d ${hours}h';
    }
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

  /// Evaluates clinical dosing timing when marking a dose:
  /// - Too early (>45m ahead): reminds user of premature peak plasma levels / overlap risk.
  /// - Conflict window with next dose: warns against dangerous double-dosing / dose stacking.
  /// - Delayed (>45m late): confirms whether taken delayed now or taken earlier on time.
  void _evaluateDoseIntakeTiming({
    required BuildContext context,
    required DoseItem dose,
    required DateTime date,
    required ValueChanged<DoseStatus> onUpdateStatus,
  }) {
    final now = DateTime.now();
    final isToday = _isSameDay(date, now);

    if (!isToday) {
      _showLockedToast(context, date.isAfter(now));
      return;
    }

    final doseDateTime = _parseDoseDateTime(date, dose.time);
    final diffMinutes = now.difference(doseDateTime).inMinutes;

    // 1. Too Early Check (More than 45 minutes early)
    if (diffMinutes < -45) {
      final earlyDuration = doseDateTime.difference(now);
      final h = earlyDuration.inHours;
      final m = earlyDuration.inMinutes % 60;
      final earlyStr = h > 0
          ? '$h hour${h > 1 ? "s" : ""}${m > 0 ? " $m min" : ""}'
          : '$m minutes';

      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: AppTheme.cardColor(ctx),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.alarm_on_rounded, color: Theme.of(ctx).colorScheme.primary, size: 24),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Early Dose Reminder',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'It is currently $earlyStr earlier than scheduled (scheduled at ${dose.time}).',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: AppTheme.textPrimary(ctx),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Taking doses significantly ahead of schedule may cause premature drug concentration spikes and shorten the safe separation interval from your previous dose.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary(ctx),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Do you still want to take this medication now, or wait until its scheduled time?',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(ctx),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Wait Until Time'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  onUpdateStatus(DoseStatus.takenEarly);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✓ ${dose.medication.name} recorded as Taken Early!'),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text('Take Early Now'),
              ),
            ],
          );
        },
      );
      return;
    }

    // 2. Delayed Check (> 45 minutes late)
    if (diffMinutes > 45) {
      // Check for conflict with next dose of this medication
      final allTimes = List<String>.from(dose.medication.scheduledTimes)..sort();
      final idx = allTimes.indexOf(dose.time);
      String? nextDoseTime;
      if (idx != -1 && idx + 1 < allTimes.length) {
        nextDoseTime = allTimes[idx + 1];
      }

      int minutesToNext = 9999;
      if (nextDoseTime != null) {
        final nextDoseDt = _parseDoseDateTime(date, nextDoseTime);
        minutesToNext = nextDoseDt.difference(now).inMinutes;
      }

      // If conflicting window with next dose (< 3 hours / 180 minutes to next dose)
      if (nextDoseTime != null && minutesToNext <= 180 && minutesToNext > 0) {
        final remainingHoursStr = (minutesToNext / 60).toStringAsFixed(1);
        showDialog(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              backgroundColor: AppTheme.cardColor(ctx),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.dangerous_rounded, color: Color(0xFFDC2626), size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Dose Conflict Warning',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEF4444)),
                    ),
                    child: Text(
                      'Warning: Taking this dose now is dangerously close to your next scheduled dose at $nextDoseTime (only $remainingHoursStr hours away).',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF991B1B),
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Clinical safety guidelines advise against double-dosing or taking doses in close proximity to prevent toxicity and dose stacking.\n\nDid you take this earlier near ${dose.time} and are just recording it now, or did you miss the intake window?',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary(ctx),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              actions: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    onUpdateStatus(DoseStatus.taken);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✓ Recorded ${dose.medication.name} as Taken Earlier near ${dose.time}'),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Text('Took Earlier Near ${dose.time}'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    onUpdateStatus(DoseStatus.missed);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Recorded as Missed Window (Avoided double-dose risk)'),
                        backgroundColor: Color(0xFFDC2626),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text('Missed Window (Skip)'),
                ),
              ],
            );
          },
        );
        return;
      }

      // Normal Delayed check (> 45 mins late, but safe spacing from next dose)
      final delayedHours = (diffMinutes / 60).floor();
      final delayedMins = diffMinutes % 60;
      final delayedStr = delayedHours > 0
          ? '$delayedHours hour${delayedHours > 1 ? "s" : ""}${delayedMins > 0 ? " $delayedMins min" : ""}'
          : '$delayedMins minutes';

      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: AppTheme.cardColor(ctx),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.schedule_rounded, color: Color(0xFFD97706), size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Delayed Dose Confirmation',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scheduled for ${dose.time} ($delayedStr ago).',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: AppTheme.textPrimary(ctx),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Did you take it just now, or did you take it earlier near ${dose.time} and are just recording it now?',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary(ctx),
                    height: 1.4,
                  ),
                ),
              ],
            ),
            actions: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  onUpdateStatus(DoseStatus.taken);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✓ Recorded ${dose.medication.name} as Taken Earlier near ${dose.time}'),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text('Took Earlier (On Time)'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  onUpdateStatus(DoseStatus.delayed);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('⏱ Recorded ${dose.medication.name} as Taken Delayed'),
                      backgroundColor: const Color(0xFFD97706),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text('Took Just Now (Delayed)'),
              ),
            ],
          );
        },
      );
      return;
    }

    // 3. On-Time Normal Intake (-45 <= diffMinutes <= 45)
    onUpdateStatus(DoseStatus.taken);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Marked ${dose.medication.name} as Taken On Time!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// As-Needed (PRN) End-of-Day Check Banner (Displayed in evening/night for unlogged PRNs)
  Widget _buildEndOfDayPrnCheckBanner(BuildContext context, List<Medication> unloggedPrns) {
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF0D9488) : const Color(0xFF14B8A6),
          width: 1.4,
        ),
        boxShadow: AppTheme.glowShadow(const Color(0xFF0D9488), opacity: 0.15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.nightlight_round, color: Color(0xFF0D9488), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'End-of-Day As-Needed (PRN) Check',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Evening Review',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D9488),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Did you need to take any of your as-needed medications today, or were you symptom-free?',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context), height: 1.35),
          ),
          const SizedBox(height: 12),
          for (final med in unloggedPrns) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.cardColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder(context)),
              ),
              child: Row(
                children: [
                  Icon(med.icon, size: 20, color: med.categoryColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          med.name,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        Text(
                          '${med.dosage} • Up to ${med.timesPerDay} dose${med.timesPerDay > 1 ? "s" : ""}/day',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      _logPrnDose(med, DateTime.now(), DoseStatus.notNeeded);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✓ ${med.name} logged as Not Needed today (Symptom-free)'),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Text('Not Needed', style: TextStyle(fontSize: 11.5)),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      _promptPrnDoseTime(med, DateTime.now());
                    },
                    child: const Text('Took Dose', style: TextStyle(fontSize: 11.5)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// As-Needed (PRN) Medications Section on Homeboard
  Widget _buildPrnMedicationsSection(
    BuildContext context,
    List<Medication> prnMeds,
    bool isToday,
    DateTime selectedDate,
  ) {
    final isDark = AppTheme.isDark(context);
    final dateKey = "${selectedDate.year.toString().padLeft(4, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.healing_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'As-Needed (PRN) Medications',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cardBorder(context)),
              ),
              child: Text(
                'Symptom-Driven',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Taken on-demand when symptoms arise. Not restricted by rigid clock times.',
          style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary(context)),
        ),
        const SizedBox(height: 10),
        for (final med in prnMeds) ...[
          Builder(
            builder: (ctx) {
              final logs = med.doseLog[dateKey] ?? [];
              final takenLogs = logs.where((e) => !e.endsWith(':missed') && !e.endsWith(':notNeeded') && !e.endsWith(':not_needed')).toList();
              final isNotNeeded = logs.any((e) => e.endsWith(':notNeeded') || e.endsWith(':not_needed'));
              final takenCount = takenLogs.length;
              final maxDoses = med.timesPerDay;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isNotNeeded
                        ? (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))
                        : (takenCount > 0 ? (isDark ? const Color(0xFF047857) : const Color(0xFF6EE7B7)) : AppTheme.cardBorder(context)),
                    width: (takenCount > 0 || isNotNeeded) ? 1.4 : 1,
                  ),
                  boxShadow: AppTheme.softShadow(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: med.categoryColor.withValues(alpha: isDark ? 0.20 : 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(med.icon, color: med.categoryColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                med.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${med.dosage} • ${med.form.name} • Max $maxDoses dose${maxDoses > 1 ? "s" : ""}/day',
                                style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary(context)),
                              ),
                            ],
                          ),
                        ),
                        if (isNotNeeded) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.cardBorder(context)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_rounded, size: 12, color: AppTheme.textSecondary(context)),
                                const SizedBox(width: 4),
                                Text(
                                  'Not Needed Today',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (takenCount > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$takenCount / $maxDoses Taken',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.successGreenLight : AppTheme.successGreen,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (med.doctorNotes != null && med.doctorNotes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Indication: ${med.doctorNotes}',
                        style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textMuted(context)),
                      ),
                    ],
                    if (isToday) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!isNotNeeded && takenCount == 0) ...[
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                _logPrnDose(med, selectedDate, DoseStatus.notNeeded);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('✓ Marked ${med.name} as Not Needed today (Symptom-free)'),
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.remove_circle_outline_rounded, size: 14),
                              label: const Text('Not Needed', style: TextStyle(fontSize: 11.5)),
                            ),
                            const SizedBox(width: 8),
                          ],
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              _handleTakePrnDose(med, selectedDate, takenCount, maxDoses, takenLogs);
                            },
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: Text(
                              takenCount == 0 ? 'Take PRN Dose' : 'Take Another Dose ($takenCount/$maxDoses)',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  void _handleTakePrnDose(
    Medication med,
    DateTime date,
    int takenCount,
    int maxDoses,
    List<String> takenLogs,
  ) {
    final now = DateTime.now();

    // 1. Daily Cap Check
    if (takenCount >= maxDoses) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.cardColor(ctx),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C), size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('Daily Limit Reached', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Text(
            'You have already logged $takenCount dose${takenCount > 1 ? "s" : ""} today, which is the maximum safe daily limit ($maxDoses dose${maxDoses > 1 ? "s" : ""} in 24 hours) for ${med.name}.\n\nTaking additional doses may lead to adverse effects or toxicity. Please contact your physician or pharmacist before taking more.',
            style: const TextStyle(fontSize: 12.5, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // 2. Minimum Spacing Interval Check (if taken within last 4 hours)
    if (takenLogs.isNotEmpty) {
      final lastLog = takenLogs.last;
      final parts = lastLog.split(':');
      if (parts.length >= 2) {
        final lastH = int.tryParse(parts[0]) ?? 0;
        final lastM = int.tryParse(parts[1]) ?? 0;
        final lastTime = DateTime(date.year, date.month, date.day, lastH, lastM);
        final diffHours = now.difference(lastTime).inMinutes / 60.0;
        if (diffHours < 4.0 && diffHours >= 0) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.cardColor(ctx),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.schedule_rounded, color: Color(0xFFD97706), size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Interval Separation Warning', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: Text(
                'Your previous dose of ${med.name} was logged at ${parts[0]}:${parts[1]} (${diffHours.toStringAsFixed(1)} hours ago).\n\nClinical guidelines recommend spacing PRN doses at least 4 to 6 hours apart to prevent drug accumulation.\n\nDo you still need to log this dose now?',
                style: const TextStyle(fontSize: 12.5, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel / Wait'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _logPrnDose(med, date, DoseStatus.taken);
                  },
                  child: const Text('Confirm Intake Now'),
                ),
              ],
            ),
          );
          return;
        }
      }
    }

    // Normal PRN intake
    _logPrnDose(med, date, DoseStatus.taken);
  }

  void _logPrnDose(Medication med, DateTime date, DoseStatus status) {
    final now = DateTime.now();
    final timeStr = status == DoseStatus.notNeeded ? 'PRN' : DateFormat('HH:mm').format(now);
    ref.read(medicationsNotifierProvider.notifier).setDoseStatus(
      med.id,
      date,
      timeStr,
      status,
    );
    if (status == DoseStatus.taken) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Logged ${med.name} dose at $timeStr'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _promptPrnDoseTime(Medication med, DateTime date) async {
    final now = DateTime.now();
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (pickedTime != null) {
      final hh = pickedTime.hour.toString().padLeft(2, '0');
      final mm = pickedTime.minute.toString().padLeft(2, '0');
      final timeStr = '$hh:$mm';
      ref.read(medicationsNotifierProvider.notifier).setDoseStatus(
        med.id,
        date,
        timeStr,
        DoseStatus.taken,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Logged ${med.name} dose at $timeStr'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildUnifiedTodayScheduleHero({
    required BuildContext context,
    required bool isDark,
    required bool isToday,
    required String formattedScheduleTitle,
    required double progress,
    required int takenCount,
    required int pendingCount,
    required int delayedCount,
    required int missedCount,
    required int notNeededCount,
    required int totalDoses,
    required DoseItem? nextPendingDose,
    required UserProfile profile,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  primary.withValues(alpha: 0.90),
                  secondary.withValues(alpha: 0.80),
                ]
              : [
                  primary,
                  secondary,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: AppTheme.glowShadow(
          primary,
          opacity: 0.28,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Row: Date/Schedule Title + Percentage Badge
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
          const SizedBox(height: 12),

          // 2. Linear Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? secondary : const Color(0xFF5EEAD4),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3. Status Breakdown Pills
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
          const SizedBox(height: 14),

          // 4. Integrated Next Dose / Schedule Spotlight
          _buildNextDoseSpotlight(
            context: context,
            isDark: isDark,
            isToday: isToday,
            totalDoses: totalDoses,
            pendingCount: pendingCount,
            nextPendingDose: nextPendingDose,
            profile: profile,
          ),
        ],
      ),
    );
  }

  Widget _buildNextDoseSpotlight({
    required BuildContext context,
    required bool isDark,
    required bool isToday,
    required int totalDoses,
    required int pendingCount,
    required DoseItem? nextPendingDose,
    required UserProfile profile,
  }) {
    if (isToday && nextPendingDose != null) {
      final now = DateTime.now();
      final doseDateTime = _parseDoseDateTime(now, nextPendingDose.time);
      final diff = doseDateTime.difference(now);
      final countdownText = _formatCountdown(diff);
      final isOverdue = diff.isNegative && diff.abs().inMinutes >= 15;
      final med = nextPendingDose.medication;
      final allergyFlags = SchedulerService.getAllergyConflictsForMedication(
        medication: med,
        profile: profile,
      );

      return Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOverdue
                ? const Color(0xFFFCA5A5)
                : Colors.white.withValues(alpha: 0.20),
            width: isOverdue ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Spotlight Subheader: Label + Countdown Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isOverdue ? Icons.warning_amber_rounded : Icons.timer_rounded,
                      color: isOverdue ? const Color(0xFFFDE68A) : Colors.white70,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'NEXT MEDICATION',
                      style: TextStyle(
                        color: isOverdue ? const Color(0xFFFDE68A) : Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? const Color(0xFFEF4444).withValues(alpha: 0.40)
                        : Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    countdownText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Med Details Row with Take Action Button
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Icon(
                    med.icon,
                    size: 24,
                    color: Colors.white,
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
                              med.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => showMedicationClinicalGuide(
                              context,
                              medicationName: med.name,
                              medication: med,
                            ),
                            child: const Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${med.dosage} • Scheduled for ${nextPendingDose.time}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.90),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _evaluateDoseIntakeTiming(
                      context: context,
                      dose: nextPendingDose,
                      date: _selectedDate,
                      onUpdateStatus: (newStatus) {
                        ref
                            .read(medicationsNotifierProvider.notifier)
                            .setDoseStatus(
                              nextPendingDose.medication.id,
                              _selectedDate,
                              nextPendingDose.time,
                              newStatus,
                            );
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Take',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Pre-condition badges if applicable
            if (med.preConditions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final pre in med.preConditions)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'BEFORE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            pre.description,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],

            // Allergy Alert if applicable
            if (allergyFlags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flag_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Allergy Alert: ${allergyFlags.first.relatedAllergy ?? "Potential conflict"}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Default status summary when no next pending dose or not today
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              totalDoses == 0
                  ? 'No medications scheduled for this day.'
                  : (pendingCount == 0
                      ? 'Outstanding! All scheduled doses completed for today.'
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

              // Check if any medication is active on this day (or has taken doses for discontinued)
              final hasMeds = medications.any((m) =>
                  (!m.isDiscontinued && m.isActiveOn(date)) ||
                  (m.isDiscontinued &&
                      m.scheduledTimes.any((t) {
                        final s = m.getDoseStatus(date, t);
                        return s == DoseStatus.taken || s == DoseStatus.takenEarly;
                      })));

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

void showDoseIntakeStatusPicker({
  required BuildContext context,
  required DoseItem dose,
  required ValueChanged<DoseStatus> onUpdateStatus,
  void Function(DoseStatus)? onEvaluateIntake,
}) {
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
              _buildIntakeStatusOption(
                ctx: ctx,
                currentStatus: dose.status,
                status: DoseStatus.taken,
                title: 'Taken On Time',
                subtitle: 'Taken as scheduled within optimal therapeutic window',
                icon: Icons.check_circle_rounded,
                color: isDark ? AppTheme.successGreenLight : AppTheme.successGreen,
                onUpdateStatus: onUpdateStatus,
                onEvaluateIntake: onEvaluateIntake,
                dose: dose,
              ),
              const SizedBox(height: 8),
              _buildIntakeStatusOption(
                ctx: ctx,
                currentStatus: dose.status,
                status: DoseStatus.takenEarly,
                title: 'Taken Early',
                subtitle: 'Administered in advance ahead of the scheduled time slot',
                icon: Icons.alarm_on_rounded,
                color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488),
                onUpdateStatus: onUpdateStatus,
                dose: dose,
              ),
              const SizedBox(height: 8),
              _buildIntakeStatusOption(
                ctx: ctx,
                currentStatus: dose.status,
                status: DoseStatus.delayed,
                title: 'Taken Delayed / Late',
                subtitle: 'Taken late after the scheduled time',
                icon: Icons.schedule_rounded,
                color: isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber,
                onUpdateStatus: onUpdateStatus,
                dose: dose,
              ),
              const SizedBox(height: 8),
              _buildIntakeStatusOption(
                ctx: ctx,
                currentStatus: dose.status,
                status: DoseStatus.missed,
                title: 'Missed Window',
                subtitle: 'Window expired or unable to take dose safely',
                icon: Icons.cancel_rounded,
                color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                onUpdateStatus: onUpdateStatus,
                dose: dose,
              ),
              if (med.scheduleFrequency == ScheduleFrequency.asNeeded) ...[
                const SizedBox(height: 8),
                _buildIntakeStatusOption(
                  ctx: ctx,
                  currentStatus: dose.status,
                  status: DoseStatus.notNeeded,
                  title: 'Not Needed (As Needed / PRN)',
                  subtitle: 'Symptoms absent or medication was not required today',
                  icon: Icons.remove_circle_outline_rounded,
                  color: isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade700,
                  onUpdateStatus: onUpdateStatus,
                  dose: dose,
                ),
              ],
              const SizedBox(height: 8),
              _buildIntakeStatusOption(
                ctx: ctx,
                currentStatus: dose.status,
                status: DoseStatus.pending,
                title: 'Reset to Pending',
                subtitle: 'Clear intake log for this time slot',
                icon: Icons.restore_rounded,
                color: AppTheme.textMuted(ctx),
                onUpdateStatus: onUpdateStatus,
                dose: dose,
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildIntakeStatusOption({
  required BuildContext ctx,
  required DoseStatus currentStatus,
  required DoseStatus status,
  required String title,
  required String subtitle,
  required IconData icon,
  required Color color,
  required ValueChanged<DoseStatus> onUpdateStatus,
  void Function(DoseStatus)? onEvaluateIntake,
  required DoseItem dose,
}) {
  final isSelected = currentStatus == status;

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
      } else if (status == DoseStatus.taken && onEvaluateIntake != null) {
        Navigator.pop(ctx);
        onEvaluateIntake(DoseStatus.taken);
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

class _RoutineSlotHeader extends StatelessWidget {
  final RoutineSlotGroup group;
  final bool isToday;
  final VoidCallback onTakeAll;
  final ValueChanged<ClinicalSlotConflict> onAutoSpaceConflict;

  const _RoutineSlotHeader({
    required this.group,
    required this.isToday,
    required this.onTakeAll,
    required this.onAutoSpaceConflict,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(top: 14, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: isDark ? 0.20 : 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(group.icon, size: 16, color: primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        group.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant(context),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${group.doses.length} ${group.doses.length == 1 ? "med" : "meds"}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isToday && group.pendingCount > 1) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onTakeAll,
                  icon: const Icon(Icons.done_all_rounded, size: 14),
                  label: Text('Take All (${group.pendingCount})'),
                ),
              ] else if (group.allTaken) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.successGreen),
                    const SizedBox(width: 4),
                    Text(
                      'All Taken',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),

          // Conflict Banner if any medications in this slot collide
          if (group.conflicts.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final conflict in group.conflicts)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: conflict.isSevere
                      ? const Color(0xFFFEE2E2).withValues(alpha: isDark ? 0.20 : 0.85)
                      : const Color(0xFFFEF3C7).withValues(alpha: isDark ? 0.20 : 0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: conflict.isSevere
                        ? const Color(0xFFDC2626)
                        : const Color(0xFFF59E0B),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          conflict.isSevere ? Icons.dangerous_rounded : Icons.warning_amber_rounded,
                          size: 16,
                          color: conflict.isSevere ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            conflict.title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: conflict.isSevere ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conflict.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        height: 1.35,
                      ),
                    ),
                    if (conflict.requiredSpacingHours > 0) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => onAutoSpaceConflict(conflict),
                          icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
                          label: Text('Auto-Space (${conflict.medicationB.name} +${conflict.requiredSpacingHours}h)'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
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
  final void Function(DoseStatus)? onEvaluateIntake;

  const _DoseTimelineCard({
    required this.dose,
    required this.date,
    this.isLocked = false,
    required this.onUpdateStatus,
    this.onEvaluateIntake,
  });

  void _showStatusPicker(BuildContext context) {
    showDoseIntakeStatusPicker(
      context: context,
      dose: dose,
      onUpdateStatus: onUpdateStatus,
      onEvaluateIntake: onEvaluateIntake,
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
          if (onEvaluateIntake != null) {
            onEvaluateIntake!(DoseStatus.taken);
          } else {
            onUpdateStatus(DoseStatus.taken);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✓ ${med.name} marked as Taken!'),
                duration: const Duration(seconds: 2),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            );
          }
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
                        // Clinical Necessity Level Badge
                        if (med.necessityLevel == NecessityLevel.critical ||
                            med.necessityLevel == NecessityLevel.vital) ...[
                          Container(
                            margin: const EdgeInsets.only(top: 4, bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: med.necessityLevel.color.withValues(alpha: isDark ? 0.22 : 0.12),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: med.necessityLevel.color.withValues(alpha: 0.55),
                                width: 0.9,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  med.necessityLevel.icon,
                                  size: 12,
                                  color: med.necessityLevel.color,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    med.necessityLevel.badgeText,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: med.necessityLevel.color,
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
