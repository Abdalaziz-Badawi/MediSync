import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medisync/core/models/condition.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/models/user_profile.dart';
import 'package:medisync/core/services/device_integration_service.dart';
import 'package:medisync/core/services/notification_service.dart';
import 'package:medisync/core/services/storage_service.dart';
import 'package:medisync/features/homeboard/presentation/pages/home_page.dart';

class RecordingNotificationService implements NotificationService {
  final List<Map<String, dynamic>> dailyScheduled = [];
  final List<Map<String, dynamic>> monthlyScheduled = [];
  final List<Map<String, dynamic>> persistentEmergencyNotifications = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> showTestNotification({String title = '', String body = ''}) async {}

  @override
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    dailyScheduled.add({
      'id': id,
      'title': title,
      'body': body,
      'hour': hour,
      'minute': minute,
    });
  }

  @override
  Future<void> scheduleMonthlyNotification({
    required int id,
    required String title,
    required String body,
    required int dayOfMonth,
    required int hour,
    required int minute,
  }) async {
    monthlyScheduled.add({
      'id': id,
      'title': title,
      'body': body,
      'dayOfMonth': dayOfMonth,
      'hour': hour,
      'minute': minute,
    });
  }

  @override
  Future<void> showPersistentEmergencyNotification({
    required String patientName,
    required String bloodType,
    int? allergiesCount,
    int? activeMedsCount,
  }) async {
    persistentEmergencyNotifications.add({
      'patientName': patientName,
      'bloodType': bloodType,
      'allergiesCount': allergiesCount,
      'activeMedsCount': activeMedsCount,
    });
  }

  @override
  Future<void> scheduleMealReminder({
    required int id,
    required String mealName,
    required String advice,
    required int hour,
    required int minute,
  }) async {}

  @override
  Future<void> cancelNotification(int id) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required int dayOfWeek,
    required int hour,
    required int minute,
  }) async {}

  @override
  Future<void> scheduleMedicationReminders(Medication med) async {
    final times = med.scheduledTimes;
    if (times.isEmpty) return;

    if (med.scheduleFrequency == ScheduleFrequency.monthly ||
        med.scheduleFrequency == ScheduleFrequency.twiceMonthly) {
      final days = med.monthlyDays.isNotEmpty ? med.monthlyDays : [1];
      for (final d in days) {
        for (final t in times) {
          final parts = t.split(':');
          final hour = int.tryParse(parts[0]) ?? 8;
          final min = int.tryParse(parts[1]) ?? 0;
          await scheduleMonthlyNotification(
            id: med.id.hashCode ^ d ^ hour ^ min,
            title: 'Medication Reminder: ${med.name}',
            body: 'Monthly dose: ${med.dosage}',
            dayOfMonth: d,
            hour: hour,
            minute: min,
          );
        }
      }
      return;
    }

    if (med.scheduleFrequency == ScheduleFrequency.daily) {
      for (final t in times) {
        final parts = t.split(':');
        final hour = int.tryParse(parts[0]) ?? 8;
        final min = int.tryParse(parts[1]) ?? 0;
        await scheduleDailyNotification(
          id: med.id.hashCode ^ hour ^ min,
          title: 'Medication Reminder: ${med.name}',
          body: 'Daily dose: ${med.dosage}',
          hour: hour,
          minute: min,
        );
      }
    }
  }

  @override
  Future<void> cancelMedicationReminders(Medication med) async {}

  @override
  Future<void> syncAllMedicationReminders(List<Medication> medications) async {
    for (final med in medications) {
      await scheduleMedicationReminders(med);
    }
  }
}

class FakeProfileNotifier extends StateNotifier<UserProfile> implements ProfileNotifier {
  FakeProfileNotifier()
      : super(
          const UserProfile(
            name: 'Sarah Connor',
            allergies: ['Penicillin'],
            bloodType: 'O+',
            healthId: 'MED-9921',
            chronicConditions: ['Hypertension'],
            wakeTime: '07:00',
            sleepTime: '23:00',
            breakfastTime: '08:00',
            lunchTime: '13:00',
            dinnerTime: '20:00',
          ),
        );

  @override
  Future<void> updateProfile(UserProfile newProfile) async {
    state = newProfile;
  }
}

