import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:medisync/core/services/storage_service.dart';

const String kThemeBoxName = 'theme_settings_box';
const String kThemeModeKey = 'app_theme_mode';
const String kFontScaleKey = 'app_font_scale';
const String kPaletteKey = 'app_theme_palette';

enum AppPalette {
  emeraldTeal('Emerald & Teal', Color(0xFF0D9488), Color(0xFF0284C7)),
  oceanBlue('Ocean & Cyan', Color(0xFF0284C7), Color(0xFF0D9488)),
  royalIndigo('Royal Indigo', Color(0xFF6366F1), Color(0xFF8B5CF6)),
  amethystViolet('Amethyst & Lilac', Color(0xFF8B5CF6), Color(0xFF6366F1)),
  sunsetCoral('Sunset Coral', Color(0xFFEA580C), Color(0xFFF59E0B)),
  roseRuby('Rose & Ruby', Color(0xFFE11D48), Color(0xFFFB7185)),
  midnightSapphire('Midnight Sapphire', Color(0xFF1E3A8A), Color(0xFF3B82F6)),
  forestSage('Forest & Sage', Color(0xFF15803D), Color(0xFF65A30D)),
  crimsonAmber('Crimson & Amber', Color(0xFFB91C1C), Color(0xFFD97706)),
  nordicTitanium('Nordic Titanium', Color(0xFF475569), Color(0xFF64748B));

  final String label;
  final Color primary;
  final Color secondary;
  const AppPalette(this.label, this.primary, this.secondary);

  Color get darkPrimary {
    switch (this) {
      case AppPalette.emeraldTeal:
        return const Color(0xFF2DD4BF);
      case AppPalette.oceanBlue:
        return const Color(0xFF38BDF8);
      case AppPalette.royalIndigo:
        return const Color(0xFF818CF8);
      case AppPalette.amethystViolet:
        return const Color(0xFFA78BFA);
      case AppPalette.sunsetCoral:
        return const Color(0xFFFB923C);
      case AppPalette.roseRuby:
        return const Color(0xFFFB7185);
      case AppPalette.midnightSapphire:
        return const Color(0xFF60A5FA);
      case AppPalette.forestSage:
        return const Color(0xFF4ADE80);
      case AppPalette.crimsonAmber:
        return const Color(0xFFF87171);
      case AppPalette.nordicTitanium:
        return const Color(0xFF94A3B8);
    }
  }

  Color get darkSecondary {
    switch (this) {
      case AppPalette.emeraldTeal:
        return const Color(0xFF38BDF8);
      case AppPalette.oceanBlue:
        return const Color(0xFF2DD4BF);
      case AppPalette.royalIndigo:
        return const Color(0xFFA78BFA);
      case AppPalette.amethystViolet:
        return const Color(0xFF818CF8);
      case AppPalette.sunsetCoral:
        return const Color(0xFFFBBF24);
      case AppPalette.roseRuby:
        return const Color(0xFFFDA4AF);
      case AppPalette.midnightSapphire:
        return const Color(0xFF93C5FD);
      case AppPalette.forestSage:
        return const Color(0xFFA3E635);
      case AppPalette.crimsonAmber:
        return const Color(0xFFFBBF24);
      case AppPalette.nordicTitanium:
        return const Color(0xFFCBD5E1);
    }
  }
}

class AppTheme {
  // Brand Palette: Modern Healthcare Emerald, Trust Cyan, Comforting Indigo, and Rich Clinical Accents
  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color primaryTealLight = Color(0xFF2DD4BF);
  static const Color secondaryCyan = Color(0xFF0284C7);
  static const Color secondaryCyanLight = Color(0xFF38BDF8);
  static const Color accentIndigo = Color(0xFF6366F1);
  static const Color accentIndigoLight = Color(0xFF818CF8);
  static const Color accentViolet = Color(0xFF8B5CF6);
  static const Color accentVioletLight = Color(0xFFA78BFA);
  static const Color accentRose = Color(0xFFF43F5E);
  static const Color accentRoseLight = Color(0xFFFB7185);
  static const Color accentCoral = Color(0xFFEA580C);
  static const Color accentCoralLight = Color(0xFFFB923C);

  static const Color warningAmber = Color(0xFFD97706);
  static const Color warningAmberLight = Color(0xFFFBBF24);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color dangerRedLight = Color(0xFFF87171);
  static const Color successGreen = Color(0xFF16A34A);
  static const Color successGreenLight = Color(0xFF4ADE80);

