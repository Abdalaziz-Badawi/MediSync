import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/models/user_profile.dart';
import 'package:medisync/core/services/device_integration_service.dart';
import 'package:medisync/core/services/notification_service.dart';
import 'package:medisync/core/services/storage_service.dart';
import 'package:medisync/core/theme/app_theme.dart';
import 'package:medisync/features/homeboard/presentation/pages/home_page.dart';
import 'package:medisync/features/homeboard/presentation/widgets/next_dose_countdown_card.dart';
import 'package:medisync/features/profile/presentation/pages/profile_page.dart';
import 'package:medisync/features/profile/presentation/widgets/emergency_health_card.dart';
import 'package:medisync/features/records/presentation/pages/records_page.dart';
import 'package:medisync/features/splash/presentation/pages/splash_screen.dart';

class FakeProfileNotifier extends StateNotifier<UserProfile>
    implements ProfileNotifier {
  FakeProfileNotifier()
      : super(
          UserProfile(
            name: 'Sarah Connor',
            dateOfBirth: DateTime(1985, 4, 12),
            healthId: 'ID-99201-X',
            bloodType: 'O+',
            gender: 'Female',
            allergies: const ['Penicillin'],
            wakeTime: '07:00',
            sleepTime: '23:00',
          ),
        );

  @override
  Future<void> updateProfile(UserProfile newProfile) async {
    state = newProfile;
  }
}

class FakeProfileWithConditionsNotifier extends StateNotifier<UserProfile>
    implements ProfileNotifier {
  FakeProfileWithConditionsNotifier()
      : super(
          UserProfile(
            name: 'Sarah Connor',
            dateOfBirth: DateTime(1985, 4, 12),
            healthId: 'ID-99201-X',
            bloodType: 'O+',
            gender: 'Female',
            allergies: const ['Penicillin'],
            chronicConditions: const ['Asthma', 'Hypertension'],
            wakeTime: '07:00',
            sleepTime: '23:00',
          ),
        );

  @override
  Future<void> updateProfile(UserProfile newProfile) async {
    state = newProfile;
  }
}

class FakeThemeNotifier extends StateNotifier<ThemeMode>
    implements ThemeNotifier {
  FakeThemeNotifier() : super(ThemeMode.light);

  @override
  void setThemeMode(ThemeMode mode) {
    state = mode;
  }

  @override
  void toggleTheme() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
}

class FakeFontScaleNotifier extends StateNotifier<double>
    implements FontScaleNotifier {
  FakeFontScaleNotifier() : super(1.0);

  @override
  void setFontScale(double scale) {
    state = scale;
  }
}

class FakePaletteNotifier extends StateNotifier<AppPalette>
    implements PaletteNotifier {
  FakePaletteNotifier() : super(AppPalette.emeraldTeal);

  @override
  void setPalette(AppPalette palette) {
    state = palette;
  }
}

class FakeNotificationService implements NotificationService {
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
  }) async {}

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
}