class FakeMedicationsNotifier extends StateNotifier<List<Medication>>
    implements MedicationsNotifier {
  FakeMedicationsNotifier(super.initial);

  @override
  Future<void> addOrUpdate(Medication med) async {
    state = [...state, med];
  }

  @override
  Future<void> remove(String id) async {
    state = state.where((m) => m.id != id).toList();
  }

  @override
  Future<void> discontinue(String id, {DateTime? date, String? reason}) async {}

  @override
  Future<void> resume(String id) async {}

  @override
  Future<void> toggleDoseTaken(String id, DateTime date, String time) async {}

  @override
  Future<void> setDoseStatus(String id, DateTime date, String time, DoseStatus status) async {
    state = state.map((m) {
      if (m.id == id) {
        final dateKey =
            "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        final updatedMap = Map<String, List<String>>.from(m.doseLog);
        final entries = List<String>.from(updatedMap[dateKey] ?? []);
        entries.removeWhere((e) => e == time || e.startsWith('$time:'));
        if (status != DoseStatus.pending) {
          entries.add('$time:${status.name}');
        }
        updatedMap[dateKey] = entries;
        return m.copyWith(doseLog: updatedMap);
      }
      return m;
    }).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('v1.7.2 Bug Fixes & Architectural Enhancements Tests', () {
    test('Monthly medication (Vitamin D3) does not trigger daily notifications', () async {
      final notifService = RecordingNotificationService();

      final vitaminD3 = Medication(
        id: 'vit-d3',
        name: 'Vitamin D3 50,000 IU',
        dosage: '1 capsule',
        timesPerDay: 1,
        scheduledTimes: ['09:00'],
        scheduleFrequency: ScheduleFrequency.monthly,
        monthlyDays: [5], // Scheduled specifically for the 5th of every month
        startDate: DateTime(2026, 1, 1),
      );

      await notifService.scheduleMedicationReminders(vitaminD3);

      // Verify that NO daily notifications were scheduled
      expect(notifService.dailyScheduled, isEmpty);

      // Verify that monthly notification was scheduled strictly for day 5
      expect(notifService.monthlyScheduled.length, 1);
      expect(notifService.monthlyScheduled.first['dayOfMonth'], 5);
      expect(notifService.monthlyScheduled.first['hour'], 9);
      expect(notifService.monthlyScheduled.first['minute'], 0);
    });

    testWidgets('Unified Today Schedule Hero Card combines schedule adherence and next dose spotlight',
        (WidgetTester tester) async {
      final med = Medication(
        id: 'med-bp',
        name: 'Lisinopril',
        dosage: '10 mg',
        timesPerDay: 1,
        scheduledTimes: ['23:59'],
        startDate: DateTime.now(),
        preConditions: const [
          MedicationCondition(
            type: ConditionType.drinkWater,
            timing: ConditionTiming.before,
            description: 'Drink full glass of water',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileNotifierProvider.overrideWith((ref) => FakeProfileNotifier()),
            medicationsNotifierProvider.overrideWith((ref) => FakeMedicationsNotifier([med])),
          ],
          child: const MaterialApp(
            home: HomePage(),
          ),
        ),
      );

      // Verify Unified Header is rendered
      expect(find.text("Today's Schedule"), findsOneWidget);
      expect(find.text('0% Done'), findsOneWidget);
      expect(find.text('⏳ 1 Due'), findsOneWidget);

      // Verify Integrated Next Dose Spotlight is rendered inside the same card
      expect(find.text('NEXT MEDICATION'), findsOneWidget);
      expect(find.text('Lisinopril'), findsWidgets);
      expect(find.text('10 mg • Scheduled for 23:59'), findsOneWidget);
      expect(find.text('BEFORE'), findsOneWidget);
      expect(find.text('Drink full glass of water'), findsOneWidget);
      expect(find.text('Take'), findsOneWidget);

      // Tap Take button to verify that interactive status options sheet opens seamlessly
      await tester.tap(find.text('Take').first);
      await tester.pumpAndSettle();

      expect(find.text('Record Dose: Lisinopril (23:59)'), findsOneWidget);
      expect(find.text('Taken On Time'), findsOneWidget);
      expect(find.text('Taken Early'), findsOneWidget);
      expect(find.text('Taken Delayed / Late'), findsOneWidget);
      expect(find.text('Missed Window'), findsOneWidget);
    });

    test('Zero-PIN persistent lockscreen notification is dispatched with patient emergency data', () async {
      final notifService = RecordingNotificationService();

      await notifService.showPersistentEmergencyNotification(
        patientName: 'Sarah Connor',
        bloodType: 'O+',
        allergiesCount: 1,
        activeMedsCount: 1,
      );

      expect(notifService.persistentEmergencyNotifications.length, 1);
      final entry = notifService.persistentEmergencyNotifications.first;
      expect(entry['patientName'], 'Sarah Connor');
      expect(entry['bloodType'], 'O+');
      expect(entry['allergiesCount'], 1);
      expect(entry['activeMedsCount'], 1);
    });

    test('syncEmergencyData serializes full demographics, blood group and dispatches card picture to native storage', () async {
      final methodCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.example.medisync/device_integration'),
        (MethodCall call) async {
          methodCalls.add(call);
          if (call.method == 'updateWidgetData') return true;
          if (call.method == 'saveEmergencyCardImage') return true;
          return null;
        },
      );

      final service = DeviceIntegrationService();
      final profile = UserProfile(
        name: 'Dr. Jane Doe',
        gender: 'Female',
        dateOfBirth: DateTime(1990, 5, 15),
        bloodType: 'AB+',
        healthId: 'HEALTH-4432',
        allergies: const ['Aspirin', 'Sulfa'],
        chronicConditions: const ['Asthma'],
        wakeTime: '07:00',
        sleepTime: '23:00',
        breakfastTime: '08:00',
        lunchTime: '13:00',
        dinnerTime: '20:00',
      );

      final med = Medication(
        id: 'med-inhaler',
        name: 'Albuterol',
        dosage: '90 mcg',
        timesPerDay: 2,
        scheduledTimes: const ['08:00', '20:00'],
        startDate: DateTime.now(),
      );

      await service.syncEmergencyData(profile: profile, medications: [med]);

      final widgetUpdate = methodCalls.firstWhere((c) => c.method == 'updateWidgetData');
      expect(widgetUpdate.arguments['patientName'], 'Dr. Jane Doe');
      expect(widgetUpdate.arguments['bloodType'], 'AB+');
      expect(widgetUpdate.arguments['healthId'], 'HEALTH-4432');
      expect(widgetUpdate.arguments['allergiesCount'], 2);
      expect(widgetUpdate.arguments['activeMedsCount'], 1);
      expect(widgetUpdate.arguments['demographics'], contains('Gender: Female'));
      expect(widgetUpdate.arguments['allergies'], 'Aspirin, Sulfa');
      expect(widgetUpdate.arguments['conditions'], 'Asthma');
      expect(widgetUpdate.arguments['medications'], contains('Albuterol 90 mcg'));

      final imageSave = methodCalls.firstWhere((c) => c.method == 'saveEmergencyCardImage');
      expect(imageSave.arguments['bytes'], isNotNull);
      expect((imageSave.arguments['bytes'] as List).isNotEmpty, isTrue);
    });
  });
}