  // Dynamic Helper Methods for clean, readable widgets
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color primaryColor(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color primaryContainer(BuildContext context) =>
      Theme.of(context).colorScheme.primaryContainer;

  static Color secondaryColor(BuildContext context) =>
      Theme.of(context).colorScheme.secondary;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? const Color(0xFF94A3B8) : const Color(0xFF475569);

  static Color textMuted(BuildContext context) =>
      isDark(context) ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  static Color cardColor(BuildContext context) =>
      isDark(context) ? const Color(0xFF151E2E) : Colors.white;

  static Color cardBorder(BuildContext context) =>
      isDark(context) ? const Color(0xFF243248) : const Color(0xFFE2E8F0);

  static Color surfaceVariant(BuildContext context) =>
      isDark(context) ? const Color(0xFF1C273C) : const Color(0xFFEBF1F2);

  static Color chipSelected(BuildContext context) =>
      Theme.of(context).colorScheme.primary.withValues(alpha: isDark(context) ? 0.25 : 0.15);

  // Shadows for Establishing Hierarchy and Field of Depth
  static List<BoxShadow> softShadow(BuildContext context) {
    return [
      BoxShadow(
        color: isDark(context)
            ? Colors.black.withValues(alpha: 0.3)
            : const Color(0xFF0F172A).withValues(alpha: 0.05),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ];
  }

  static List<BoxShadow> elevatedShadow(BuildContext context) {
    return [
      BoxShadow(
        color: isDark(context)
            ? Colors.black.withValues(alpha: 0.45)
            : const Color(0xFF0F172A).withValues(alpha: 0.08),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];
  }

  static List<BoxShadow> floatingShadow(BuildContext context) {
    return [
      BoxShadow(
        color: isDark(context)
            ? Colors.black.withValues(alpha: 0.65)
            : const Color(0xFF0F172A).withValues(alpha: 0.14),
        blurRadius: 26,
        offset: const Offset(0, 8),
        spreadRadius: 1,
      ),
    ];
  }

  static List<BoxShadow> glowShadow(Color color, {double opacity = 0.28}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ];
  }

  static List<BoxShadow> appBarGlowShadow(BuildContext context, {double opacity = 0.10}) {
    final primary = Theme.of(context).colorScheme.primary;
    return [
      BoxShadow(
        color: primary.withValues(alpha: opacity),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
      ...softShadow(context),
    ];
  }

  // Light Theme (Soothing clinical porcelain background)
  static ThemeData lightTheme([AppPalette palette = AppPalette.emeraldTeal]) {
    final primary = palette.primary;
    final secondary = palette.secondary;

    const textTheme = TextTheme(
      displayLarge: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 20),
      titleMedium: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 16),
      titleSmall: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w600, fontSize: 14),
      bodyLarge: TextStyle(color: Color(0xFF0F172A), fontSize: 16, height: 1.45),
      bodyMedium: TextStyle(color: Color(0xFF334155), fontSize: 14, height: 1.4),
      bodySmall: TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.35),
      labelLarge: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primary.withValues(alpha: 0.15),
        onPrimaryContainer: primary,
        secondary: secondary,
        onSecondary: Colors.white,
        secondaryContainer: secondary.withValues(alpha: 0.15),
        onSecondaryContainer: secondary,
        tertiary: accentIndigo,
        surface: Colors.white,
        onSurface: const Color(0xFF0F172A),
        onSurfaceVariant: const Color(0xFF475569),
        error: dangerRed,
        onError: Colors.white,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF4F7F6), // Warm soothing medical off-white
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        ),
        titleTextStyle: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        hourMinuteTextStyle: const TextStyle(fontSize: 46, fontWeight: FontWeight.bold),
        dayPeriodTextStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        dialTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        dialBackgroundColor: const Color(0xFFF1F5F9),
        hourMinuteColor: const Color(0xFFE0F2FE),
        hourMinuteTextColor: const Color(0xFF0369A1),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 3,
        indicatorColor: primary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(color: primary, fontWeight: FontWeight.w700, fontSize: 12);
          }
          return const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500, fontSize: 12);
        }),
      ),
    );
  }

  // Dark Theme (Deep obsidian slate, optimal for eye-care)
  static ThemeData darkTheme([AppPalette palette = AppPalette.emeraldTeal]) {
    final primary = palette.darkPrimary;
    final secondary = palette.darkSecondary;

    const textTheme = TextTheme(
      displayLarge: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.w700, fontSize: 20),
      titleMedium: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.w600, fontSize: 16),
      titleSmall: TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.w600, fontSize: 14),
      bodyLarge: TextStyle(color: Color(0xFFF8FAFC), fontSize: 16, height: 1.45),
      bodyMedium: TextStyle(color: Color(0xFFCBD5E1), fontSize: 14, height: 1.4),
      bodySmall: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.35),
      labelLarge: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        onPrimary: const Color(0xFF042F2E),
        primaryContainer: primary.withValues(alpha: 0.25),
        onPrimaryContainer: primary,
        secondary: secondary,
        onSecondary: const Color(0xFF082F49),
        secondaryContainer: secondary.withValues(alpha: 0.2),
        onSecondaryContainer: secondary,
        tertiary: accentIndigoLight,
        surface: const Color(0xFF151E2E),
        onSurface: const Color(0xFFF8FAFC),
        onSurfaceVariant: const Color(0xFFCBD5E1),
        error: dangerRedLight,
        onError: const Color(0xFF450A0A),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF090E17), // Rich obsidian slate
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF151E2E),
        foregroundColor: Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        ),
        titleTextStyle: TextStyle(
          color: Color(0xFFF8FAFC),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF151E2E),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF243248), width: 1),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        hourMinuteTextStyle: const TextStyle(fontSize: 46, fontWeight: FontWeight.bold),
        dayPeriodTextStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        dialTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        dialBackgroundColor: const Color(0xFF0F172A),
        hourMinuteColor: primary.withValues(alpha: 0.2),
        hourMinuteTextColor: primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF151E2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF243248)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF243248)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: const Color(0xFF042F2E),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF151E2E),
        elevation: 4,
        indicatorColor: primary.withValues(alpha: 0.25),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(color: primary, fontWeight: FontWeight.w700, fontSize: 12);
          }
          return const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500, fontSize: 12);
        }),
      ),
    );
  }
}

