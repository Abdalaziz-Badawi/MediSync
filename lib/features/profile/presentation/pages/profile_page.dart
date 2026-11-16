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

  void _addAllergy() {
    final text = _newAllergyController.text.trim();
    if (text.isNotEmpty && !_allergies.contains(text)) {
      setState(() {
        _allergies.add(text);
        _newAllergyController.clear();
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
      const SnackBar(
        content: Text('Profile and routine saved locally!'),
        backgroundColor: AppTheme.primaryTeal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentThemeMode = ref.watch(themeNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Routine'),
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: const Text(
              'Save',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTeal,
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
            color: const Color(0xFFE8F5E9),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined,
                      color: AppTheme.successGreen, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Privacy First: All data is stored strictly on your local device. No third-party data tracking.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1B5E20),
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
            decoration: const InputDecoration(
              labelText: 'Your Name',
              prefixIcon: Icon(Icons.person_outline),
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
                  const Text(
                    'Appearance & Theme',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose between Light mode and Night-friendly Dark mode.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
                        label: Text('Auto'),
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
                  const Row(
                    children: [
                      Icon(Icons.notifications_active_outlined,
                          color: AppTheme.primaryTeal, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Reminders & Notifications',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Test alarms and notifications on your device to ensure sound and vibrations are working.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await ref
                          .read(notificationServiceProvider)
                          .showTestNotification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                '🔔 Test notification triggered on phone! Check status bar.'),
                            backgroundColor: AppTheme.primaryTeal,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.alarm, color: AppTheme.primaryTeal),
                    label: const Text('Test Notification & Sound Now'),
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
                  const Text(
                    'Daily Routine Schedule',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Used by the smart scheduler to arrange morning, mealtime, and bedtime medicines.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
                  const Divider(height: 20),
                  _RoutineTimeRow(
                    icon: Icons.breakfast_dining_outlined,
                    label: 'Breakfast Time',
                    time: _breakfastTime,
                    onTap: () => _pickTime(
                      currentTime: _breakfastTime,
                      onPicked: (t) => _breakfastTime = t,
                    ),
                  ),
                  const Divider(height: 20),
                  _RoutineTimeRow(
                    icon: Icons.lunch_dining_outlined,
                    label: 'Lunch Time',
                    time: _lunchTime,
                    onTap: () => _pickTime(
                      currentTime: _lunchTime,
                      onPicked: (t) => _lunchTime = t,
                    ),
                  ),
                  const Divider(height: 20),
                  _RoutineTimeRow(
                    icon: Icons.dinner_dining_outlined,
                    label: 'Dinner Time',
                    time: _dinnerTime,
                    onTap: () => _pickTime(
                      currentTime: _dinnerTime,
                      onPicked: (t) => _dinnerTime = t,
                    ),
                  ),
                  const Divider(height: 20),
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
                  const Row(
                    children: [
                      Icon(Icons.shield, color: AppTheme.dangerRed, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Known Drug Allergies',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'The app cross-checks all entered medicines against these to prevent adverse reactions.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _allergies.map((allergy) {
                      return Chip(
                        backgroundColor: const Color(0xFFFFEBEE),
                        side: const BorderSide(color: AppTheme.dangerRed),
                        label: Text(
                          allergy,
                          style: const TextStyle(
                            color: AppTheme.dangerRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        deleteIconColor: AppTheme.dangerRed,
                        onDeleted: () {
                          setState(() {
                            _allergies.remove(allergy);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newAllergyController,
                          decoration: const InputDecoration(
                            labelText: 'Add Allergy',
                            hintText: 'e.g. Penicillin, Sulfa, Aspirin',
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addAllergy(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: const Icon(Icons.add),
                        onPressed: _addAllergy,
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.primaryTeal,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryTeal, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                time,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTeal,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
