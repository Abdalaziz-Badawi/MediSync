import 'package:flutter/material.dart';
import 'package:medisync/core/theme/app_theme.dart';
import 'package:medisync/features/homeboard/presentation/pages/home_page.dart';
import 'package:medisync/features/medications/presentation/pages/medications_list_page.dart';
import 'package:medisync/features/profile/presentation/pages/profile_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    MedicationsListPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final activeColor = isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 68,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xF21E293B) : const Color(0xF9FFFFFF),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF334155).withValues(alpha: 0.9)
                  : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: AppTheme.floatingShadow(context),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.today_outlined,
                selectedIcon: Icons.today,
                label: 'Today',
                activeColor: activeColor,
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.medication_outlined,
                selectedIcon: Icons.medication,
                label: 'Medications',
                activeColor: activeColor,
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
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
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
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
              size: 22,
              color: isSelected
                  ? activeColor
                  : AppTheme.textSecondary(context),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: activeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
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