class FakeStorageService implements StorageService {
  @override
  bool isSetupCompleted() => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Test mock notifier for medications
class MockMedicationsNotifier extends StateNotifier<List<Medication>>
    implements MedicationsNotifier {
  DoseStatus? lastRecordedStatus;
  String? lastRecordedTime;

  MockMedicationsNotifier(super.state);

  @override
  Future<void> addOrUpdate(Medication med) async {}

  @override
  Future<void> remove(String id) async {}

  @override
  Future<void> discontinue(String id, {DateTime? date, String? reason}) async {}

  @override
  Future<void> resume(String id) async {}

  @override
  Future<void> toggleDoseTaken(String medId, DateTime date, String time) async {}

  @override
  Future<void> setDoseStatus(
    String medId,
    DateTime date,
    String time,
    DoseStatus status,
  ) async {
    lastRecordedStatus = status;
    lastRecordedTime = time;
  }
}

void main() {
  group('v1.6.2 Demographics, Emergency Card & Dose Intake Options Tests', () {
    test('Dynamic Age Calculation from Date of Birth (DoB)', () {
      final now = DateTime.now();

      // Case 1: Birthday already occurred earlier this year
      // Born on January 1, 30 years ago
      final pastBirthday = DateTime(now.year - 30, 1, 1);
      final profilePast = UserProfile(
        name: 'Alex Mercer',
        dateOfBirth: pastBirthday,
      );
      expect(profilePast.age, equals(30));

      // Case 2: Birthday has not yet occurred this year
      // Born on December 31, 30 years ago
      final futureBirthday = DateTime(now.year - 30, 12, 31);
      final profileFuture = UserProfile(
        name: 'Dana Mercer',
        dateOfBirth: futureBirthday,
      );
      if (now.month == 12 && now.day == 31) {
        expect(profileFuture.age, equals(30));
      } else {
        expect(profileFuture.age, equals(29));
      }

      // Case 3: Leap Year birthday (Feb 29)
      final leapYearBirthday = DateTime(2000, 2, 29);
      final profileLeap = UserProfile(
        name: 'Leap Year Child',
        dateOfBirth: leapYearBirthday,
      );
      expect(profileLeap.age, isNotNull);
      expect(profileLeap.age, greaterThanOrEqualTo(24));

      // Case 4: Future date of birth clamped to 0
      final unbornProfile = UserProfile(
        name: 'Future Person',
        dateOfBirth: now.add(const Duration(days: 30)),
      );
      expect(unbornProfile.age, equals(0));

      // Case 5: Legacy explicit age fallback when dateOfBirth is null
      final legacyProfile = UserProfile.fromJson({
        'name': 'Legacy User',
        'age': 45,
        'gender': 'Male',
      });
      expect(legacyProfile.dateOfBirth, isNull);
      expect(legacyProfile.age, equals(45));
    });

    test('Health ID and Blood Type Demographics serialization & copyWith', () {
      expect(UserProfile.standardBloodTypes, containsAll([
        'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
      ]));

      final dob = DateTime(1988, 7, 24);
      final profile = UserProfile(
        name: 'Dr. John Watson',
        dateOfBirth: dob,
        healthId: 'MRN-784-2026-X',
        bloodType: 'O-',
        gender: 'Male',
        allergies: ['Penicillin', 'Sulfa'],
        chronicConditions: ['Hypertension'],
      );

      final json = profile.toJson();
      expect(json['healthId'], equals('MRN-784-2026-X'));
      expect(json['bloodType'], equals('O-'));
      expect(json['dateOfBirth'], equals(dob.toIso8601String()));

      // Restoration from JSON
      final restored = UserProfile.fromJson(json);
      expect(restored.name, equals('Dr. John Watson'));
      expect(restored.healthId, equals('MRN-784-2026-X'));
      expect(restored.bloodType, equals('O-'));
      expect(restored.dateOfBirth, equals(dob));
      expect(restored.allergies, contains('Penicillin'));

      // copyWith updates
      final updated = restored.copyWith(
        healthId: 'NHS-992182',
        bloodType: 'AB+',
      );
      expect(updated.healthId, equals('NHS-992182'));
      expect(updated.bloodType, equals('AB+'));
      expect(updated.dateOfBirth, equals(dob));
    });

    test('DeviceIntegrationService headless Emergency Card Byte Renderer', () async {
      final profile = UserProfile(
        name: 'Sarah Connor',
        dateOfBirth: DateTime(1985, 4, 12),
        healthId: 'ID-TERMINATOR-800',
        bloodType: 'O-',
        gender: 'Female',
        allergies: ['Amoxicillin', 'Latex'],
      );

      final med = Medication(
        id: 'med-card-1',
        name: 'Metformin',
        dosage: '850 mg',
        timesPerDay: 2,
        scheduledTimes: ['08:00', '20:00'],
        startDate: DateTime.now(),
      );

      final service = DeviceIntegrationService();
      final Uint8List bytes = await service.renderEmergencyCardBytes(
        profile: profile,
        medications: [med],
      );

      expect(bytes.isNotEmpty, isTrue);
      // Verify PNG magic header signature [137, 80, 78, 71, 13, 10, 26, 10]
      expect(bytes[0], equals(0x89));
      expect(bytes[1], equals(0x50)); // 'P'
      expect(bytes[2], equals(0x4E)); // 'N'
      expect(bytes[3], equals(0x47)); // 'G'

      // Check ReportExportFormat.jpg
      expect(ReportExportFormat.jpg.mimeType, equals('image/jpeg'));
      expect(ReportExportFormat.jpg.fileExtension, equals('.jpg'));
      expect(ReportExportFormat.jpg.label, contains('Emergency ID Card'));
    });

    testWidgets('EmergencyHealthCardWidget renders demographic badges, allergies alert and medications', (tester) async {
      final profile = UserProfile(
        name: 'Bruce Wayne',
        dateOfBirth: DateTime(1980, 5, 27),
        healthId: 'GOTHAM-001',
        bloodType: 'O+',
        gender: 'Male',
        allergies: ['Penicillin', 'Peanuts'],
      );

      final meds = [
        Medication(
          id: 'b-1',
          name: 'Aspirin Cardio',
          dosage: '81 mg',
          timesPerDay: 1,
          scheduledTimes: ['08:00'],
          startDate: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EmergencyHealthCardWidget(
                profile: profile,
                medications: meds,
              ),
            ),
          ),
        ),
      );

      expect(find.text('BRUCE WAYNE'), findsOneWidget);
      expect(find.text('EMERGENCY MEDICAL ID'), findsOneWidget);
      expect(find.text('ID: GOTHAM-001'), findsOneWidget);
      expect(find.text('BLOOD: O+'), findsOneWidget);
      expect(find.text('CRITICAL ALLERGIES & CONTRAINDICATIONS:'), findsOneWidget);
      expect(find.textContaining('Penicillin'), findsOneWidget);
      expect(find.textContaining('Peanuts'), findsOneWidget);
      expect(find.text('ACTIVE MEDICATIONS'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Aspirin Cardio')),
        findsOneWidget,
      );
    });

    testWidgets('NextDoseCountdownCard Take button opens interactive clinical intake options bottom sheet', (tester) async {
      final med = Medication(
        id: 'med-take-opt',
        name: 'Panadol Extra',
        dosage: '500 mg',
        timesPerDay: 1,
        scheduledTimes: ['23:59'],
        startDate: DateTime.now(),
      );

      final mockNotifier = MockMedicationsNotifier([med]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileNotifierProvider.overrideWith((ref) => FakeProfileNotifier()),
            medicationsNotifierProvider.overrideWith((ref) => mockNotifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: NextDoseCountdownCard(
                medications: [med],
                onMarkTaken: (id, date, time) {},
              ),
            ),
          ),
        ),
      );

      // Verify Next Dose Countdown Card is present
      expect(find.text('Panadol Extra'), findsOneWidget);
      expect(find.text('Take'), findsOneWidget);

      // Tap "Take" button to open intake options sheet
      await tester.tap(find.text('Take'));
      await tester.pumpAndSettle();

      // Verify that all clinical options are present in the bottom sheet
      expect(find.text('Record Intake: Panadol Extra'), findsOneWidget);
      expect(find.text('Taken On Time'), findsOneWidget);
      expect(find.text('Taken Early'), findsOneWidget);
      expect(find.text('Taken Delayed / Late'), findsOneWidget);
      expect(find.text('Mark as Missed'), findsOneWidget);
      expect(find.text('Not Needed Today (Skip)'), findsOneWidget);

      // Tap "Taken Early" option
      await tester.tap(find.text('Taken Early'));
      await tester.pumpAndSettle();

      // Verify mock recorded status
      expect(mockNotifier.lastRecordedStatus, equals(DoseStatus.takenEarly));
      expect(mockNotifier.lastRecordedTime, equals('23:59'));
    });

