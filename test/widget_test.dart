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
  Future<void> toggleDoseTaken(String medId, DateTime date, String time) async {}
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

    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Dose Timeline'), findsOneWidget);
    expect(find.text('Metformin'), findsWidgets);
  });

  testWidgets('Renders Medications List page with medication card',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
          home: ProfilePage(),
        ),
      ),
    );

    expect(find.text('Profile & Routine'), findsOneWidget);
    expect(find.text('Appearance & Theme'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    // Scroll down to reveal allergies
    await tester.scrollUntilVisible(
      find.text('Allergies & Excipient Sensitivities'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Allergies & Excipient Sensitivities'), findsOneWidget);
    expect(find.text('Penicillin'), findsWidgets);
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
}
