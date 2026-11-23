import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/medication.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Background notification tap receiver
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final _responseController = StreamController<NotificationResponse>.broadcast();
  Stream<NotificationResponse> get onNotificationResponse => _responseController.stream;

  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() =>
      _notificationsPlugin.getNotificationAppLaunchDetails();

  static const String channelId = 'medisync_reminders_channel_v3';
  static const String channelName = 'Medication Reminders';
  static const String channelDescription =
      'Audible alerts and distinct vibration pulses for scheduled medications';

  static const String mealChannelId = 'medisync_meals_channel_v3';
  static const String mealChannelName = 'Meal & Nutrition Sync';
  static const String mealChannelDescription =
      'Companion meal reminders to ensure safe, comfortable medication timing';

  bool _canScheduleExact = true;

  Future<void> init() async {
    tz.initializeTimeZones();
    await _configureLocalTimeZone();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentSound: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _responseController.add(response);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Custom vibration rhythm: [pause, pulse, pause, pulse, pause, long pulse]
    final vibrationPattern = Int64List.fromList([0, 350, 150, 350, 150, 650]);

    // Create High-Priority Medication Channel
    final androidMedChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      showBadge: true,
      enableLights: true,
    );

    // Create Companion Meal Channel
    final androidMealChannel = AndroidNotificationChannel(
      mealChannelId,
      mealChannelName,
      description: mealChannelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 200, 100, 200]),
      showBadge: true,
    );

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(androidMedChannel);
      await androidImplementation.createNotificationChannel(androidMealChannel);
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
      try {
        final can = await androidImplementation.canScheduleExactNotifications();
        _canScheduleExact = can ?? true;
      } catch (_) {
        _canScheduleExact = true;
      }
    }
  }

  /// Queries the device's native local timezone and sets it in the timezone database
  Future<void> _configureLocalTimeZone() async {
    try {
      const channel = MethodChannel('com.example.medisync/device_integration');
      final String? timeZoneName =
          await channel.invokeMethod<String>('getTimeZone');
      if (timeZoneName != null && timeZoneName.isNotEmpty) {
        try {
          tz.setLocalLocation(tz.getLocation(timeZoneName));
          return;
        } catch (_) {
          // If timezone name is non-standard or aliased, find by offset
          final currentOffset = DateTime.now().timeZoneOffset.inMilliseconds;
          for (final location in tz.timeZoneDatabase.locations.values) {
            if (location.currentTimeZone.offset == currentOffset) {
              tz.setLocalLocation(location);
              return;
            }
          }
        }
      }
    } catch (_) {
      // In test environments or fallback, set local location matching system offset
      try {
        final currentOffset = DateTime.now().timeZoneOffset.inMilliseconds;
        for (final location in tz.timeZoneDatabase.locations.values) {
          if (location.currentTimeZone.offset == currentOffset) {
            tz.setLocalLocation(location);
            return;
          }
        }
      } catch (_) {}
    }
  }

  /// Deterministic Notification ID generator for daily doses
  static int getNotificationId(String medId, String time) {
    return (medId.hashCode ^ time.hashCode).abs() & 0x7FFFFFFF;
  }

  /// Deterministic Notification ID for Pre-Dose Preparation Reminder (15 min before)
  static int getPreNotificationId(String medId, String time) {
    return (medId.hashCode ^ time.hashCode ^ 0x33333333).abs() & 0x7FFFFFFF;
  }

  /// Deterministic Notification ID for Post-Dose Recovery Advisory (30 min after)
  static int getPostNotificationId(String medId, String time) {
    return (medId.hashCode ^ time.hashCode ^ 0x77777777).abs() & 0x7FFFFFFF;
  }

  /// Deterministic Notification ID generator for specific weekday doses
  static int getNotificationIdWithDay(String medId, String time, int dayOfWeek) {
    return (medId.hashCode ^ time.hashCode ^ (dayOfWeek * 7919)).abs() &
        0x7FFFFFFF;
  }

  /// Deterministic Notification ID generator for meal companion reminders
  static int getMealNotificationId(String medId, String time) {
    return (medId.hashCode ^ time.hashCode ^ 0x55555555).abs() & 0x7FFFFFFF;
  }

  /// Sends an immediate test notification with sound and vibration
  Future<void> showTestNotification({
    String title = '⏰ MediSync Smart Reminder',
    String body =
        'Time for Metformin (500mg). Condition: 20 minutes after your meal!',
  }) async {
    final vibrationPattern = Int64List.fromList([0, 350, 150, 350, 150, 650]);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'MediSync Alarm',
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      category: AndroidNotificationCategory.alarm,
      styleInformation: const BigTextStyleInformation(''),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'action_taken',
          '✓ Taken',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'action_snooze',
          '⏰ Snooze (+15m)',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'action_skip',
          '⚠️ Skip',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    final payload = jsonEncode({
      'actionType': 'test_dose',
      'medId': 'test_med',
      'medName': 'Metformin',
      'dosage': '500mg',
      'time': '12:00',
      'necessity': 'medium',
    });

    await _notificationsPlugin.show(
      999, // Test notification ID
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Schedules recurring daily medication dose notification
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
    List<AndroidNotificationAction>? actions,
  }) async {
    final vibrationPattern = Int64List.fromList([0, 350, 150, 350, 150, 650]);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      category: AndroidNotificationCategory.alarm,
      styleInformation: BigTextStyleInformation(body),
      actions: actions,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final mode = _canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        payload: payload,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      if (_canScheduleExact) {
        _canScheduleExact = false;
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    }
  }

  /// Schedules weekly repeating medication dose notification on a specific weekday
  Future<void> scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required int dayOfWeek, // 1 = Monday, 7 = Sunday
    required int hour,
    required int minute,
    String? payload,
    List<AndroidNotificationAction>? actions,
  }) async {
    final vibrationPattern = Int64List.fromList([0, 350, 150, 350, 150, 650]);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      category: AndroidNotificationCategory.alarm,
      styleInformation: BigTextStyleInformation(body),
      actions: actions,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduledDate.weekday != dayOfWeek || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final mode = _canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        payload: payload,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (_) {
      if (_canScheduleExact) {
        _canScheduleExact = false;
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  /// Schedules monthly repeating medication dose notification on a specific day of month
  Future<void> scheduleMonthlyNotification({
    required int id,
    required String title,
    required String body,
    required int dayOfMonth, // 1 to 31
    required int hour,
    required int minute,
    String? payload,
    List<AndroidNotificationAction>? actions,
  }) async {
    final vibrationPattern = Int64List.fromList([0, 350, 150, 350, 150, 650]);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      category: AndroidNotificationCategory.alarm,
      styleInformation: BigTextStyleInformation(body),
      actions: actions,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    final now = tz.TZDateTime.now(tz.local);
    final clampedDay = dayOfMonth.clamp(1, 28);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      clampedDay,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      var nextMonth = now.month + 1;
      var nextYear = now.year;
      if (nextMonth > 12) {
        nextMonth = 1;
        nextYear++;
      }
      scheduledDate = tz.TZDateTime(
        tz.local,
        nextYear,
        nextMonth,
        clampedDay,
        hour,
        minute,
      );
    }

    final mode = _canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        payload: payload,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    } catch (_) {
      if (_canScheduleExact) {
        _canScheduleExact = false;
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        );
      }
    }
  }

  /// Automatically schedules all 3-phase dose alarms for a given medication
  Future<void> scheduleMedicationReminders(Medication med) async {
    if (med.isDiscontinued || med.scheduleFrequency == ScheduleFrequency.asNeeded) {
      await cancelMedicationReminders(med);
      return;
    }

    final isAllDays = med.daysOfWeek.isEmpty ||
        med.daysOfWeek.length == 7 ||
        (med.daysOfWeek.toSet().length == 7);

    for (final time in med.scheduledTimes) {
      final parts = time.split(':');
      if (parts.length < 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      // Condition text
      String readableCondition = '';
      if (med.mealCondition != null && med.mealCondition!.trim().isNotEmpty) {
        final mc = med.mealCondition!.trim();
        if (mc == 'before_meal' ||
            mc == 'before_breakfast' ||
            mc == 'before_lunch' ||
            mc == 'before_dinner') {
          readableCondition = 'Take before meal';
        } else if (mc == 'with_meal') {
          readableCondition = 'Take with meal';
        } else if (mc == 'after_meal' ||
            mc == 'after_breakfast' ||
            mc == 'after_lunch' ||
            mc == 'after_dinner') {
          readableCondition = 'Take after meal';
        } else {
          readableCondition = mc;
        }
      }

      // --- PHASE 1: Pre-Dose Preparation Reminder (15 min prior) ---
      final totalMinutes = hour * 60 + minute;
      var preMinutes = totalMinutes - 15;
      if (preMinutes < 0) preMinutes += 24 * 60;
      final preHour = preMinutes ~/ 60;
      final preMin = preMinutes % 60;

      final preBuffer = StringBuffer();
      preBuffer.write('Prepare ${med.dosage} (${med.form.name}).');
      if (readableCondition.isNotEmpty) {
        preBuffer.write(' $readableCondition.');
      }
      if (med.foodRestrictions.isNotEmpty) {
        preBuffer.write(' Avoid: ${med.foodRestrictions.join(", ")}.');
      }

      // --- PHASE 2: Administration Dose Reminder (At scheduled time) ---
      final atBuffer = StringBuffer();
      atBuffer.write('${med.dosage} (${med.form.name})');
      if (readableCondition.isNotEmpty) {
        atBuffer.write('\n🍽️ Condition: $readableCondition');
      }
      if (med.doctorNotes != null && med.doctorNotes!.trim().isNotEmpty) {
        atBuffer.write('\n📝 ${med.doctorNotes!.trim()}');
      }

      // --- PHASE 3: Post-Dose Recovery Advisory (30 min after) ---
      final postMinutes = (totalMinutes + 30) % (24 * 60);
      final postHour = postMinutes ~/ 60;
      final postMin = postMinutes % 60;

      final postBuffer = StringBuffer();
      postBuffer.write(med.missedDoseAdvice);
      if (med.sideEffects.isNotEmpty) {
        postBuffer.write(' Monitor for: ${med.sideEffects.map((s) => s.description).take(2).join(", ")}.');
      }

      // Actionable notification payloads and interactive quick action buttons
      final prePayload = jsonEncode({
        'actionType': 'pre_dose',
        'medId': med.id,
        'medName': med.name,
        'dosage': med.dosage,
        'time': time,
        'necessity': med.necessityLevel.name,
      });
      const preActions = [
        AndroidNotificationAction(
          'action_take_early',
          '✓ Take Early',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ];

      final dosePayload = jsonEncode({
        'actionType': 'dose',
        'medId': med.id,
        'medName': med.name,
        'dosage': med.dosage,
        'time': time,
        'necessity': med.necessityLevel.name,
      });
      const doseActions = [
        AndroidNotificationAction(
          'action_taken',
          '✓ Taken',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'action_snooze',
          '⏰ Snooze (+15m)',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'action_skip',
          '⚠️ Skip',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ];

      final postPayload = jsonEncode({
        'actionType': 'post_dose',
        'medId': med.id,
        'medName': med.name,
        'dosage': med.dosage,
        'time': time,
      });
      const postActions = [
        AndroidNotificationAction(
          'action_ack',
          '✓ Understood',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ];

      if (med.scheduleFrequency == ScheduleFrequency.monthly ||
          med.scheduleFrequency == ScheduleFrequency.twiceMonthly) {
        final days = med.monthlyDays.isNotEmpty
            ? med.monthlyDays
            : (med.scheduleFrequency == ScheduleFrequency.monthly
                ? [med.startDate.day]
                : [1, 15]);
        for (final d in days) {
          await scheduleMonthlyNotification(
            id: getPreNotificationId(med.id, '$time-m$d'),
            title: '⏳ Upcoming: ${med.name} in 15 min',
            body: preBuffer.toString(),
            dayOfMonth: d,
            hour: preHour,
            minute: preMin,
            payload: prePayload,
            actions: preActions,
          );
          await scheduleMonthlyNotification(
            id: getNotificationIdWithDay(med.id, time, d + 100),
            title: '💊 Time for ${med.name}',
            body: atBuffer.toString(),
            dayOfMonth: d,
            hour: hour,
            minute: minute,
            payload: dosePayload,
            actions: doseActions,
          );
          await scheduleMonthlyNotification(
            id: getPostNotificationId(med.id, '$time-m$d'),
            title: '📋 Post-Dose Care: ${med.name}',
            body: postBuffer.toString(),
            dayOfMonth: d,
            hour: postHour,
            minute: postMin,
            payload: postPayload,
            actions: postActions,
          );
        }
      } else if (med.scheduleFrequency == ScheduleFrequency.daily && isAllDays) {
        // Phase 1
        await scheduleDailyNotification(
          id: getPreNotificationId(med.id, time),
          title: '⏳ Upcoming: ${med.name} in 15 min',
          body: preBuffer.toString(),
          hour: preHour,
          minute: preMin,
          payload: prePayload,
          actions: preActions,
        );
        // Phase 2
        await scheduleDailyNotification(
          id: getNotificationId(med.id, time),
          title: '💊 Time for ${med.name}',
          body: atBuffer.toString(),
          hour: hour,
          minute: minute,
          payload: dosePayload,
          actions: doseActions,
        );
        // Phase 3
        await scheduleDailyNotification(
          id: getPostNotificationId(med.id, time),
          title: '📋 Post-Dose Care: ${med.name}',
          body: postBuffer.toString(),
          hour: postHour,
          minute: postMin,
          payload: postPayload,
          actions: postActions,
        );
      } else {
        final targetDays = med.daysOfWeek.isNotEmpty ? med.daysOfWeek : [med.startDate.weekday];
        for (final day in targetDays) {
          if (day >= 1 && day <= 7) {
            await scheduleWeeklyNotification(
              id: getPreNotificationId(med.id, '$time-$day'),
              title: '⏳ Upcoming: ${med.name} in 15 min',
              body: preBuffer.toString(),
              dayOfWeek: day,
              hour: preHour,
              minute: preMin,
              payload: prePayload,
              actions: preActions,
            );
            await scheduleWeeklyNotification(
              id: getNotificationIdWithDay(med.id, time, day),
              title: '💊 Time for ${med.name}',
              body: atBuffer.toString(),
              dayOfWeek: day,
              hour: hour,
              minute: minute,
              payload: dosePayload,
              actions: doseActions,
            );
            await scheduleWeeklyNotification(
              id: getPostNotificationId(med.id, '$time-$day'),
              title: '📋 Post-Dose Care: ${med.name}',
              body: postBuffer.toString(),
              dayOfWeek: day,
              hour: postHour,
              minute: postMin,
              payload: postPayload,
              actions: postActions,
            );
          }
        }
      }
    }
  }

  /// Cancels all alarms associated with a medication (all 3 phases)
  Future<void> cancelMedicationReminders(Medication med) async {
    for (final time in med.scheduledTimes) {
      await cancelNotification(getPreNotificationId(med.id, time));
      await cancelNotification(getNotificationId(med.id, time));
      await cancelNotification(getPostNotificationId(med.id, time));
      for (int day = 1; day <= 7; day++) {
        await cancelNotification(getPreNotificationId(med.id, '$time-$day'));
        await cancelNotification(getNotificationIdWithDay(med.id, time, day));
        await cancelNotification(getPostNotificationId(med.id, '$time-$day'));
      }
      for (int mDay = 1; mDay <= 31; mDay++) {
        await cancelNotification(getPreNotificationId(med.id, '$time-m$mDay'));
        await cancelNotification(getNotificationIdWithDay(med.id, time, mDay + 100));
        await cancelNotification(getPostNotificationId(med.id, '$time-m$mDay'));
      }
      await cancelNotification(getMealNotificationId(med.id, time));
    }
  }

  /// Displays a prominent, ongoing, public Emergency Medical ID notification on the lockscreen
  Future<void> showPersistentEmergencyNotification({
    required String patientName,
    required String bloodType,
    int? allergiesCount,
    int? activeMedsCount,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'emergency_medical_id_channel',
      'Emergency Medical ID',
      channelDescription: 'Persistent 1-touch emergency medical ID for first responders and lock screen',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      visibility: NotificationVisibility.public,
      color: Color(0xFFDC2626),
      colorized: true,
      showWhen: false,
      category: AndroidNotificationCategory.status,
    );

    const details = NotificationDetails(android: androidDetails);
    final allergiesStr = (allergiesCount != null && allergiesCount > 0) ? ' • $allergiesCount Allergies' : '';
    final medsStr = (activeMedsCount != null && activeMedsCount > 0) ? ' • $activeMedsCount Meds' : '';

    await _notificationsPlugin.show(
      888888,
      '🚨 EMERGENCY MEDICAL ID: $patientName',
      'Blood: $bloodType$allergiesStr$medsStr • Tap to view without PIN',
      details,
      payload: 'emergency_card',
    );
  }

  /// Synchronizes all active medication alarms (purges stale/cancelled alarms and reschedules active ones)
  Future<void> syncAllMedicationReminders(List<Medication> medications) async {
    await cancelAll();
    for (final med in medications) {
      if (!med.isDiscontinued) {
        await scheduleMedicationReminders(med);
      }
    }
  }

  /// Schedules companion meal reminder
  Future<void> scheduleMealReminder({
    required int id,
    required String mealName,
    required String advice,
    required int hour,
    required int minute,
  }) async {
    final vibrationPattern = Int64List.fromList([0, 200, 100, 200]);

    final androidDetails = AndroidNotificationDetails(
      mealChannelId,
      mealChannelName,
      channelDescription: mealChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      category: AndroidNotificationCategory.reminder,
      styleInformation: BigTextStyleInformation(advice),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final mode = _canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        '🍽️ $mealName Reminder',
        advice,
        scheduledDate,
        details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      if (_canScheduleExact) {
        _canScheduleExact = false;
        await _notificationsPlugin.zonedSchedule(
          id,
          '🍽️ $mealName Reminder',
          advice,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    }
  }

  /// Schedules a 15-minute actionable snooze reminder with persistent alert and high priority
  Future<void> scheduleSnoozeNotification({
    required String medId,
    required String medName,
    required String dosage,
    required String time,
    int minutes = 15,
    String necessity = 'medium',
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate = now.add(Duration(minutes: minutes));
    final id = (medId.hashCode ^ time.hashCode ^ 0x99999999).abs() & 0x7FFFFFFF;

    final vibrationPattern = Int64List.fromList([0, 350, 150, 350, 150, 650]);
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      category: AndroidNotificationCategory.alarm,
      styleInformation: BigTextStyleInformation('Snoozed dose: $dosage. Time to take it now.'),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'action_taken',
          '✓ Taken',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'action_snooze',
          '⏰ Snooze (+15m)',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'action_skip',
          '⚠️ Skip',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    final payload = jsonEncode({
      'actionType': 'dose',
      'medId': medId,
      'medName': medName,
      'dosage': dosage,
      'time': time,
      'necessity': necessity,
    });

    final mode = _canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        '⏰ Snoozed: $medName ($dosage)',
        'Snooze duration ended. Please administer your dose now.',
        scheduledDate,
        details,
        payload: payload,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      if (_canScheduleExact) {
        _canScheduleExact = false;
        await _notificationsPlugin.zonedSchedule(
          id,
          '⏰ Snoozed: $medName ($dosage)',
          'Snooze duration ended. Please administer your dose now.',
          scheduledDate,
          details,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
