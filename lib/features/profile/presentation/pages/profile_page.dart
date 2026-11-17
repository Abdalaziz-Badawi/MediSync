import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medisync/core/models/user_profile.dart';
import 'package:medisync/core/services/notification_service.dart';
import 'package:medisync/core/services/storage_service.dart';
import 'package:medisync/core/theme/app_theme.dart';
import 'package:medisync/features/onboarding/presentation/pages/onboarding_page.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _newAllergyController;

  late String _wakeTime;
  late String _sleepTime;
  late String _breakfastTime;
  late String _lunchTime;
  late String _dinnerTime;
  late bool _useHealthApp;
  late List<String> _allergies;

  static const List<String> _commonAllergySuggestions = [
    'Penicillin',
    'Sulfa',
    'Aspirin',
    'NSAIDs',
    'Dairy / Lactose',
    'Peanut Oil',
    'Gelatin',
    'Alpha-gal',
    'Sesame',
    'Egg',
  ];

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileNotifierProvider);
    _nameController = TextEditingController(text: profile.name);
    _newAllergyController = TextEditingController();

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
    _newAllergyController.dispose();
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

  void _addAllergy([String? specific]) {
    final text = specific ?? _newAllergyController.text.trim();
    if (text.isNotEmpty && !_allergies.contains(text)) {
      setState(() {
        _allergies.add(text);
        if (specific == null) _newAllergyController.clear();
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

  @override
  Widget build(BuildContext context) {
    final currentThemeMode = ref.watch(themeNotifierProvider);
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
        padding: const EdgeInsets.all(16),
        children: [
          // Privacy Guarantee Card
          Card(
            color: isDark ? const Color(0xFF064E3B) : const Color(0xFFE8F5E9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: isDark ? AppTheme.successGreenLight : AppTheme.successGreen,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Privacy First: All data is stored strictly on your local device. Zero third-party cloud trackers.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFFD1FAE5) : const Color(0xFF1B5E20),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // User Name
          TextField(
            controller: _nameController,
            style: TextStyle(color: AppTheme.textPrimary(context)),
            decoration: InputDecoration(
              labelText: 'Your Name',
              labelStyle: TextStyle(color: AppTheme.textSecondary(context)),
              prefixIcon: Icon(
                Icons.person_outline,
                color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Theme / Appearance Card (Light & Dark Mode)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance & Theme',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose between Crisp Light mode and Eye-Care Night Dark mode.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 14),
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
                      ref
                          .read(themeNotifierProvider.notifier)
                          .setThemeMode(set.first);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Notification & Reminder Testing Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Reminders, Sound & Vibration',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Test alarms and notification vibration rhythm on this device.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await ref
                          .read(notificationServiceProvider)
                          .showTestNotification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              '🔔 Test reminder with audible chime & vibration triggered!',
                            ),
                            backgroundColor: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      Icons.alarm,
                      color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                    ),
                    label: Text(
                      'Test Notification, Sound & Vibration',
                      style: TextStyle(
                        color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Daily Routine Pickers
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Routine Schedule',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Used by the smart scheduler to arrange morning, mealtime, and bedtime medicines seamlessly.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _RoutineTimeRow(
                    icon: Icons.wb_sunny_outlined,
                    label: 'Wake Up Time',
                    time: _wakeTime,
                    onTap: () => _pickTime(
                      currentTime: _wakeTime,
                      onPicked: (t) => _wakeTime = t,
                    ),
                  ),
                  Divider(height: 20, color: AppTheme.cardBorder(context)),
                  _RoutineTimeRow(
                    icon: Icons.breakfast_dining_outlined,
                    label: 'Breakfast Time',
                    time: _breakfastTime,
                    onTap: () => _pickTime(
                      currentTime: _breakfastTime,
                      onPicked: (t) => _breakfastTime = t,
                    ),
                  ),
                  Divider(height: 20, color: AppTheme.cardBorder(context)),
                  _RoutineTimeRow(
                    icon: Icons.lunch_dining_outlined,
                    label: 'Lunch Time',
                    time: _lunchTime,
                    onTap: () => _pickTime(
                      currentTime: _lunchTime,
                      onPicked: (t) => _lunchTime = t,
                    ),
                  ),
                  Divider(height: 20, color: AppTheme.cardBorder(context)),
                  _RoutineTimeRow(
                    icon: Icons.dinner_dining_outlined,
                    label: 'Dinner Time',
                    time: _dinnerTime,
                    onTap: () => _pickTime(
                      currentTime: _dinnerTime,
                      onPicked: (t) => _dinnerTime = t,
                    ),
                  ),
                  Divider(height: 20, color: AppTheme.cardBorder(context)),
                  _RoutineTimeRow(
                    icon: Icons.bedtime_outlined,
                    label: 'Sleep / Bedtime',
                    time: _sleepTime,
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

          // Allergies Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.shield,
                        color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Allergies & Excipient Sensitivities',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cross-checks both active drugs and inactive excipients (lactose, peanut/sesame oils, gelatin, gluten).',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_allergies.isEmpty)
                    Text(
                      'No allergies entered yet.',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textMuted(context),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _allergies.map((allergy) {
                        return Chip(
                          backgroundColor: isDark
                              ? const Color(0xFF450A0A)
                              : const Color(0xFFFEE2E2),
                          side: BorderSide(
                            color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                          ),
                          label: Text(
                            allergy,
                            style: TextStyle(
                              color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          deleteIconColor: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                          onDeleted: () {
                            setState(() {
                              _allergies.remove(allergy);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 14),

                  // Quick suggestions from taxonomy
                  Text(
                    'Quick Add from Clinical Taxonomy:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _commonAllergySuggestions
                        .where((s) => !_allergies.contains(s))
                        .map((suggestion) {
                      return ActionChip(
                        label: Text(suggestion),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textPrimary(context),
                        ),
                        backgroundColor: AppTheme.surfaceVariant(context),
                        side: BorderSide(color: AppTheme.cardBorder(context)),
                        onPressed: () => _addAllergy(suggestion),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newAllergyController,
                          style: TextStyle(color: AppTheme.textPrimary(context)),
                          decoration: InputDecoration(
                            labelText: 'Add Custom Allergy / Excipient',
                            hintText: 'e.g. Penicillin, Lactose, Gelatin',
                            isDense: true,
                            labelStyle: TextStyle(color: AppTheme.textSecondary(context)),
                          ),
                          onSubmitted: (_) => _addAllergy(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: const Icon(Icons.add),
                        onPressed: () => _addAllergy(),
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                          foregroundColor: isDark ? const Color(0xFF042F2E) : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Re-run Onboarding button
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OnboardingPage()),
              );
            },
            icon: const Icon(Icons.restart_alt),
            label: const Text('Re-open Setup Wizard'),
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: _saveProfile,
            child: const Text('Save Profile & Routine'),
          ),
          const SizedBox(height: 40),
        ],
      ),
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
