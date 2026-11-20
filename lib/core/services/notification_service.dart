import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/medication.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

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

    await _notificationsPlugin.initialize(initSettings);

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

    await _notificationsPlugin.show(
      999, // Test notification ID
      title,
      body,
      details,
    );
  }

  /// Schedules recurring daily medication dose notification
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
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
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  /// Automatically schedules all dose alarms for a given medication
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

      final title = '⏰ Time for ${med.name}';
      final buffer = StringBuffer();
      buffer.write('${med.dosage} (${med.form.name})');

      if (med.mealCondition != null && med.mealCondition!.trim().isNotEmpty) {
        final mc = med.mealCondition!.trim();
        String readableMc = mc;
        if (mc == 'before_meal' ||
            mc == 'before_breakfast' ||
            mc == 'before_lunch' ||
            mc == 'before_dinner') {
          readableMc = 'Take before meal';
        } else if (mc == 'with_meal') {
          readableMc = 'Take with meal';
        } else if (mc == 'after_meal' ||
            mc == 'after_breakfast' ||
            mc == 'after_lunch' ||
            mc == 'after_dinner') {
          readableMc = 'Take after meal';
        }
        buffer.write('\n🍽️ Condition: $readableMc');
      }

      if (med.foodRestrictions.isNotEmpty) {
        buffer.write('\n⚠️ Avoid: ${med.foodRestrictions.join(', ')}');
      }

      final body = buffer.toString();

      if (isAllDays) {
        final id = getNotificationId(med.id, time);
        await scheduleDailyNotification(
          id: id,
          title: title,
          body: body,
          hour: hour,
          minute: minute,
        );
      } else {
        for (final day in med.daysOfWeek) {
          if (day >= 1 && day <= 7) {
            final id = getNotificationIdWithDay(med.id, time, day);
            await scheduleWeeklyNotification(
              id: id,
              title: title,
              body: body,
              dayOfWeek: day,
              hour: hour,
              minute: minute,
            );
          }
        }
      }
    }
  }

  /// Cancels all alarms associated with a medication
  Future<void> cancelMedicationReminders(Medication med) async {
    for (final time in med.scheduledTimes) {
      await cancelNotification(getNotificationId(med.id, time));
      for (int day = 1; day <= 7; day++) {
        await cancelNotification(getNotificationIdWithDay(med.id, time, day));
      }
      await cancelNotification(getMealNotificationId(med.id, time));
    }
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

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  throw UnimplementedError('NotificationService must be initialized in main');
});
