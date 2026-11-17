import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medisync/core/models/user_profile.dart';
import 'package:medisync/core/services/notification_service.dart';
import 'package:medisync/core/services/storage_service.dart';
import 'package:medisync/core/theme/app_theme.dart';
import 'package:medisync/features/homeboard/presentation/pages/main_navigation_page.dart';
import 'package:medisync/features/profile/presentation/widgets/allergy_selector_widget.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Form state
  final TextEditingController _nameController =
      TextEditingController(text: 'Abdalaziz');

  final List<String> _selectedAllergies = ['Penicillin'];
  String _wakeTime = '07:30';
  String _breakfastTime = '08:30';
  String _lunchTime = '13:30';
  String _dinnerTime = '20:00';
  String _sleepTime = '23:00';

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({
    required String currentTime,
    required Function(String) onPicked,
  }) async {
    final parts = currentTime.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );

    final result = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (result != null) {
      final formatted =
          '${result.hour.toString().padLeft(2, '0')}:${result.minute.toString().padLeft(2, '0')}';
      setState(() {
        onPicked(formatted);
      });
    }
  }

  void _finishSetup() async {
    final profile = UserProfile(
      name: _nameController.text.trim().isEmpty
          ? 'User'
          : _nameController.text.trim(),
      allergies: _selectedAllergies,
      wakeTime: _wakeTime,
      breakfastTime: _breakfastTime,
      lunchTime: _lunchTime,
      dinnerTime: _dinnerTime,
      sleepTime: _sleepTime,
    );

    await ref.read(profileNotifierProvider.notifier).updateProfile(profile);
    await ref.read(storageServiceProvider).setSetupCompleted(true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationPage()),
      );
    }
  }

  void _nextStep() {
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishSetup();
    }
  }

  void _toggleAllergy(String allergy) {
    setState(() {
      if (_selectedAllergies.contains(allergy)) {
        _selectedAllergies.remove(allergy);
      } else {
        _selectedAllergies.add(allergy);
      }
    });
  }

  void _addCustomAllergy(String custom) {
    final trimmed = custom.trim();
    if (trimmed.isNotEmpty && !_selectedAllergies.contains(trimmed)) {
      setState(() {
        _selectedAllergies.add(trimmed);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: List.generate(4, (index) {
                  return Expanded(
                    child: Container(
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: index <= _currentStep
                            ? (isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal)
                            : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Step Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentStep = i),
                children: [
                  _buildWelcomeStep(),
                  _buildAllergiesStep(),
                  _buildRoutineStep(),
                  _buildNotificationsStep(),
                ],
              ),
            ),

            // Bottom Navigation Buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentStep > 0) ...[
                    OutlinedButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _nextStep,
                      child: Text(
                        _currentStep == 3
                            ? 'Complete Setup & Open App'
                            : 'Continue',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeStep() {
    final isDark = AppTheme.isDark(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF134E4A) : const Color(0xFFE0F2F1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.medication_rounded,
              color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Welcome to MediSync',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your smart, privacy-first medication organizer. Let’s configure your profile so the app can study your routine and schedule your doses safely.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary(context), height: 1.4),
        ),
        const SizedBox(height: 32),
        Card(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '100% Offline & Private: No accounts required. All health data is encrypted and saved strictly on your local device.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Your Name *',
            hintText: 'Enter your name or preferred nickname',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
      ],
    );
  }

  Widget _buildAllergiesStep() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      children: [
        const SizedBox(height: 10),
        Text(
          'Known Drug & Excipient Allergies',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Cross-reference your profile against active pharmaceuticals, food excipients (lactose, peanut/sesame oil), inactive additives (gelatin, sulfites), and materials (latex).',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context), height: 1.4),
        ),
        const SizedBox(height: 20),
        AllergySelectorWidget(
          selectedAllergies: _selectedAllergies,
          onToggleAllergy: _toggleAllergy,
          onAddCustomAllergy: _addCustomAllergy,
        ),
      ],
    );
  }

  Widget _buildRoutineStep() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      children: [
        const SizedBox(height: 10),
        Text(
          'Your Daily Routine',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'The smart scheduling engine uses these hours to place morning medicines, mealtime doses, and bedtime sleep medicines at biologically studied intervals.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context), height: 1.4),
        ),
        const SizedBox(height: 20),
        _buildRoutinePickerRow(
          icon: Icons.wb_sunny_outlined,
          label: 'Wake Up Time',
          time: _wakeTime,
          onTap: () => _pickTime(
            currentTime: _wakeTime,
            onPicked: (t) => _wakeTime = t,
          ),
        ),
        const Divider(height: 16),
        _buildRoutinePickerRow(
          icon: Icons.breakfast_dining_outlined,
          label: 'Breakfast Time',
          time: _breakfastTime,
          onTap: () => _pickTime(
            currentTime: _breakfastTime,
            onPicked: (t) => _breakfastTime = t,
          ),
        ),
        const Divider(height: 16),
        _buildRoutinePickerRow(
          icon: Icons.lunch_dining_outlined,
          label: 'Lunch Time',
          time: _lunchTime,
          onTap: () => _pickTime(
            currentTime: _lunchTime,
            onPicked: (t) => _lunchTime = t,
          ),
        ),
        const Divider(height: 16),
        _buildRoutinePickerRow(
          icon: Icons.dinner_dining_outlined,
          label: 'Dinner Time',
          time: _dinnerTime,
          onTap: () => _pickTime(
            currentTime: _dinnerTime,
            onPicked: (t) => _dinnerTime = t,
          ),
        ),
        const Divider(height: 16),
        _buildRoutinePickerRow(
          icon: Icons.bedtime_outlined,
          label: 'Bedtime / Sleep',
          time: _sleepTime,
          onTap: () => _pickTime(
            currentTime: _sleepTime,
            onPicked: (t) => _sleepTime = t,
          ),
        ),
      ],
    );
  }

  Widget _buildRoutinePickerRow({
    required IconData icon,
    required String label,
    required String time,
    required VoidCallback onTap,
  }) {
    final isDark = AppTheme.isDark(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.primaryTealLight.withValues(alpha: 0.18)
                    : const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                time,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsStep() {
    final isDark = AppTheme.isDark(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      children: [
        const SizedBox(height: 10),
        Text(
          'Notifications & Reminders',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'MediSync sends high-priority alerts with sound and vibration right on schedule, including pre-medication conditions (e.g. "Eat food first").',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context), height: 1.4),
        ),
        const SizedBox(height: 30),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  size: 56,
                  color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                ),
                const SizedBox(height: 16),
                Text(
                  'Verify Notifications on Device',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the button below to trigger an immediate test notification with sound on your phone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context)),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(notificationServiceProvider)
                        .showTestNotification();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                              '🔔 Notification sent! Check your phone status bar.'),
                          backgroundColor: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Send Test Alarm to Phone'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                    foregroundColor: isDark ? const Color(0xFF042F2E) : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
