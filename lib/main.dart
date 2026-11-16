import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medisync/core/services/notification_service.dart';
import 'package:medisync/core/services/storage_service.dart';
import 'package:medisync/core/theme/app_theme.dart';
import 'package:medisync/features/homeboard/presentation/pages/main_navigation_page.dart';
import 'package:medisync/features/onboarding/presentation/pages/onboarding_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();
  await storageService.seedInitialDataIfEmpty();

  final notificationService = NotificationService();
  await notificationService.init();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const MediSyncApp(),
    ),
  );
}

class MediSyncApp extends ConsumerWidget {
  const MediSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeNotifierProvider);
    final storage = ref.watch(storageServiceProvider);
    final isSetupCompleted = storage.isSetupCompleted();

    return MaterialApp(
      title: 'MediSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: isSetupCompleted
          ? const MainNavigationPage()
          : const OnboardingPage(),
    );
  }
}