    testWidgets('Profile Page renders bio info widgets and handles narrow screens without overflow', (tester) async {
      tester.view.physicalSize = const Size(340 * 2, 700 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileNotifierProvider.overrideWith((ref) => FakeProfileNotifier()),
            medicationsNotifierProvider.overrideWith((ref) => MockMedicationsNotifier([])),
            themeNotifierProvider.overrideWith((ref) => FakeThemeNotifier()),
            fontScaleNotifierProvider.overrideWith((ref) => FakeFontScaleNotifier()),
            paletteNotifierProvider.overrideWith((ref) => FakePaletteNotifier()),
            notificationServiceProvider.overrideWithValue(FakeNotificationService()),
          ],
          child: const MaterialApp(
            home: ProfilePage(initiallyExpanded: true),
          ),
        ),
      );

      // Verify Bio & Demographics section header and action button
      expect(find.text('Bio & Demographics'), findsOneWidget);
      expect(find.text('Setup Wizard'), findsOneWidget);

      // Verify wrapped bio badges render cleanly
      expect(find.text('Blood: O+'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.text('ID: ID-99201-X'), findsOneWidget);
      expect(find.textContaining('yrs'), findsWidgets);
    });

    testWidgets('Profile Page collapsible Daily Routine expands and collapses properly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileNotifierProvider.overrideWith((ref) => FakeProfileNotifier()),
            medicationsNotifierProvider.overrideWith((ref) => MockMedicationsNotifier([])),
            themeNotifierProvider.overrideWith((ref) => FakeThemeNotifier()),
            fontScaleNotifierProvider.overrideWith((ref) => FakeFontScaleNotifier()),
            paletteNotifierProvider.overrideWith((ref) => FakePaletteNotifier()),
            notificationServiceProvider.overrideWithValue(FakeNotificationService()),
          ],
          child: const MaterialApp(
            home: ProfilePage(initiallyExpanded: true),
          ),
        ),
      );

      // Header is present
      expect(find.text('Daily Routine & Meal Times'), findsOneWidget);

      // Initially expanded (because initiallyExpanded: true)
      expect(find.text('Wake Up Time'), findsOneWidget);
      expect(find.text('Breakfast Time'), findsOneWidget);

      // Tap header to collapse
      await tester.tap(find.text('Daily Routine & Meal Times'));
      await tester.pumpAndSettle();

      // Expanded list is hidden, collapsed preview chips are shown
      expect(find.text('Wake Up Time'), findsNothing);
      expect(find.text('Wake: '), findsOneWidget);
      expect(find.text('Breakfast: '), findsOneWidget);

      // Tap header again to re-expand
      await tester.tap(find.text('Daily Routine & Meal Times'));
      await tester.pumpAndSettle();

      // Expanded time rows are visible again
      expect(find.text('Wake Up Time'), findsOneWidget);
    });

    testWidgets('Profile Page displays Chronic Conditions & Organ Risks outside the emergency card', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileNotifierProvider.overrideWith((ref) => FakeProfileWithConditionsNotifier()),
            medicationsNotifierProvider.overrideWith((ref) => MockMedicationsNotifier([])),
            themeNotifierProvider.overrideWith((ref) => FakeThemeNotifier()),
            fontScaleNotifierProvider.overrideWith((ref) => FakeFontScaleNotifier()),
            paletteNotifierProvider.overrideWith((ref) => FakePaletteNotifier()),
            notificationServiceProvider.overrideWithValue(FakeNotificationService()),
          ],
          child: const MaterialApp(
            home: ProfilePage(initiallyExpanded: true),
          ),
        ),
      );

      // Verify that Chronic Conditions badge is displayed in Bio Info Wrap outside the card
      expect(find.text('2 Conditions'), findsOneWidget);

      // Verify that the dedicated Chronic Conditions & Organ Risks section is displayed outside the card
      expect(find.text('Chronic Conditions & Organ Risks'), findsOneWidget);
      expect(find.text('2 active conditions recorded • Tap to view & edit'), findsOneWidget);

      // Verify collapsed preview chips for active conditions appear outside the card
      expect(find.text('Asthma'), findsOneWidget);
      expect(find.text('Hypertension'), findsOneWidget);

      // Tap header to expand Chronic Conditions section
      await tester.tap(find.text('Chronic Conditions & Organ Risks'));
      await tester.pumpAndSettle();

      // Verify expanded clinical taxonomy options appear
      expect(find.text('Select all active chronic medical conditions, organ risks, or clinical states:'), findsOneWidget);
      expect(find.text('Asthma (Airway)'), findsOneWidget);
      expect(find.text('Hypertension (High BP)'), findsOneWidget);
      expect(find.text('Diabetes (Type 1 or 2)'), findsOneWidget);
      expect(find.text('Heart Condition'), findsOneWidget);

      // Tap to toggle Diabetes
      await tester.tap(find.text('Diabetes (Type 1 or 2)'));
      await tester.pumpAndSettle();

      // Verify Diabetes is now selected and condition count updated
      expect(find.text('3 Conditions'), findsOneWidget);
    });

    testWidgets('Layout Robustness & Overflow Check on Narrow Viewports (320px)', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Test 1: ProfilePage on 320px
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileNotifierProvider.overrideWith((ref) => FakeProfileWithConditionsNotifier()),
            medicationsNotifierProvider.overrideWith((ref) => MockMedicationsNotifier([])),
            themeNotifierProvider.overrideWith((ref) => FakeThemeNotifier()),
            fontScaleNotifierProvider.overrideWith((ref) => FakeFontScaleNotifier()),
            paletteNotifierProvider.overrideWith((ref) => FakePaletteNotifier()),
            notificationServiceProvider.overrideWithValue(FakeNotificationService()),
          ],
          child: const MaterialApp(
            home: ProfilePage(initiallyExpanded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final err1 = tester.takeException();
      if (err1 != null) {
        debugPrint('PROFILE OVERFLOW ERROR: $err1');
      }
      expect(err1, isNull);

      // Test 2: HomePage on 320px
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileNotifierProvider.overrideWith((ref) => FakeProfileWithConditionsNotifier()),
            medicationsNotifierProvider.overrideWith((ref) => MockMedicationsNotifier([])),
            themeNotifierProvider.overrideWith((ref) => FakeThemeNotifier()),
            fontScaleNotifierProvider.overrideWith((ref) => FakeFontScaleNotifier()),
            paletteNotifierProvider.overrideWith((ref) => FakePaletteNotifier()),
            notificationServiceProvider.overrideWithValue(FakeNotificationService()),
          ],
          child: const MaterialApp(
            home: HomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final err2 = tester.takeException();
      if (err2 != null) {
        debugPrint('HOMEPAGE OVERFLOW ERROR: $err2');
      }
      expect(err2, isNull);

      // Test 3: RecordsPage on 320px
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileNotifierProvider.overrideWith((ref) => FakeProfileWithConditionsNotifier()),
            medicationsNotifierProvider.overrideWith((ref) => MockMedicationsNotifier([])),
            themeNotifierProvider.overrideWith((ref) => FakeThemeNotifier()),
            fontScaleNotifierProvider.overrideWith((ref) => FakeFontScaleNotifier()),
            paletteNotifierProvider.overrideWith((ref) => FakePaletteNotifier()),
            notificationServiceProvider.overrideWithValue(FakeNotificationService()),
          ],
          child: const MaterialApp(
            home: RecordsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final err3 = tester.takeException();
      if (err3 != null) {
        debugPrint('RECORDSPAGE OVERFLOW ERROR: $err3');
      }
      expect(err3, isNull);
    });

    testWidgets('SplashScreen renders only the logo in the center of the glowing circle with zero text', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paletteNotifierProvider.overrideWith((ref) => FakePaletteNotifier()),
            storageServiceProvider.overrideWithValue(FakeStorageService()),
          ],
          child: const MaterialApp(
            home: SplashScreen(),
          ),
        ),
      );

      // Verify that the healthcare logo icon is rendered
      expect(find.byIcon(Icons.health_and_safety_rounded), findsOneWidget);

      // Verify that NO text widgets ("MediSync" or subtitle) are rendered on the splash screen
      expect(find.text('MediSync'), findsNothing);
      expect(find.text('CLINICAL SAFETY & ROUTINE INTELLIGENCE'), findsNothing);

      // Verify the logo icon is inside a circular Container with BoxShadow glow
      final iconFinder = find.byIcon(Icons.health_and_safety_rounded);
      expect(iconFinder, findsOneWidget);

      final containerFinder = find.ancestor(
        of: iconFinder,
        matching: find.byType(Container),
      );
      expect(containerFinder, findsWidgets);

      final container = tester.widget<Container>(containerFinder.first);
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration, isNotNull);
      expect(decoration!.shape, equals(BoxShape.circle));
      expect(decoration.boxShadow, isNotEmpty);
      expect(decoration.boxShadow!.length, greaterThanOrEqualTo(2));
    });
  });
}
