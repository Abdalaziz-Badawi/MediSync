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
              // Concentric ripple rings
              if (!isExpanding) ...[
                Transform.scale(
                  scale: pulse * 1.35,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary.withValues(alpha: 0.08 * fadeOut),
                    ),
                  ),
                ),
                Transform.scale(
                  scale: pulse * 1.18,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary.withValues(alpha: 0.14 * fadeOut),
                    ),
                  ),
                ),
              ],

              // Expanding transition circle
              Center(
                child: Transform.scale(
                  scale: pulse * expand,
                  child: Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [primary, secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.38),
                          blurRadius: 30,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Foreground Emblem & Brand Typography (visible before expansion)
              if (!isExpanding)
                Center(
                  child: Opacity(
                    opacity: fadeOut,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Healthcare Cross & Pulse Badge
                        Container(
                          width: 86,
                          height: 86,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.health_and_safety_rounded,
                              color: Colors.white,
                              size: 46,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'MediSync',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.4,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: isDark ? 0.20 : 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            'CLINICAL SAFETY & ROUTINE INTELLIGENCE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: primary,
                            ),
                          ),
                        ),
                      ],
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
