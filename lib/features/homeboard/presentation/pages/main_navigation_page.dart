import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medisync/core/theme/app_theme.dart';
import 'package:medisync/features/homeboard/presentation/pages/home_page.dart';
import 'package:medisync/features/medications/presentation/pages/medications_list_page.dart';
import 'package:medisync/features/profile/presentation/pages/profile_page.dart';
import 'package:medisync/features/records/presentation/pages/records_page.dart';

final mainNavIndexProvider = StateProvider<int>((ref) => 0);

class MainNavigationPage extends ConsumerStatefulWidget {
  const MainNavigationPage({super.key});

  @override
  ConsumerState<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends ConsumerState<MainNavigationPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    MedicationsListPage(),
    RecordsPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final activeColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Indexed Pages
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),

          // Scroll depth cue: subtle ambient gradient hinting that content flows under the floating bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 105,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      (isDark ? const Color(0xFF090E17) : const Color(0xFFF4F7F6))
                          .withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 68,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xF2151E2E) : const Color(0xF9FFFFFF),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF243248).withValues(alpha: 0.9)
                  : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              // 360-degree surrounding ambient glow aura
              BoxShadow(
                color: activeColor.withValues(alpha: isDark ? 0.32 : 0.20),
                blurRadius: 28,
                spreadRadius: 2.5,
                offset: Offset.zero,
              ),
              BoxShadow(
                color: (isDark ? activeColor : const Color(0xFF0F172A))
                    .withValues(alpha: isDark ? 0.22 : 0.10),
                blurRadius: 14,
                spreadRadius: 1,
                offset: Offset.zero,
              ),
              // Floating downward elevation shadow
              ...AppTheme.floatingShadow(context),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.calendar_today_outlined,
                selectedIcon: Icons.calendar_today_rounded,
                label: 'Today',
                activeColor: activeColor,
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.medication_outlined,
                selectedIcon: Icons.medication_rounded,
                label: 'Meds',
                activeColor: activeColor,
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.assignment_outlined,
                selectedIcon: Icons.assignment_turned_in_rounded,
                label: 'Records',
                activeColor: activeColor,
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                label: 'Profile',
                activeColor: activeColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required Color activeColor,
  }) {
    final isSelected = _currentIndex == index;
    final isDark = AppTheme.isDark(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
        ref.read(mainNavIndexProvider.notifier).state = index;
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 12 : 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? activeColor.withValues(alpha: 0.2)
                  : activeColor.withValues(alpha: 0.14))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: isSelected
              ? Border.all(
                  color: activeColor.withValues(alpha: 0.35),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              size: 21,
              color: isSelected
                  ? activeColor
                  : AppTheme.textSecondary(context),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: activeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
