import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medisync/core/models/user_profile.dart';
import 'package:medisync/core/services/notification_service.dart';
import 'package:medisync/core/services/storage_service.dart';
import 'package:medisync/core/theme/app_theme.dart';
import 'package:medisync/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:medisync/features/profile/presentation/widgets/allergy_selector_widget.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late TextEditingController _nameController;

  late String _wakeTime;
  late String _sleepTime;
  late String _breakfastTime;
  late String _lunchTime;
  late String _dinnerTime;
  late bool _useHealthApp;
  late List<String> _allergies;

  // Privacy Shield / Sneak Peek Prevention
  bool _isPrivacyMaskActive = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileNotifierProvider);
    _nameController = TextEditingController(text: profile.name);

    _wakeTime = profile.wakeTime;
    _sleepTime = profile.sleepTime;
    _breakfastTime = profile.breakfastTime;
    _lunchTime = profile.lunchTime;
    _dinnerTime = profile.dinnerTime;
    _useHealthApp = profile.useHealthApp;
    _allergies = List.from(profile.allergies);
  }

  @override
  void dispose() {
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              hourMinuteTextStyle: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              dayPeriodTextStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              dialTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
          ),
          child: AnimatedScale(
            scale: 1.12, // Substantially enlarges the clock widget & dial
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );

    if (result != null) {
      final formatted =
          '${result.hour.toString().padLeft(2, '0')}:${result.minute.toString().padLeft(2, '0')}';
      setState(() {
        onPicked(formatted);
      });
    }
  }

  void _toggleAllergy(String allergy) {
    setState(() {
      if (_allergies.contains(allergy)) {
        _allergies.remove(allergy);
      } else {
        _allergies.add(allergy);
      }
    });
  }

  void _addCustomAllergy(String custom) {
    final trimmed = custom.trim();
    if (trimmed.isNotEmpty && !_allergies.contains(trimmed)) {
      setState(() {
        _allergies.add(trimmed);
      });
    }
  }

  void _saveProfile() {
    final updated = UserProfile(
      name: _nameController.text.trim().isEmpty
          ? 'User'
          : _nameController.text.trim(),
      allergies: _allergies,
      wakeTime: _wakeTime,
      sleepTime: _sleepTime,
      breakfastTime: _breakfastTime,
      lunchTime: _lunchTime,
      dinnerTime: _dinnerTime,
      useHealthApp: _useHealthApp,
    );

    ref.read(profileNotifierProvider.notifier).updateProfile(updated);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Profile and daily routine saved locally!'),
        backgroundColor: AppTheme.isDark(context) ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
      ),
    );
  }

  String _maskText(String text) {
    if (!_isPrivacyMaskActive) return text;
    if (text.isEmpty) return '••••••';
    return '${text[0]}${'•' * (text.length - 1).clamp(4, 10)}';
  }

  @override
  Widget build(BuildContext context) {
    final currentThemeMode = ref.watch(themeNotifierProvider);
    final fontScale = ref.watch(fontScaleNotifierProvider);
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile & Routine',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary(context),
          ),
        ),
        actions: [
          // Sneak Peek Privacy Toggle in AppBar
          IconButton(
            tooltip: _isPrivacyMaskActive ? 'Disable Privacy Mask' : 'Enable Privacy Mask',
            icon: Icon(
              _isPrivacyMaskActive ? Icons.visibility_off : Icons.visibility,
              color: _isPrivacyMaskActive
                  ? (isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber)
                  : AppTheme.textSecondary(context),
            ),
            onPressed: () {
              setState(() {
                _isPrivacyMaskActive = !_isPrivacyMaskActive;
              });
            },
          ),
          TextButton(
            onPressed: _saveProfile,
            child: Text(
              'Save',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // ==========================================
          // SECTION 1: IDENTITY & SNEAK-PEEK PRIVACY SHIELD
          // ==========================================
          _buildSectionHeader(
            icon: Icons.security_rounded,
            title: '1. Identity & Privacy Shield',
            subtitle: 'Offline security with sneak-peek masking for public spaces',
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1),
                        child: Text(
                          _nameController.text.isNotEmpty
                              ? _nameController.text[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _maskText(_nameController.text),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Local Device Storage • 100% Encrypted',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                            ),
                          ],
                        ),
                      ),
                      // Privacy Toggle Button
                      FilterChip(
                        selected: _isPrivacyMaskActive,
                        selectedColor: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                        side: BorderSide(
                          color: _isPrivacyMaskActive
                              ? (isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber)
                              : AppTheme.cardBorder(context),
                        ),
                        avatar: Icon(
                          _isPrivacyMaskActive ? Icons.lock : Icons.lock_open,
                          size: 14,
                          color: _isPrivacyMaskActive
                              ? (isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber)
                              : AppTheme.textSecondary(context),
                        ),
                        label: Text(
                          _isPrivacyMaskActive ? 'Masked' : 'Public Safe',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isPrivacyMaskActive
                                ? (isDark ? AppTheme.warningAmberLight : const Color(0xFFB45309))
                                : AppTheme.textSecondary(context),
                          ),
                        ),
                        onSelected: (val) {
                          setState(() {
                            _isPrivacyMaskActive = val;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _nameController,
                    obscureText: _isPrivacyMaskActive,
                    style: TextStyle(color: AppTheme.textPrimary(context)),
                    decoration: InputDecoration(
                      labelText: 'Your Name',
                      hintText: 'Enter name or nickname',
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ==========================================
          // SECTION 2: ACCESSIBILITY, FONT SCALE & THEME
          // ==========================================
          _buildSectionHeader(
            icon: Icons.text_fields_rounded,
            title: '2. Typography & Appearance',
            subtitle: 'Dynamic font scaling and circadian display themes',
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance & Theme',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select between high-contrast daylight theme and eye-care night theme.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('Dark'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_outlined),
                        label: Text('System'),
                      ),
                    ],
                    selected: {currentThemeMode},
                    onSelectionChanged: (set) {
                      ref.read(themeNotifierProvider.notifier).setThemeMode(set.first);
                    },
                  ),
                  const SizedBox(height: 20),

                  // Font Size Scaling Functionality
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Font Size & Text Scaling',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${(fontScale * 100).toInt()}% Scale',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enlarge text size across the entire application for maximum readability.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('A', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Slider(
                          value: fontScale,
                          min: 0.85,
                          max: 1.45,
                          divisions: 6,
                          label: '${(fontScale * 100).toInt()}%',
                          onChanged: (val) {
                            ref.read(fontScaleNotifierProvider.notifier).setFontScale(val);
                          },
                        ),
                      ),
                      const Text('A', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  // Font Size Quick Presets
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFontPresetChip(label: 'Compact', scale: 0.9, current: fontScale),
                        const SizedBox(width: 6),
                        _buildFontPresetChip(label: 'Standard', scale: 1.0, current: fontScale),
                        const SizedBox(width: 6),
                        _buildFontPresetChip(label: 'Comfort', scale: 1.15, current: fontScale),
                        const SizedBox(width: 6),
                        _buildFontPresetChip(label: 'Large', scale: 1.30, current: fontScale),
                        const SizedBox(width: 6),
                        _buildFontPresetChip(label: 'X-Large', scale: 1.45, current: fontScale),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ==========================================
          // SECTION 3: SOUNDS, VIBRATION & ALERTS
          // ==========================================
          _buildSectionHeader(
            icon: Icons.notifications_active_rounded,
            title: '3. Alerts, Sound & Haptics',
            subtitle: 'High-priority clinical reminder pulses and audible chimes',
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.volume_up_outlined,
                        color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Audible Chime & Vibration Pulse',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                            Text(
                              'Unique cadence: [350ms, 150ms pause, 350ms, 650ms alert]',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(notificationServiceProvider).showTestNotification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('🔔 Test alarm triggered with audible chime & clinical vibration!'),
                            backgroundColor: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                          ),
                        );
                      }
                    },
                    icon: Icon(Icons.alarm, color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal),
                    label: Text(
                      'Test Notification, Sound & Vibration',
                      style: TextStyle(color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ==========================================
          // SECTION 4: CIRCADIAN BIOLOGICAL ROUTINE
          // ==========================================
          _buildSectionHeader(
            icon: Icons.access_time_filled_rounded,
            title: '4. Daily Routine & Meal Schedule',
            subtitle: 'Smart timing engine places doses 20 min post-meal for comfort',
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _RoutineTimeRow(
                    icon: Icons.wb_sunny_outlined,
                    label: 'Wake Up Time',
                    time: _isPrivacyMaskActive ? '••:••' : _wakeTime,
                    onTap: () => _pickTime(
                      currentTime: _wakeTime,
                      onPicked: (t) => _wakeTime = t,
                    ),
                  ),
                  Divider(height: 20, color: AppTheme.cardBorder(context)),
                  _RoutineTimeRow(
                    icon: Icons.breakfast_dining_outlined,
                    label: 'Breakfast Time',
                    time: _isPrivacyMaskActive ? '••:••' : _breakfastTime,
                    onTap: () => _pickTime(
                      currentTime: _breakfastTime,
                      onPicked: (t) => _breakfastTime = t,
                    ),
                  ),
                  Divider(height: 20, color: AppTheme.cardBorder(context)),
                  _RoutineTimeRow(
                    icon: Icons.lunch_dining_outlined,
                    label: 'Lunch Time',
                    time: _isPrivacyMaskActive ? '••:••' : _lunchTime,
                    onTap: () => _pickTime(
                      currentTime: _lunchTime,
                      onPicked: (t) => _lunchTime = t,
                    ),
                  ),
                  Divider(height: 20, color: AppTheme.cardBorder(context)),
                  _RoutineTimeRow(
                    icon: Icons.dinner_dining_outlined,
                    label: 'Dinner Time',
                    time: _isPrivacyMaskActive ? '••:••' : _dinnerTime,
                    onTap: () => _pickTime(
                      currentTime: _dinnerTime,
                      onPicked: (t) => _dinnerTime = t,
                    ),
                  ),
                  Divider(height: 20, color: AppTheme.cardBorder(context)),
                  _RoutineTimeRow(
                    icon: Icons.bedtime_outlined,
                    label: 'Sleep / Bedtime',
                    time: _isPrivacyMaskActive ? '••:••' : _sleepTime,
                    onTap: () => _pickTime(
                      currentTime: _sleepTime,
                      onPicked: (t) => _sleepTime = t,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ==========================================
          // SECTION 5: CLINICAL ALLERGIES & EXCIPIENTS
          // ==========================================
          _buildSectionHeader(
            icon: Icons.health_and_safety_rounded,
            title: 'Allergies & Excipient Sensitivities',
            subtitle: 'Cross-checks drugs, food fillers (lactose), additives & latex',
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AllergySelectorWidget(
                selectedAllergies: _allergies,
                onToggleAllergy: _toggleAllergy,
                onAddCustomAllergy: _addCustomAllergy,
                isMasked: _isPrivacyMaskActive,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ==========================================
          // SECTION 6: SYSTEM & SETUP WIZARD
          // ==========================================
          _buildSectionHeader(
            icon: Icons.settings_backup_restore_rounded,
            title: '6. System & App Configuration',
            subtitle: 'Re-open setup onboarding or reset preferences',
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const OnboardingPage()),
                      );
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Re-open Setup Wizard'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _saveProfile,
                    child: const Text('Save Profile & Routine'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDark = AppTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.primaryTealLight.withValues(alpha: 0.15)
                  : AppTheme.primaryTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontPresetChip({
    required String label,
    required double scale,
    required double current,
  }) {
    final isSelected = (current - scale).abs() < 0.05;
    final isDark = AppTheme.isDark(context);

    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected
            ? (isDark ? const Color(0xFF042F2E) : Colors.white)
            : AppTheme.textPrimary(context),
      ),
      selected: isSelected,
      selectedColor: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
      backgroundColor: AppTheme.surfaceVariant(context),
      side: BorderSide(
        color: isSelected
            ? (isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal)
            : AppTheme.cardBorder(context),
      ),
      onSelected: (_) {
        ref.read(fontScaleNotifierProvider.notifier).setFontScale(scale);
      },
    );
  }
}

class _RoutineTimeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;
  final VoidCallback onTap;

  const _RoutineTimeRow({
    required this.icon,
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.primaryTealLight.withValues(alpha: 0.18)
                    : const Color(0xFFCCFBF1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                time,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: AppTheme.textMuted(context),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
