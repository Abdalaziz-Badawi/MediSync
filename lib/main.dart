import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medisync/core/services/notification_service.dart';
import 'package:medisync/core/services/storage_service.dart';
import 'package:medisync/core/theme/app_theme.dart';
import 'package:medisync/features/splash/presentation/pages/splash_screen.dart';

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

  // Synchronize all existing active medication alarms in background without blocking UI startup
  try {
    final existingMedications = storageService.getMedications();
    await notificationService.syncAllMedicationReminders(existingMedications);
  } catch (e, stack) {
    debugPrint('Background alarm synchronization notice: $e\n$stack');
  }
}

class MediSyncApp extends ConsumerWidget {
  const MediSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeNotifierProvider);
    final fontScale = ref.watch(fontScaleNotifierProvider);
    final palette = ref.watch(paletteNotifierProvider);

    return MaterialApp(
      title: 'MediSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(palette),
      darkTheme: AppTheme.darkTheme(palette),
      themeMode: themeMode,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(fontScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashScreen(),
    );
  }
}