// Theme Notifier
class ThemeNotifier extends StateNotifier<ThemeMode> {
  final Box _settingsBox;

  ThemeNotifier(this._settingsBox) : super(_loadInitialTheme(_settingsBox));

  static ThemeMode _loadInitialTheme(Box box) {
    final raw = box.get(kThemeModeKey, defaultValue: 'system');
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    _settingsBox.put(kThemeModeKey, mode.name);
  }

  void toggleTheme() {
    if (state == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }
}

final themeNotifierProvider =
    StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final box = Hive.box(kSettingsBoxName);
  return ThemeNotifier(box);
});

// Font Scaling Accessibility Notifier
class FontScaleNotifier extends StateNotifier<double> {
  final Box _settingsBox;

  FontScaleNotifier(this._settingsBox) : super(_loadInitialScale(_settingsBox));

  static double _loadInitialScale(Box box) {
    final raw = box.get(kFontScaleKey, defaultValue: 1.0);
    if (raw is num) return raw.toDouble();
    return 1.0;
  }

  void setFontScale(double scale) {
    final clamped = scale.clamp(0.85, 1.45);
    state = clamped;
    _settingsBox.put(kFontScaleKey, clamped);
  }
}

final fontScaleNotifierProvider =
    StateNotifierProvider<FontScaleNotifier, double>((ref) {
  final box = Hive.box(kSettingsBoxName);
  return FontScaleNotifier(box);
});

// Palette Notifier
class PaletteNotifier extends StateNotifier<AppPalette> {
  final Box _settingsBox;

  PaletteNotifier(this._settingsBox) : super(_loadInitialPalette(_settingsBox));

  static AppPalette _loadInitialPalette(Box box) {
    final raw = box.get(kPaletteKey, defaultValue: AppPalette.emeraldTeal.name);
    return AppPalette.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AppPalette.emeraldTeal,
    );
  }

  void setPalette(AppPalette palette) {
    state = palette;
    _settingsBox.put(kPaletteKey, palette.name);
  }
}

final paletteNotifierProvider =
    StateNotifierProvider<PaletteNotifier, AppPalette>((ref) {
  final box = Hive.box(kSettingsBoxName);
  return PaletteNotifier(box);
});
