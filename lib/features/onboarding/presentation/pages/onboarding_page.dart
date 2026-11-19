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

  // Personal Information
  final TextEditingController _nameController =
      TextEditingController(text: 'Abdalaziz');
  final TextEditingController _ageController =
      TextEditingController(text: '');
  String _selectedGender = 'Male';

  // Allergies & Health Triggers
  final List<String> _selectedAllergies = ['Penicillin'];
  final List<String> _selectedTriggers = [];
  final TextEditingController _customTriggerController = TextEditingController();

  // Daily Routine Hours
  String _wakeTime = '07:30';
  String _breakfastTime = '08:30';
  String _lunchTime = '13:30';
  String _dinnerTime = '20:00';
  String _sleepTime = '23:00';

  // Pre-configured chronic condition triggers
  static const List<Map<String, dynamic>> _commonTriggers = [
    {'title': 'Asthma / Reactive Airway', 'icon': Icons.air_rounded, 'tag': 'Asthma'},
    {'title': 'High Blood Pressure', 'icon': Icons.favorite_border_rounded, 'tag': 'Hypertension'},
    {'title': 'Type 1 or 2 Diabetes', 'icon': Icons.bloodtype_outlined, 'tag': 'Diabetes'},
    {'title': 'Stomach Ulcer / GERD', 'icon': Icons.lunch_dining_outlined, 'tag': 'Peptic Ulcer'},
    {'title': 'Kidney Impairment', 'icon': Icons.water_drop_outlined, 'tag': 'Kidney Disease'},
    {'title': 'Liver Impairment', 'icon': Icons.health_and_safety_outlined, 'tag': 'Liver Disease'},
    {'title': 'Heart Condition / Arrhythmia', 'icon': Icons.monitor_heart_outlined, 'tag': 'Heart Disease'},
    {'title': 'Pregnancy / Breastfeeding', 'icon': Icons.child_care_rounded, 'tag': 'Pregnancy'},
  ];

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileNotifierProvider);
    if (profile.name.isNotEmpty && profile.name != 'User') {
      _nameController.text = profile.name;
    }
    if (profile.age != null) {
      _ageController.text = profile.age.toString();
    }
    if (profile.gender != null) {
      _selectedGender = profile.gender!;
    }
    if (profile.allergies.isNotEmpty) {
      _selectedAllergies.clear();
      _selectedAllergies.addAll(profile.allergies);
    }
    if (profile.chronicConditions.isNotEmpty) {
      _selectedTriggers.clear();
      _selectedTriggers.addAll(profile.chronicConditions);
    }
    _wakeTime = profile.wakeTime;
    _breakfastTime = profile.breakfastTime;
    _lunchTime = profile.lunchTime;
    _dinnerTime = profile.dinnerTime;
    _sleepTime = profile.sleepTime;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _customTriggerController.dispose();
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
    final ageInt = int.tryParse(_ageController.text.trim());
    final profile = UserProfile(
      name: _nameController.text.trim().isEmpty
          ? 'User'
          : _nameController.text.trim(),
      age: ageInt,
      gender: _selectedGender,
      allergies: _selectedAllergies,
      chronicConditions: _selectedTriggers,
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
    if (_currentStep < 4) {
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

  void _toggleTrigger(String trigger) {
    setState(() {
      if (_selectedTriggers.contains(trigger)) {
        _selectedTriggers.remove(trigger);
      } else {
        _selectedTriggers.add(trigger);
      }
    });
  }

  void _addCustomTrigger() {
    final text = _customTriggerController.text.trim();
    if (text.isNotEmpty && !_selectedTriggers.contains(text)) {
      setState(() {
        _selectedTriggers.add(text);
        _customTriggerController.clear();
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
            // Top Progress Bar (5 Steps)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: List.generate(5, (index) {
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
                  _buildDemographicsStep(),
                  _buildAllergiesStep(),
                  _buildHealthTriggersStep(),
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
                        _currentStep == 4
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

  // Step 1: Personal Demographics (Name, Age, Gender)
  Widget _buildDemographicsStep() {
    final isDark = AppTheme.isDark(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF134E4A) : const Color(0xFFE0F2F1),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              Icons.person_rounded,
              color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
              size: 44,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Welcome to MediSync',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Set up your personal profile and clinical safety profile. All data remains 100% on your device.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context), height: 1.4),
        ),
        const SizedBox(height: 24),

        // Privacy Guarantee Card
        Card(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '100% Offline & Private: Zero telemetry or accounts. Encrypted strictly in your device secure storage.',
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
        const SizedBox(height: 20),

        // Name Field
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Your Name *',
            hintText: 'Enter your preferred name',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 16),

        // Age Field
        TextField(
          controller: _ageController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Age (Years)',
            hintText: 'e.g. 28',
            prefixIcon: Icon(Icons.cake_outlined),
            helperText: 'Used for pediatric (<18) or geriatric (≥65) safe dosing thresholds',
          ),
        ),
        const SizedBox(height: 20),

        // Biological Gender Selector
        Text(
          'Biological Gender',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: ['Male', 'Female', 'Other', 'Prefer not to say'].map((g) {
            final isSelected = _selectedGender == g;
            return ChoiceChip(
              label: Text(g),
              selected: isSelected,
              selectedColor: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
              labelStyle: TextStyle(
                color: isSelected
                    ? (isDark ? const Color(0xFF042F2E) : Colors.white)
                    : AppTheme.textPrimary(context),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) => setState(() => _selectedGender = g),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Step 2: Allergies & Excipient Triggers
  Widget _buildAllergiesStep() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      children: [
        const SizedBox(height: 10),
        Text(
          'Drug & Excipient Allergies',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Select substances you react to. MediSync will flag conflicting medications with bold red flags and audible alerts.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context), height: 1.4),
        ),
        const SizedBox(height: 18),
        AllergySelectorWidget(
          selectedAllergies: _selectedAllergies,
          onToggleAllergy: _toggleAllergy,
          onAddCustomAllergy: _addCustomAllergy,
        ),
      ],
    );
  }

  // Step 3: Chronic Health Conditions & Risk Triggers
  Widget _buildHealthTriggersStep() {
    final isDark = AppTheme.isDark(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      children: [
        const SizedBox(height: 10),
        Text(
          'Health Conditions & Triggers',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Indicate any underlying health conditions so MediSync can screen for dangerous drug-disease contraindications (e.g., NSAIDs with Ulcers, Beta-blockers with Asthma):',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context), height: 1.4),
        ),
        const SizedBox(height: 18),

        // Grid / List of Common Health Triggers
        ..._commonTriggers.map((trig) {
          final tag = trig['tag'] as String;
          final title = trig['title'] as String;
          final icon = trig['icon'] as IconData;
          final isSelected = _selectedTriggers.contains(tag);

          return Card(
            elevation: isSelected ? 2 : 0,
            color: isSelected
                ? (isDark ? const Color(0xFF134E4A) : const Color(0xFFE0F2F1))
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isSelected
                    ? (isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal)
                    : AppTheme.cardBorder(context),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Icon(
                icon,
                color: isSelected
                    ? (isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal)
                    : AppTheme.textSecondary(context),
              ),
              title: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              trailing: Checkbox(
                value: isSelected,
                activeColor: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                checkColor: isDark ? const Color(0xFF042F2E) : Colors.white,
                onChanged: (_) => _toggleTrigger(tag),
              ),
              onTap: () => _toggleTrigger(tag),
            ),
          );
        }),

        const SizedBox(height: 14),
        // Add Custom Trigger Field
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customTriggerController,
                decoration: const InputDecoration(
                  labelText: 'Add Other Health Condition',
                  hintText: 'e.g. Glaucoma, Gout',
                  prefixIcon: Icon(Icons.add_circle_outline),
                ),
                onSubmitted: (_) => _addCustomTrigger(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addCustomTrigger,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ],
    );
  }

  // Step 4: Daily Routine Times
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

  // Step 5: Notifications & Device Test
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
          'MediSync sends high-priority alerts with sound and vibration right on schedule, including mealtime directives (e.g. "Take after meal").',
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
                  'Tap the button below to test a high-priority alarm notification with sound on your phone.',
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
                              '🔔 Test alarm sent! Check your phone notification tray.'),
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
