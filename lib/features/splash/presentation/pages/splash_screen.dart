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
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

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
    final palette = ref.watch(paletteNotifierProvider);
    final primary = isDark ? palette.darkPrimary : palette.primary;
    final secondary = isDark ? palette.darkSecondary : palette.secondary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090E17) : const Color(0xFFF4F7F6),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final pulse = _pulseAnimation.value;
          final expand = _expandAnimation.value;
          final isExpanding = _controller.value >= 0.65;
          final fadeOut = (1.0 - (_controller.value / 0.65)).clamp(0.0, 1.0);

          return Stack(
            alignment: Alignment.center,
            children: [
              // Concentric ripple glow rings
              if (!isExpanding) ...[
                Transform.scale(
                  scale: pulse * 1.40,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary.withValues(alpha: 0.10 * fadeOut),
                    ),
                  ),
                ),
                Transform.scale(
                  scale: pulse * 1.20,
                  child: Container(
                    width: 115,
                    height: 115,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary.withValues(alpha: 0.18 * fadeOut),
                    ),
                  ),
                ),
              ],

              // Glowing Circle with Centered Logo Icon
              Center(
                child: Transform.scale(
                  scale: pulse * expand,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [primary, secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        // Intense inner core glow
                        BoxShadow(
                          color: primary.withValues(alpha: isDark ? 0.65 : 0.45),
                          blurRadius: 36,
                          spreadRadius: 4,
                        ),
                        // Outer soft ambient glow aura
                        BoxShadow(
                          color: secondary.withValues(alpha: isDark ? 0.40 : 0.28),
                          blurRadius: 64,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Opacity(
                        opacity: isExpanding ? fadeOut : 1.0,
                        child: const Icon(
                          Icons.health_and_safety_rounded,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
