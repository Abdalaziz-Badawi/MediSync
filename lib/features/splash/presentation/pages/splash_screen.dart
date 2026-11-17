import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medisync/core/services/storage_service.dart';
import 'package:medisync/core/theme/app_theme.dart';
import 'package:medisync/features/homeboard/presentation/pages/main_navigation_page.dart';
import 'package:medisync/features/onboarding/presentation/pages/onboarding_page.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<Color?> _colorAnimation;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    final palette = ref.read(paletteNotifierProvider);

    // Phase 1: Subtle breathing pulse (0.0 to 0.6 of duration)
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.7, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 40,
      ),
    ]).animate(_controller);

    // Theme Palette Color Shift matching Today page & active palette
    _colorAnimation = TweenSequence<Color?>([
      TweenSequenceItem(
        tween: ColorTween(
          begin: palette.primary,
          end: palette.secondary,
        ),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: ColorTween(
          begin: palette.secondary,
          end: palette.primary,
        ),
        weight: 40,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.65, curve: Curves.easeInOut),
    ));

    // Phase 2: Expanding circle to cover the screen (0.65 to 1.0)
    _expandAnimation = Tween<double>(begin: 1.0, end: 32.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.65, 1.0, curve: Curves.easeInOutCubic),
      ),
    );

    _controller.forward().then((_) => _navigateToNextScreen());
  }

  void _navigateToNextScreen() {
    if (!mounted) return;
    final storage = ref.read(storageServiceProvider);
    final isSetupCompleted = storage.isSetupCompleted();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (context, animation, secondaryAnimation) => isSetupCompleted
            ? const MainNavigationPage()
            : const OnboardingPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090E17) : const Color(0xFFF4F7F6),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final circleColor = _colorAnimation.value ?? AppTheme.primaryTeal;
          final pulse = _pulseAnimation.value;
          final expand = _expandAnimation.value;
          final totalScale = pulse * expand;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Minimal expanding circle
              Center(
                child: Transform.scale(
                  scale: totalScale,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: circleColor,
                      boxShadow: [
                        BoxShadow(
                          color: circleColor.withValues(alpha: 0.35),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Foreground App Icon & Title (visible before expansion)
              if (_controller.value < 0.7) ...[
                Center(
                  child: Opacity(
                    opacity: (1.0 - (_controller.value / 0.7)).clamp(0.0, 1.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.medication_liquid_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'MediSync',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Clinical Safety & Smart Routine',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
