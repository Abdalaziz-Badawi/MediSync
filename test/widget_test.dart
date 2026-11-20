import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medisync/core/models/condition.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/models/side_effect.dart';
import 'package:medisync/core/models/user_profile.dart';
import 'package:medisync/core/services/notification_service.dart';
import 'package:medisync/core/services/storage_service.dart';
import 'package:medisync/core/theme/app_theme.dart';
import 'package:medisync/features/homeboard/presentation/pages/home_page.dart';
import 'package:medisync/features/homeboard/presentation/widgets/next_dose_countdown_card.dart';
import 'package:medisync/features/medications/presentation/pages/medications_list_page.dart';
import 'package:medisync/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:medisync/features/profile/presentation/pages/profile_page.dart';

// Test mock notifier for profile
class FakeProfileNotifier extends StateNotifier<UserProfile>
    implements ProfileNotifier {
  FakeProfileNotifier()
      : super(
          const UserProfile(
            name: 'Sarah Connor',
            allergies: ['Penicillin'],
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

// Test mock notifier for medications
class FakeMedicationsNotifier extends StateNotifier<List<Medication>>
    implements MedicationsNotifier {
  FakeMedicationsNotifier()
      : super([
          Medication(
            id: 'test-1',
            name: 'Metformin',
            dosage: '500 mg',
            timesPerDay: 1,
            scheduledTimes: ['23:59'],
            startDate: DateTime.now(),
            preConditions: const [
              MedicationCondition(
                type: ConditionType.meal,
                timing: ConditionTiming.before,
                description: 'Take with food to prevent upset stomach',
              ),
            ],
            sideEffects: const [
              SideEffect(
                type: SideEffectType.stomachUpset,
                description: 'Stomach irritation',
                scheduleHint: ScheduleHint.scheduleAfterMeal,
              ),
            ],
          ),
        ]);

  @override
  Future<void> addOrUpdate(Medication med) async {
    state = [...state, med];
  }

  @override
  Future<void> remove(String id) async {
    state = state.where((m) => m.id != id).toList();
  }

  @override
  Future<void> discontinue(String id, {DateTime? date, String? reason}) async {
    state = state.map((m) {
      if (m.id == id) {
        return m.copyWith(
          discontinuedDate: date ?? DateTime.now(),
          discontinuationReason: reason ?? 'Discontinued',
        );
      }
      return m;
    }).toList();
  }

  @override
  Future<void> resume(String id) async {
    state = state.map((m) {
      if (m.id == id) {
        return m.copyWith(
          discontinuedDate: null,
          discontinuationReason: null,
        );
      }
      return m;
    }).toList();
  }

  @override
  Future<void> toggleDoseTaken(String medId, DateTime date, String time) async {}

  @override
  Future<void> setDoseStatus(
    String medId,
    DateTime date,
    String time,
    DoseStatus status,
  ) async {}
}

// Test mock notifier for Theme
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

// Test mock notifier for FontScale
class FakeFontScaleNotifier extends StateNotifier<double>
    implements FontScaleNotifier {
  FakeFontScaleNotifier() : super(1.0);

  @override
  void setFontScale(double scale) {
    state = scale;
  }
}

// Test mock notifier for Palette
class FakePaletteNotifier extends StateNotifier<AppPalette>
    implements PaletteNotifier {
  FakePaletteNotifier() : super(AppPalette.emeraldTeal);

  @override
  void setPalette(AppPalette palette) {
    state = palette;
  }
}

// Test mock NotificationService
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

void main() {
  testWidgets('Renders Home Dashboard with user name, countdown card, and medication dose',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileNotifierProvider
              .overrideWith((ref) => FakeProfileNotifier()),
          medicationsNotifierProvider
              .overrideWith((ref) => FakeMedicationsNotifier()),
          themeNotifierProvider
              .overrideWith((ref) => FakeThemeNotifier()),
        ],
        child: const MaterialApp(
          home: HomePage(),
        ),
      ),
    );

    expect(find.text('Hello, Sarah'), findsOneWidget);
    expect(find.byType(NextDoseCountdownCard), findsOneWidget);
    expect(find.text('NEXT MEDICATION'), findsOneWidget);
    expect(find.text('BEFORE'), findsOneWidget);
    expect(find.text('Take'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Dose Timeline'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Dose Timeline'), findsOneWidget);
    expect(find.text('Metformin'), findsWidgets);
  });

  testWidgets('Renders Medications List page with medication card',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileNotifierProvider
              .overrideWith((ref) => FakeProfileNotifier()),
          medicationsNotifierProvider
              .overrideWith((ref) => FakeMedicationsNotifier()),
        ],
        child: const MaterialApp(
          home: MedicationsListPage(),
        ),
      ),
    );

    expect(find.text('My Medications'), findsOneWidget);
    expect(find.text('Metformin'), findsOneWidget);
    expect(find.text('Add Medicine'), findsOneWidget);
  });

  testWidgets('Renders Profile page with theme toggle, routine and allergies',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileNotifierProvider
              .overrideWith((ref) => FakeProfileNotifier()),
          medicationsNotifierProvider
              .overrideWith((ref) => FakeMedicationsNotifier()),
          themeNotifierProvider
              .overrideWith((ref) => FakeThemeNotifier()),
          fontScaleNotifierProvider
              .overrideWith((ref) => FakeFontScaleNotifier()),
          paletteNotifierProvider
              .overrideWith((ref) => FakePaletteNotifier()),
          notificationServiceProvider
              .overrideWithValue(FakeNotificationService()),
        ],
        child: const MaterialApp(
          home: ProfilePage(initiallyExpanded: true),
        ),
      ),
    );

    expect(find.text('Profile & Routine'), findsOneWidget);
    expect(find.text('Daily Routine & Meal Times'), findsOneWidget);
    expect(find.text('Wake Up Time'), findsOneWidget);
    expect(find.text('Penicillin'), findsWidgets);

    // Scroll down to reveal Settings & Preferences
    await tester.scrollUntilVisible(
      find.text('Appearance & Theme'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Appearance & Theme'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('Renders Onboarding Setup Wizard with welcome step',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileNotifierProvider
              .overrideWith((ref) => FakeProfileNotifier()),
          notificationServiceProvider
              .overrideWithValue(FakeNotificationService()),
        ],
        child: const MaterialApp(
          home: OnboardingPage(),
        ),
      ),
    );

    expect(find.text('Welcome to MediSync'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Your Name *'), findsOneWidget);
  });

  testWidgets(
      'Medications List supports selection mode, select all, and batch delete',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileNotifierProvider
              .overrideWith((ref) => FakeProfileNotifier()),
          medicationsNotifierProvider
              .overrideWith((ref) => FakeMedicationsNotifier()),
        ],
        child: const MaterialApp(
          home: MedicationsListPage(),
        ),
      ),
    );

    expect(find.text('My Medications'), findsOneWidget);
    expect(find.text('Metformin'), findsOneWidget);

    // Enter selection mode via checklist icon
    final selectBtn = find.byIcon(Icons.checklist_rounded);
    expect(selectBtn, findsOneWidget);
    await tester.tap(selectBtn);
    await tester.pumpAndSettle();

    expect(find.text('0 Selected'), findsOneWidget);
    expect(find.text('Select All'), findsOneWidget);
    expect(find.text('Select None'), findsOneWidget);

    // Select All
    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();

    expect(find.text('1 Selected'), findsOneWidget);
    expect(find.text('Delete (1)'), findsOneWidget);

    // Select None
    await tester.tap(find.text('Select None'));
    await tester.pumpAndSettle();

    expect(find.text('0 Selected'), findsOneWidget);
  });

  testWidgets(
      'NextDoseCountdownCard renders "Today We\'re Done!" and tomorrow summary when today is complete',
      (WidgetTester tester) async {
    final now = DateTime.now();
    final todayStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final yyyymmdd =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final med = Medication(
      id: 'done-med-1',
      name: 'Amoxicillin',
      dosage: '250mg',
      timesPerDay: 1,
      scheduledTimes: [todayStr],
      startDate: now.subtract(const Duration(days: 2)),
      preConditions: const [],
      sideEffects: const [],
      doseLog: {
        yyyymmdd: ['$todayStr:taken'],
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NextDoseCountdownCard(
            medications: [med],
            onMarkTaken: (medId, time, date) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Today We're Done!"), findsOneWidget);
    expect(find.text("TOMORROW'S SCHEDULE SUMMARY"), findsOneWidget);
  });

  testWidgets('Date selection locking locks timeline actions on non-today dates',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileNotifierProvider.overrideWith((ref) => FakeProfileNotifier()),
          medicationsNotifierProvider
              .overrideWith((ref) => FakeMedicationsNotifier()),
        ],
        child: const MaterialApp(
          home: HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Default is today - verify no locked message is present
    expect(find.byIcon(Icons.lock_clock_rounded), findsNothing);

    // Tap on the next day's date chip in the horizontal calendar strip
    final futureDayFinder = find.byType(InkWell);
    if (futureDayFinder.evaluate().isNotEmpty) {
      // Find a day chip that has text of future day
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowDayNumber = tomorrow.day.toString();
      final tomorrowChip = find.text(tomorrowDayNumber);
      if (tomorrowChip.evaluate().isNotEmpty) {
        await tester.tap(tomorrowChip.first);
        await tester.pumpAndSettle();

        // Lock icon and notice should now be visible
        await tester.scrollUntilVisible(
          find.byIcon(Icons.lock_clock_rounded),
          500,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byIcon(Icons.lock_clock_rounded), findsOneWidget);
        expect(find.textContaining('locked and cannot be logged ahead of time.'), findsOneWidget);
      }
    }
  });
}
