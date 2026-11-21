import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medisync/core/models/user_profile.dart';
import 'package:medisync/core/services/device_integration_service.dart';
import 'package:medisync/core/services/notification_service.dart';
import 'package:medisync/core/services/storage_service.dart';
import 'package:medisync/core/theme/app_theme.dart';
import 'package:medisync/features/homeboard/presentation/pages/main_navigation_page.dart';
import 'package:medisync/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:medisync/features/profile/presentation/widgets/allergy_selector_widget.dart';
import 'package:medisync/features/profile/presentation/widgets/emergency_health_card.dart';

class ProfilePage extends ConsumerStatefulWidget {
  final bool initiallyExpanded;
  const ProfilePage({super.key, this.initiallyExpanded = false});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _healthIdController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  DateTime? _dateOfBirth;

  late String _avatarId;
  String? _profileImagePath;
  String _lockscreenDefaultView = 'card';
  late String _gender;
  late String _bloodType;
  late String _wakeTime;
  late String _sleepTime;
  late String _breakfastTime;
  late String _lunchTime;
  late String _dinnerTime;
  late bool _useHealthApp;
  late List<String> _allergies;
  late List<String> _chronicConditions;

  double? get _currentWeight => double.tryParse(_weightController.text.trim());
  double? get _currentHeight => double.tryParse(_heightController.text.trim());
  double? get _calculatedBmi {
    final w = _currentWeight;
    final h = _currentHeight;
    if (w != null && h != null && h > 0) {
      final meters = h / 100.0;
      return w / (meters * meters);
    }
    return null;
  }

  String get _currentBmiCategory {
    final b = _calculatedBmi;
    if (b == null) return '';
    if (b < 18.5) return 'Underweight';
    if (b < 25.0) return 'Normal Weight';
    if (b < 30.0) return 'Overweight';
    return 'Obese';
  }

  int? get _calculatedAge {
    if (_dateOfBirth == null) return null;
    final now = DateTime.now();
    int calculated = now.year - _dateOfBirth!.year;
    if (now.month < _dateOfBirth!.month ||
        (now.month == _dateOfBirth!.month && now.day < _dateOfBirth!.day)) {
      calculated--;
    }
    return calculated >= 0 ? calculated : 0;
  }

  // Privacy Shield / Sneak Peek Prevention
  bool _isPrivacyMaskActive = false;

  // Collapsible Cards State (Starts collapsed by default, expands on interaction, collapses on leave)
  late bool _isProfileCardExpanded;
  late bool _isSettingsCardExpanded;
  late bool _isRoutineExpanded;
  bool _isAllergiesExpanded = false;
  bool _isConditionsExpanded = false;
  bool _isAboutCardExpanded = false;

  final TextEditingController _customConditionController = TextEditingController();

  static const List<Map<String, dynamic>> _commonChronicConditions = [
    {'title': 'Asthma (Airway)', 'icon': Icons.air_rounded, 'tag': 'Asthma'},
    {'title': 'Hypertension (High BP)', 'icon': Icons.favorite_border_rounded, 'tag': 'Hypertension'},
    {'title': 'Diabetes (Type 1 or 2)', 'icon': Icons.bloodtype_outlined, 'tag': 'Diabetes'},
    {'title': 'Peptic Ulcer / GERD', 'icon': Icons.lunch_dining_outlined, 'tag': 'Peptic Ulcer'},
    {'title': 'Kidney Impairment', 'icon': Icons.water_drop_outlined, 'tag': 'Kidney Disease'},
    {'title': 'Liver Impairment', 'icon': Icons.health_and_safety_outlined, 'tag': 'Liver Disease'},
    {'title': 'Heart Condition', 'icon': Icons.monitor_heart_outlined, 'tag': 'Heart Disease'},
    {'title': 'Pregnancy / Lactation', 'icon': Icons.child_care_rounded, 'tag': 'Pregnancy'},
  ];

  static const List<Map<String, dynamic>> _availableAvatars = [
    {'id': 'avatar_wellness', 'icon': Icons.spa_rounded, 'label': 'Wellness'},
    {'id': 'avatar_doctor', 'icon': Icons.medical_services_rounded, 'label': 'Clinical'},
    {'id': 'avatar_shield', 'icon': Icons.shield_rounded, 'label': 'Protector'},
    {'id': 'avatar_heart', 'icon': Icons.favorite_rounded, 'label': 'Heart'},
    {'id': 'avatar_person', 'icon': Icons.person_rounded, 'label': 'Individual'},
    {'id': 'avatar_star', 'icon': Icons.stars_rounded, 'label': 'Star'},
  ];

  @override
  void initState() {
    super.initState();
    _isProfileCardExpanded = widget.initiallyExpanded;
    _isSettingsCardExpanded = widget.initiallyExpanded;
    _isRoutineExpanded = widget.initiallyExpanded;

    final profile = ref.read(profileNotifierProvider);
    _nameController = TextEditingController(text: profile.name);
    _healthIdController = TextEditingController(text: profile.healthId ?? '');
    _weightController =
        TextEditingController(text: profile.weightKg?.toString() ?? '');
    _heightController =
        TextEditingController(text: profile.heightCm?.toString() ?? '');
    _profileImagePath = profile.profileImagePath;
    _lockscreenDefaultView = profile.lockscreenDefaultView;
    _dateOfBirth = profile.dateOfBirth;
    _avatarId = profile.avatarId;
    _gender = profile.gender ?? 'Male';
    _bloodType = profile.bloodType ?? 'O+';

    _wakeTime = profile.wakeTime;
    _sleepTime = profile.sleepTime;
    _breakfastTime = profile.breakfastTime;
    _lunchTime = profile.lunchTime;
    _dinnerTime = profile.dinnerTime;
    _useHealthApp = profile.useHealthApp;
    _allergies = List.from(profile.allergies);
    _chronicConditions = List.from(profile.chronicConditions);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _healthIdController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _customConditionController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final profile = ref.read(profileNotifierProvider);
    if (_nameController.text.trim() != profile.name) return true;
    if (_healthIdController.text.trim() != (profile.healthId ?? '')) return true;
    if (_weightController.text.trim() != (profile.weightKg?.toString() ?? '')) return true;
    if (_heightController.text.trim() != (profile.heightCm?.toString() ?? '')) return true;
    if (_profileImagePath != profile.profileImagePath) return true;
    if (_lockscreenDefaultView != profile.lockscreenDefaultView) return true;
    if (_dateOfBirth != profile.dateOfBirth) return true;
    if (_gender != (profile.gender ?? 'Male')) return true;
    if (_bloodType != (profile.bloodType ?? 'O+')) return true;
    if (_avatarId != profile.avatarId) return true;
    if (_wakeTime != profile.wakeTime) return true;
    if (_sleepTime != profile.sleepTime) return true;
    if (_breakfastTime != profile.breakfastTime) return true;
    if (_lunchTime != profile.lunchTime) return true;
    if (_dinnerTime != profile.dinnerTime) return true;
    if (_useHealthApp != profile.useHealthApp) return true;
    if (_allergies.length != profile.allergies.length) return true;
    for (final a in _allergies) {
      if (!profile.allergies.contains(a)) return true;
    }
    if (_chronicConditions.length != profile.chronicConditions.length) return true;
    for (final c in _chronicConditions) {
      if (!profile.chronicConditions.contains(c)) return true;
    }
    return false;
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
            scale: 1.12, // Substantially enlarged clock widget
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

  void _toggleChronicCondition(String tag) {
    setState(() {
      if (_chronicConditions.contains(tag)) {
        _chronicConditions.remove(tag);
      } else {
        _chronicConditions.add(tag);
      }
    });
  }

  void _addCustomChronicCondition(String custom) {
    final trimmed = custom.trim();
    if (trimmed.isNotEmpty && !_chronicConditions.contains(trimmed)) {
      setState(() {
        _chronicConditions.add(trimmed);
      });
      _customConditionController.clear();
    }
  }

  void _saveProfile() {
    final updated = UserProfile(
      name: _nameController.text.trim().isEmpty
          ? 'User'
          : _nameController.text.trim(),
      avatarId: _avatarId,
      profileImagePath: _profileImagePath,
      lockscreenDefaultView: _lockscreenDefaultView,
      dateOfBirth: _dateOfBirth,
      gender: _gender,
      bloodType: _bloodType,
      healthId: _healthIdController.text.trim().isNotEmpty
          ? _healthIdController.text.trim()
          : null,
      allergies: _allergies,
      chronicConditions: _chronicConditions,
      wakeTime: _wakeTime,
      sleepTime: _sleepTime,
      breakfastTime: _breakfastTime,
      lunchTime: _lunchTime,
      dinnerTime: _dinnerTime,
      useHealthApp: _useHealthApp,
      weightKg: _currentWeight,
      heightCm: _currentHeight,
    );

    ref.read(profileNotifierProvider.notifier).updateProfile(updated);

    // Sync updated profile to Lockscreen Emergency Widget
    final activeCount = ref.read(medicationsNotifierProvider).where((m) => !m.isDiscontinued).length;
    DeviceIntegrationService().updateLockscreenWidget(
      patientName: updated.name,
      bloodType: updated.bloodType ?? 'Unknown',
      allergiesCount: updated.allergies.length,
      activeMedsCount: activeCount,
    );

    setState(() {}); // Updates _hasChanges to false

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Profile, health biometrics & emergency data saved locally!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✓ User settings, theme & device sync saved!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  String _maskText(String text) {
    if (!_isPrivacyMaskActive) return text;
    if (text.isEmpty) return '••••••';
    return '${text[0]}${'•' * (text.length - 1).clamp(4, 10)}';
  }

  IconData _getAvatarIcon(String id) {
    final match = _availableAvatars.firstWhere(
      (a) => a['id'] == id,
      orElse: () => _availableAvatars.first,
    );
    return match['icon'] as IconData;
  }

  void _openAvatarPicker() {
    final isDark = AppTheme.isDark(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF151E2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Account Avatar (PFP)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(ctx),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Choose an icon avatar to personalize your account:',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(ctx)),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: _availableAvatars.map((av) {
                    final isSel = _avatarId == av['id'] && _profileImagePath == null;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _avatarId = av['id'] as String;
                          _profileImagePath = null;
                        });
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(36),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSel
                              ? Theme.of(ctx).colorScheme.primary.withValues(alpha: isDark ? 0.3 : 0.15)
                              : AppTheme.surfaceVariant(ctx),
                          border: Border.all(
                            color: isSel
                                ? Theme.of(ctx).colorScheme.primary
                                : AppTheme.cardBorder(ctx),
                            width: isSel ? 2.5 : 1,
                          ),
                        ),
                        child: Icon(
                          av['icon'] as IconData,
                          size: 32,
                          color: isSel
                              ? Theme.of(ctx).colorScheme.primary
                              : AppTheme.textSecondary(ctx),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Divider(height: 1, color: AppTheme.cardBorder(ctx)),
                const SizedBox(height: 10),

                // Custom Gallery Photo Picker Action
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.photo_library_rounded, color: Theme.of(ctx).colorScheme.primary, size: 22),
                  ),
                  title: const Text('Pick Photo from Device Gallery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(
                    _profileImagePath != null
                        ? 'Custom photo currently active (tap to replace)'
                        : 'Select an image from device gallery',
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary(ctx)),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final picked = await DeviceIntegrationService().pickGalleryImage();
                    if (picked != null) {
                      setState(() {
                        _profileImagePath = picked;
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('✓ Profile picture selected from gallery! Save profile to keep changes.'),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                          ),
                        );
                      }
                    }
                  },
                ),

                if (_profileImagePath != null) ...[
                  const SizedBox(height: 6),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerRed.withValues(alpha: isDark ? 0.25 : 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: AppTheme.dangerRed, size: 22),
                    ),
                    title: const Text('Remove Custom Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.dangerRed)),
                    subtitle: Text('Revert back to icon avatar', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary(ctx))),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _profileImagePath = null;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openEditProfileDialog() {
    final isDark = AppTheme.isDark(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF151E2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Personal Profile',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(ctx),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                style: TextStyle(color: AppTheme.textPrimary(ctx)),
                decoration: InputDecoration(
                  labelText: 'Your Name or Nickname',
                  prefixIcon: Icon(
                    Icons.person_outline_rounded,
                    color: Theme.of(ctx).colorScheme.primary,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              // Date of Birth Selector (replacing direct age typing)
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dateOfBirth ?? DateTime(1995, 5, 14),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _dateOfBirth = picked);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.cardBorder(ctx)),
                    borderRadius: BorderRadius.circular(12),
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cake_outlined, color: Theme.of(ctx).colorScheme.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date of Birth',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textSecondary(ctx),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _dateOfBirth != null
                                  ? DateFormat('d MMMM yyyy').format(_dateOfBirth!)
                                  : 'Tap to select Date of Birth',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _dateOfBirth != null
                                    ? AppTheme.textPrimary(ctx)
                                    : AppTheme.textMuted(ctx),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_calculatedAge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF134E4A) : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$_calculatedAge yrs',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.primaryTealLight : const Color(0xFF166534),
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      const Icon(Icons.calendar_month_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Health ID Field
              TextField(
                controller: _healthIdController,
                style: TextStyle(color: AppTheme.textPrimary(ctx)),
                decoration: InputDecoration(
                  labelText: 'Health ID / Medical Record #',
                  hintText: 'e.g. National ID, NHS, Insurance #',
                  prefixIcon: Icon(
                    Icons.credit_card_rounded,
                    color: Theme.of(ctx).colorScheme.primary,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              // Height & Weight Fields with Live Dynamic BMI
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _heightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: AppTheme.textPrimary(ctx)),
                      decoration: InputDecoration(
                        labelText: 'Height (cm)',
                        hintText: 'e.g. 175',
                        prefixIcon: Icon(
                          Icons.height_rounded,
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: AppTheme.textPrimary(ctx)),
                      decoration: InputDecoration(
                        labelText: 'Weight (kg)',
                        hintText: 'e.g. 70.5',
                        prefixIcon: Icon(
                          Icons.monitor_weight_outlined,
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              if (_calculatedBmi != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.primary.withValues(alpha: isDark ? 0.20 : 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.favorite_rounded, size: 16, color: Theme.of(ctx).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Calculated BMI: ${_calculatedBmi!.toStringAsFixed(1)} • $_currentBmiCategory',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Biological Gender
              Text(
                'Biological Gender',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(ctx),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: ['Male', 'Female', 'Other', 'Prefer not to say'].map((g) {
                  final isSel = _gender == g;
                  return ChoiceChip(
                    label: Text(g),
                    selected: isSel,
                    selectedColor: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                    labelStyle: TextStyle(
                      color: isSel
                          ? (isDark ? const Color(0xFF042F2E) : Colors.white)
                          : AppTheme.textPrimary(ctx),
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => setState(() => _gender = g),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Blood Type Selector
              Row(
                children: [
                  const Icon(Icons.bloodtype_rounded, size: 16, color: Color(0xFFDC2626)),
                  const SizedBox(width: 4),
                  Text(
                    'Blood Type (Emergency ID)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(ctx),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: UserProfile.standardBloodTypes.map((bt) {
                  final isSel = _bloodType == bt;
                  return ChoiceChip(
                    label: Text(bt),
                    selected: isSel,
                    selectedColor: const Color(0xFFDC2626),
                    labelStyle: TextStyle(
                      color: isSel ? Colors.white : AppTheme.textPrimary(ctx),
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => setState(() => _bloodType = bt),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Chronic Conditions & Clinical Organ Risks
              Row(
                children: [
                  const Icon(Icons.monitor_heart_outlined, size: 16, color: Color(0xFF0D9488)),
                  const SizedBox(width: 4),
                  Text(
                    'Chronic Conditions & Organ Risks',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(ctx),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _commonChronicConditions.map((cond) {
                  final tag = cond['tag'] as String;
                  final title = cond['title'] as String;
                  final isSel = _chronicConditions.contains(tag);
                  return FilterChip(
                    label: Text(title),
                    selected: isSel,
                    selectedColor: const Color(0xFFCCFBF1),
                    checkmarkColor: const Color(0xFF0F766E),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      color: isSel ? const Color(0xFF0F766E) : AppTheme.textPrimary(ctx),
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => setState(() => _toggleChronicCondition(tag)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Theme.of(ctx).colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.15),
                  child: Icon(
                    _getAvatarIcon(_avatarId),
                    color: Theme.of(ctx).colorScheme.primary,
                  ),
                ),
                title: const Text('Change Avatar Icon'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  _openAvatarPicker();
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OnboardingPage()),
                  );
                },
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: const Text('Relaunch Full Setup Wizard'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _saveProfile();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save Details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentThemeMode = ref.watch(themeNotifierProvider);
    final fontScale = ref.watch(fontScaleNotifierProvider);
    final currentPalette = ref.watch(paletteNotifierProvider);
    final isDark = AppTheme.isDark(context);
    final hasChanges = _hasChanges;

    // Auto-collapse when user leaves or changes page
    ref.listen<int>(mainNavIndexProvider, (prev, next) {
      if (next != 3) {
        if (_isProfileCardExpanded || _isSettingsCardExpanded || _isAllergiesExpanded || _isAboutCardExpanded || _isRoutineExpanded || _isConditionsExpanded) {
          setState(() {
            _isProfileCardExpanded = false;
            _isSettingsCardExpanded = false;
            _isAllergiesExpanded = false;
            _isAboutCardExpanded = false;
            _isRoutineExpanded = false;
            _isConditionsExpanded = false;
          });
        }
      }
    });

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
              _isPrivacyMaskActive ? Icons.visibility_off_rounded : Icons.visibility_rounded,
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
          // Save button only appears if changes have been made
          if (hasChanges)
            TextButton(
              onPressed: _saveProfile,
              child: Text(
                'Save',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
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
          // 1. MASTER USER PROFILE CARD (Houses PFP, Routine, & Allergies)
          // ==========================================
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.cardBorder(context)),
              boxShadow: AppTheme.softShadow(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Account Info Row with PFP Avatar (Tap to expand/collapse card)
                InkWell(
                  onTap: () {
                    setState(() {
                      _isProfileCardExpanded = !_isProfileCardExpanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Avatar PFP (Tap to choose new avatar)
                        GestureDetector(
                          onTap: _openAvatarPicker,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.15),
                                backgroundImage: (_profileImagePath != null && File(_profileImagePath!).existsSync())
                                    ? FileImage(File(_profileImagePath!))
                                    : null,
                                child: (_profileImagePath != null && File(_profileImagePath!).existsSync())
                                    ? null
                                    : Icon(
                                        _getAvatarIcon(_avatarId),
                                        size: 30,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    size: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  if (_calculatedAge != null) ...[
                                    Flexible(
                                      child: Text(
                                        '$_calculatedAge yrs • $_gender',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Text('•', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    const SizedBox(width: 5),
                                  ],
                                  Expanded(
                                    child: Text(
                                      _isProfileCardExpanded
                                          ? 'Encrypted Local Storage • Tap to collapse'
                                          : 'Encrypted Local Storage • Tap to expand',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary(context),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit Name',
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onPressed: _openEditProfileDialog,
                        ),
                        Icon(
                          _isProfileCardExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.textSecondary(context),
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),

                // Collapsed Summary Preview
                if (!_isProfileCardExpanded) ...[
                  Divider(height: 1, color: AppTheme.cardBorder(context)),
                  InkWell(
                    onTap: () => setState(() => _isProfileCardExpanded = true),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Routine: Wake ${_isPrivacyMaskActive ? '••:••' : _wakeTime} • Bed ${_isPrivacyMaskActive ? '••:••' : _sleepTime} • ${_allergies.length} Allergies • ${_chronicConditions.length} Conditions',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'Expand',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                if (_isProfileCardExpanded) ...[
                  Divider(height: 1, color: AppTheme.cardBorder(context)),

                  // 1. Demographics & Bio Info Section (Organized Clean Layout)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bio Info Header Row (Title on Left with Expanded, Setup Wizard Action on Right)
                        Row(
                          children: [
                            Icon(
                              Icons.badge_outlined,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Bio & Demographics',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const OnboardingPage()),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.auto_fix_high_rounded,
                                      size: 13,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Setup Wizard',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Organized Full-Width Wrap for Bio Info Badges (Eliminates Row Overflow)
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Chip(
                              visualDensity: VisualDensity.compact,
                              avatar: const Icon(Icons.cake_outlined, size: 14),
                              label: Text(
                                _dateOfBirth != null
                                    ? '${_calculatedAge ?? 0} yrs (${DateFormat('d MMM yyyy').format(_dateOfBirth!)})'
                                    : 'DoB: Not set',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: AppTheme.surfaceVariant(context),
                            ),
                            Chip(
                              visualDensity: VisualDensity.compact,
                              avatar: const Icon(Icons.person_outline_rounded, size: 14),
                              label: Text(_gender, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              backgroundColor: AppTheme.surfaceVariant(context),
                            ),
                            Chip(
                              visualDensity: VisualDensity.compact,
                              avatar: const Icon(Icons.bloodtype_rounded, size: 14, color: Color(0xFFDC2626)),
                              label: Text(
                                'Blood: $_bloodType',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                              backgroundColor: const Color(0xFFFEF2F2),
                              side: const BorderSide(color: Color(0xFFFECACA)),
                            ),
                            if (_healthIdController.text.trim().isNotEmpty)
                              Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: const Icon(Icons.credit_card_rounded, size: 14),
                                label: Text(
                                  'ID: ${_healthIdController.text.trim()}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                backgroundColor: AppTheme.surfaceVariant(context),
                              ),
                            if (_chronicConditions.isNotEmpty)
                              Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: const Icon(Icons.monitor_heart_rounded, size: 14, color: Color(0xFF0D9488)),
                                label: Text(
                                  '${_chronicConditions.length} Condition${_chronicConditions.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D9488),
                                  ),
                                ),
                                backgroundColor: const Color(0xFFF0FDFA),
                                side: const BorderSide(color: Color(0xFFCCFBF1)),
                              ),
                            if (_heightController.text.trim().isNotEmpty)
                              Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: const Icon(Icons.height_rounded, size: 14),
                                label: Text(
                                  'HT: ${_heightController.text.trim()} cm',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                backgroundColor: AppTheme.surfaceVariant(context),
                              ),
                            if (_weightController.text.trim().isNotEmpty)
                              Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: const Icon(Icons.monitor_weight_outlined, size: 14),
                                label: Text(
                                  'WT: ${_weightController.text.trim()} kg',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                backgroundColor: AppTheme.surfaceVariant(context),
                              ),
                            if (_calculatedBmi != null)
                              Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: const Icon(Icons.favorite_rounded, size: 14, color: Color(0xFF2563EB)),
                                label: Text(
                                  'BMI: ${_calculatedBmi!.toStringAsFixed(1)} ($_currentBmiCategory)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                                backgroundColor: const Color(0xFFEFF6FF),
                                side: const BorderSide(color: Color(0xFFBFDBFE)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: AppTheme.cardBorder(context)),

                  // --- INTEGRATED DAILY ROUTINE & MEAL SCHEDULE (Collapsible View) ---
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isRoutineExpanded = !_isRoutineExpanded;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.access_time_filled_rounded,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daily Routine & Meal Times',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary(context),
                                  ),
                                ),
                                Text(
                                  _isRoutineExpanded
                                      ? 'Tap to collapse daily routine schedule'
                                      : 'Wake ${_isPrivacyMaskActive ? '••:••' : _wakeTime} • Bed ${_isPrivacyMaskActive ? '••:••' : _sleepTime} • Tap to view & edit',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            _isRoutineExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: AppTheme.textSecondary(context),
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Collapsed Routine Quick-Preview Badges (Horizontal scrollable, 0 risk of overflow)
                  if (!_isRoutineExpanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildRoutinePreviewChip(
                              context,
                              icon: Icons.wb_sunny_rounded,
                              label: 'Wake',
                              time: _isPrivacyMaskActive ? '••:••' : _wakeTime,
                            ),
                            const SizedBox(width: 6),
                            _buildRoutinePreviewChip(
                              context,
                              icon: Icons.breakfast_dining_rounded,
                              label: 'Breakfast',
                              time: _isPrivacyMaskActive ? '••:••' : _breakfastTime,
                            ),
                            const SizedBox(width: 6),
                            _buildRoutinePreviewChip(
                              context,
                              icon: Icons.lunch_dining_rounded,
                              label: 'Lunch',
                              time: _isPrivacyMaskActive ? '••:••' : _lunchTime,
                            ),
                            const SizedBox(width: 6),
                            _buildRoutinePreviewChip(
                              context,
                              icon: Icons.dinner_dining_rounded,
                              label: 'Dinner',
                              time: _isPrivacyMaskActive ? '••:••' : _dinnerTime,
                            ),
                            const SizedBox(width: 6),
                            _buildRoutinePreviewChip(
                              context,
                              icon: Icons.bedtime_rounded,
                              label: 'Sleep',
                              time: _isPrivacyMaskActive ? '••:••' : _sleepTime,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Expanded Full Routine Time Selectors
                  if (_isRoutineExpanded)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _RoutineTimeRow(
                            icon: Icons.wb_sunny_rounded,
                            label: 'Wake Up Time',
                            time: _isPrivacyMaskActive ? '••:••' : _wakeTime,
                            onTap: () => _pickTime(
                              currentTime: _wakeTime,
                              onPicked: (t) => _wakeTime = t,
                            ),
                          ),
                          Divider(height: 14, color: AppTheme.cardBorder(context)),
                          _RoutineTimeRow(
                            icon: Icons.breakfast_dining_rounded,
                            label: 'Breakfast Time',
                            time: _isPrivacyMaskActive ? '••:••' : _breakfastTime,
                            onTap: () => _pickTime(
                              currentTime: _breakfastTime,
                              onPicked: (t) => _breakfastTime = t,
                            ),
                          ),
                          Divider(height: 14, color: AppTheme.cardBorder(context)),
                          _RoutineTimeRow(
                            icon: Icons.lunch_dining_rounded,
                            label: 'Lunch Time',
                            time: _isPrivacyMaskActive ? '••:••' : _lunchTime,
                            onTap: () => _pickTime(
                              currentTime: _lunchTime,
                              onPicked: (t) => _lunchTime = t,
                            ),
                          ),
                          Divider(height: 14, color: AppTheme.cardBorder(context)),
                          _RoutineTimeRow(
                            icon: Icons.dinner_dining_rounded,
                            label: 'Dinner Time',
                            time: _isPrivacyMaskActive ? '••:••' : _dinnerTime,
                            onTap: () => _pickTime(
                              currentTime: _dinnerTime,
                              onPicked: (t) => _dinnerTime = t,
                            ),
                          ),
                          Divider(height: 14, color: AppTheme.cardBorder(context)),
                          _RoutineTimeRow(
                            icon: Icons.bedtime_rounded,
                            label: 'Sleep / Bedtime',
                            time: _isPrivacyMaskActive ? '••:••' : _sleepTime,
                            onTap: () => _pickTime(
                              currentTime: _sleepTime,
                              onPicked: (t) => _sleepTime = t,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),

                const SizedBox(height: 10),
                Divider(height: 1, color: AppTheme.cardBorder(context)),

                // --- INTEGRATED ALLERGIES & EXCIPIENTS (Collapsible View) ---
                InkWell(
                  onTap: () {
                    setState(() {
                      _isAllergiesExpanded = !_isAllergiesExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.shield_rounded,
                            size: 18,
                            color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_allergies.length} Active Safety Trigger${_allergies.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                              Text(
                                _isAllergiesExpanded
                                    ? 'Tap to collapse allergy triggers'
                                    : 'Tap to expand & edit allergy triggers',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _isAllergiesExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.textSecondary(context),
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),

                // Collapsed Preview Badges
                if (!_isAllergiesExpanded && _allergies.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _allergies.take(4).map((allergy) {
                          final displayText = _isPrivacyMaskActive ? '••••••••' : allergy;
                          return Chip(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                            side: BorderSide(color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed),
                            label: Text(
                              displayText,
                              style: TextStyle(
                                color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],

                // Expanded Taxonomy Selector
                if (_isAllergiesExpanded) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: AllergySelectorWidget(
                      selectedAllergies: _allergies,
                      onToggleAllergy: _toggleAllergy,
                      onAddCustomAllergy: _addCustomAllergy,
                      isMasked: _isPrivacyMaskActive,
                    ),
                  ),
                ],

                // --- CHRONIC CONDITIONS & ORGAN RISKS SECTION ---
                Divider(height: 1, color: AppTheme.cardBorder(context)),
                InkWell(
                  onTap: () {
                    setState(() {
                      _isConditionsExpanded = !_isConditionsExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withValues(alpha: isDark ? 0.25 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.monitor_heart_rounded,
                            size: 18,
                            color: Color(0xFF0D9488),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Chronic Conditions & Organ Risks',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary(context),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_chronicConditions.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${_chronicConditions.length}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0D9488),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                _isConditionsExpanded
                                    ? 'Tap to collapse clinical risks & precautions'
                                    : _chronicConditions.isEmpty
                                        ? 'None recorded • Tap to configure organ risks'
                                        : '${_chronicConditions.length} active conditions recorded • Tap to view & edit',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _isConditionsExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.textSecondary(context),
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),

                // Collapsed Preview Badges
                if (!_isConditionsExpanded && _chronicConditions.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _chronicConditions.map((condition) {
                          final displayText = _isPrivacyMaskActive ? '••••••••' : condition;
                          return Chip(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: isDark ? const Color(0xFF134E4A) : const Color(0xFFF0FDFA),
                            side: BorderSide(color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF99F6E4)),
                            avatar: const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF0D9488)),
                            label: Text(
                              displayText,
                              style: TextStyle(
                                color: isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],

                // Expanded Conditions Selector
                if (_isConditionsExpanded) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select all active chronic medical conditions, organ risks, or clinical states:',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _commonChronicConditions.map((cond) {
                            final tag = cond['tag'] as String;
                            final title = cond['title'] as String;
                            final icon = cond['icon'] as IconData;
                            final isSel = _chronicConditions.contains(tag);
                            return FilterChip(
                              avatar: Icon(
                                icon,
                                size: 16,
                                color: isSel ? const Color(0xFF0F766E) : AppTheme.textSecondary(context),
                              ),
                              label: Text(title),
                              selected: isSel,
                              selectedColor: const Color(0xFFCCFBF1),
                              checkmarkColor: const Color(0xFF0F766E),
                              labelStyle: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                color: isSel ? const Color(0xFF0F766E) : AppTheme.textPrimary(context),
                              ),
                              onSelected: (_) => _toggleChronicCondition(tag),
                            );
                          }).toList(),
                        ),
                        if (_chronicConditions.any((c) => !_commonChronicConditions.any((cc) => cc['tag'] == c))) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Custom Conditions:',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _chronicConditions
                                .where((c) => !_commonChronicConditions.any((cc) => cc['tag'] == c))
                                .map((customTag) => InputChip(
                                      avatar: const Icon(Icons.star_rounded, size: 14, color: Color(0xFF0D9488)),
                                      label: Text(customTag),
                                      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                                      backgroundColor: const Color(0xFFCCFBF1),
                                      deleteIconColor: const Color(0xFF0F766E),
                                      onDeleted: () => _toggleChronicCondition(customTag),
                                    ))
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _customConditionController,
                                decoration: const InputDecoration(
                                  hintText: 'Add custom condition (e.g. Epilepsy, G6PD)',
                                  prefixIcon: Icon(Icons.add_circle_outline_rounded, size: 18),
                                  isDense: true,
                                ),
                                onSubmitted: _addCustomChronicCondition,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.add_rounded),
                              onPressed: () => _addCustomChronicCondition(_customConditionController.text),
                              tooltip: 'Add Condition',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Explicit Save Button at bottom of Profile & Routine Card
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveProfile,
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Save Profile & Routine'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ==========================================
        // 2. USER SETTINGS & PREFERENCES GROUP (Collapsible)
        // ==========================================
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.cardBorder(context)),
            boxShadow: AppTheme.softShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Settings Header Row (Tap to expand/collapse)
              InkWell(
                onTap: () {
                  setState(() {
                    _isSettingsCardExpanded = !_isSettingsCardExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'User Settings & Preferences',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isSettingsCardExpanded
                                  ? 'Tap to collapse settings'
                                  : '${currentThemeMode.name.toUpperCase()} • ${(fontScale * 100).toInt()}% Scale • ${currentPalette.label} • Tap to expand',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _isSettingsCardExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.textSecondary(context),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),

              // Expanded Settings Content
              if (_isSettingsCardExpanded) ...[
                Divider(height: 1, color: AppTheme.cardBorder(context)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Appearance & Theme Section
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
                        'Select between High-Contrast Light and Eye-Care Night Dark theme.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
                      ),
                      const SizedBox(height: 12),
                      // Theme Mode Selector
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode_rounded),
                              label: Text('Light'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode_rounded),
                              label: Text('Dark'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(Icons.brightness_auto_rounded),
                              label: Text('System'),
                            ),
                          ],
                          selected: {currentThemeMode},
                          onSelectionChanged: (set) {
                            ref.read(themeNotifierProvider.notifier).setThemeMode(set.first);
                          },
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Theme Palette Style Section
                      Text(
                        'Color Palette Style',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: AppPalette.values.map((pal) {
                            final isSelected = currentPalette == pal;
                            final palColor = isDark ? pal.darkPrimary : pal.primary;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                avatar: CircleAvatar(
                                  radius: 6,
                                  backgroundColor: palColor,
                                ),
                                label: Text(pal.label),
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.textPrimary(context),
                                ),
                                selected: isSelected,
                                selectedColor: palColor,
                                backgroundColor: AppTheme.surfaceVariant(context),
                                side: BorderSide(
                                  color: isSelected
                                      ? palColor
                                      : AppTheme.cardBorder(context),
                                ),
                                onSelected: (_) {
                                  ref.read(paletteNotifierProvider.notifier).setPalette(pal);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Font Size & Text Scaling (GUARANTEED ZERO OVERFLOW AT 145%)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Font Size & Text Scaling',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
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
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enlarge typography throughout the application for effortless reading.',
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
                      // Horizontal Scroll for Font Presets
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildFontPresetChip(label: 'Compact (90%)', scale: 0.90, current: fontScale),
                            const SizedBox(width: 6),
                            _buildFontPresetChip(label: 'Standard (100%)', scale: 1.00, current: fontScale),
                            const SizedBox(width: 6),
                            _buildFontPresetChip(label: 'Comfort (115%)', scale: 1.15, current: fontScale),
                            const SizedBox(width: 6),
                            _buildFontPresetChip(label: 'Large (130%)', scale: 1.30, current: fontScale),
                            const SizedBox(width: 6),
                            _buildFontPresetChip(label: 'X-Large (145%)', scale: 1.45, current: fontScale),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Device Calendar & Health Synchronization
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(
                            Icons.sync_alt_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Device Calendar & Health App Link',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary(context),
                                  ),
                                ),
                                Text(
                                  'Link with native local calendar & Samsung Health / Health Connect.',
                                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final res = await ref.read(deviceIntegrationServiceProvider).openCalendar();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res ? 'Opened Device Calendar' : 'Device Calendar linked.'),
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.calendar_month_rounded, size: 16),
                              label: const Text('Device Calendar', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final res = await ref.read(deviceIntegrationServiceProvider).openHealthApp();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res ? 'Launched Device Health App' : 'Opened Health App link.'),
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.favorite_rounded, size: 16),
                              label: const Text('Health App', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Reminders, Sound & Haptics Section
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(
                            Icons.notifications_active_rounded,
                            color: Theme.of(context).colorScheme.primary,
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
                                  'Haptic rhythm: [0, 350ms, 150ms, 350ms, 650ms]',
                                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await ref.read(notificationServiceProvider).showTestNotification();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('🔔 Test alarm triggered with audible chime & vibration!'),
                                backgroundColor: Theme.of(context).colorScheme.primary,
                              ),
                            );
                          }
                        },
                        icon: Icon(Icons.alarm_rounded, color: Theme.of(context).colorScheme.primary),
                        label: Text(
                          'Test Notification, Sound & Vibration',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Lockscreen Quick Access View Selector
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(
                            Icons.screen_lock_portrait_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lockscreen Quick Access View',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary(context),
                                  ),
                                ),
                                Text(
                                  'Controls what view opens from lockscreen widget or shortcut without unlocking device',
                                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _lockscreenDefaultView,
                        decoration: const InputDecoration(
                          labelText: 'Default Lockscreen Action',
                          prefixIcon: Icon(Icons.touch_app_rounded),
                        ),
                        dropdownColor: AppTheme.cardColor(context),
                        items: const [
                          DropdownMenuItem(value: 'card', child: Text('Emergency Medical ID Card (Recommended)')),
                          DropdownMenuItem(value: 'medications', child: Text('Upcoming Dose Schedule')),
                          DropdownMenuItem(value: 'dual', child: Text('Dual View (Card + Medications)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _lockscreenDefaultView = val);
                          }
                        },
                      ),

                      // Explicit Save Settings Button at bottom of card
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saveSettings,
                          icon: const Icon(Icons.check_circle_rounded, size: 18),
                          label: const Text('Save Settings & Preferences'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
          const SizedBox(height: 16),

          // Emergency Medical ID Card Section (JPG format)
          _buildEmergencyCardSection(context),
          const SizedBox(height: 16),

          // Calendar Sync Section
          _buildCalendarSyncCard(context),
          const SizedBox(height: 16),

          // About MediSync & Developer Card (Collapsible)
          _buildAboutDeveloperCard(context),
          const SizedBox(height: 20),

          // Bottom Save Button (Only shown when changes are pending)
          if (hasChanges) ...[
            ElevatedButton(
              onPressed: _saveProfile,
              child: const Text('Save Profile & Routine'),
            ),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _buildEmergencyCardSection(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final medications = ref.watch(medicationsNotifierProvider);
    final activeCount = medications.where((m) => !m.isDiscontinued).length;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
          width: 1.5,
        ),
        boxShadow: AppTheme.softShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
            child: Row(
              children: [
                const Icon(Icons.emergency_rounded, color: Color(0xFFDC2626), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Emergency Medical ID Card',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      Text(
                        'Instant access for paramedics, emergency rooms & first responders',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your vital safety information (Blood Type: $_bloodType, Health ID, ${_allergies.length} Critical Allergies, ${_chronicConditions.length} Chronic Conditions, $activeCount Active Medications) is prepared for immediate access.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary(context),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.credit_card_rounded, size: 20),
                    label: const Text(
                      'View & Share Emergency Card (JPG)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      final profile = ref.read(profileNotifierProvider);
                      showEmergencyCardDialog(
                        context,
                        profile: profile.copyWith(
                          name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : profile.name,
                          dateOfBirth: _dateOfBirth,
                          bloodType: _bloodType,
                          healthId: _healthIdController.text.trim().isNotEmpty ? _healthIdController.text.trim() : null,
                          gender: _gender,
                          allergies: _allergies,
                          chronicConditions: _chronicConditions,
                          weightKg: _currentWeight,
                          heightCm: _currentHeight,
                          profileImagePath: _profileImagePath,
                          lockscreenDefaultView: _lockscreenDefaultView,
                        ),
                        medications: medications,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarSyncCard(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final medications = ref.watch(medicationsNotifierProvider);
    final activeMeds = medications.where((m) => !m.isDiscontinued).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFBFDBFE),
          width: 1.5,
        ),
        boxShadow: AppTheme.softShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            color: isDark ? const Color(0xFF0F2338) : const Color(0xFFEFF6FF),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Device Calendar Synchronization',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      Text(
                        'Export doses directly into your phone’s native calendar',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sync all active medication schedules (${activeMeds.length} active) to your device calendar (Google Calendar / Samsung Calendar) with recurring notifications.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary(context),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.sync_rounded, size: 20),
                    label: const Text(
                      'Sync Active Meds to Device Calendar',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final res = await ref.read(deviceIntegrationServiceProvider).syncMedicationsToCalendar(activeMeds);
                      if (!context.mounted) return;
                      if (res.success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✓ Successfully synced ${res.eventsCreated} medication event(s) to phone calendar!'),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res.message),
                            backgroundColor: AppTheme.warningAmber,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutDeveloperCard(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.cardBorder(context)),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Tap to expand/collapse)
          InkWell(
            onTap: () {
              setState(() {
                _isAboutCardExpanded = !_isAboutCardExpanded;
              });
            },
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: isDark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.info_outline_rounded, color: primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'About MediSync & Developer',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'v1.6.2',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _isAboutCardExpanded
                              ? 'Abdalaziz Adil Badawi • Tap to collapse'
                              : 'Abdalaziz Adil Badawi • Tap to expand',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isAboutCardExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textSecondary(context),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),

          if (_isAboutCardExpanded) ...[
            Divider(height: 1, color: AppTheme.cardBorder(context)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Developer Bio Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.cardBorder(context)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: primary.withValues(alpha: 0.2),
                          child: Icon(Icons.code_rounded, color: primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Abdalaziz Adil Badawi Mohamed',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Lead Software & Mobile Engineer',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Dedicated to building clinical-grade, privacy-first mobile health utilities that respect personal autonomy and data ownership.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.textSecondary(context),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // GitHub Repository Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        ref.read(deviceIntegrationServiceProvider).openBrowserUrl(
                          'https://github.com/Abdalaziz-Badawi/MediSync',
                        );
                      },
                      icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                      label: const Text('GitHub: @Abdalaziz-Badawi / MediSync'),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Project Architecture & File Management Viewer
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.cardBorder(context)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showArchitectureDialog(context),
                    icon: Icon(Icons.folder_special_rounded, color: primary, size: 18),
                    label: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Project Architecture & Clean Organization',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textPrimary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textMuted(context)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Legal Links: Terms of Use & Privacy Policy
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppTheme.cardBorder(context)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _showTermsDialog(context),
                          icon: Icon(Icons.gavel_rounded, size: 16, color: primary),
                          label: Text(
                            'Terms of Use',
                            style: TextStyle(fontSize: 11.5, color: AppTheme.textPrimary(context)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppTheme.cardBorder(context)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _showPrivacyPolicyDialog(context),
                          icon: Icon(Icons.verified_user_rounded, size: 16, color: primary),
                          label: Text(
                            'Privacy Policy',
                            style: TextStyle(fontSize: 11.5, color: AppTheme.textPrimary(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showArchitectureDialog(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151E2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.account_tree_rounded, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            const Text('Architecture & Structure', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MediSync Modular Feature Architecture:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(ctx)),
              ),
              const SizedBox(height: 10),
              _buildArchItem(ctx, '📁 lib/core/models', 'Medication, Condition, SideEffect, UserProfile, SafetyFlag'),
              _buildArchItem(ctx, '📁 lib/core/services', 'StorageService (Hive), SchedulerService, RoutineInferenceService, StreakService, DeviceIntegrationService'),
              _buildArchItem(ctx, '📁 lib/core/theme', 'AppTheme with 10 clinical palettes, soft & elevated shadow hierarchy'),
              _buildArchItem(ctx, '📁 lib/features/homeboard', 'Today schedule, NextDoseCountdownCard, Duolingo AdherenceStreakCard'),
              _buildArchItem(ctx, '📁 lib/features/medications', 'CRUD, discontinuation lifecycle, debounced allergy checks'),
              _buildArchItem(ctx, '📁 lib/features/records', 'Multi-format export (TXT, MD, HTML, XML, DOC, PDF), adherence analytics'),
              _buildArchItem(ctx, '📁 lib/features/profile', 'Daily routine setup, phone calendar sync, developer about'),
              _buildArchItem(ctx, '📁 lib/features/splash', 'Pulse cross logo animation, smooth start experience'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildArchItem(BuildContext ctx, String folder, String details) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(folder, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12, color: Theme.of(ctx).colorScheme.primary)),
          Text(details, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(ctx))),
        ],
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151E2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Terms of Use', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(
            '1. Informational Health Tool: MediSync is designed solely as an assistive scheduling and adherence tracking companion.\n\n'
            '2. Not Medical Advice: MediSync does not provide clinical diagnosis, medical treatment prescriptions, or definitive pharmacology consultations. Always consult your licensed physician or pharmacist for medical decisions.\n\n'
            '3. User Responsibility: You are responsible for verifying your prescription dosages and taking medications in accordance with your healthcare provider\'s orders.\n\n'
            '4. On-Device Autonomy: All data remains stored solely on your physical device hardware under your exclusive control.',
            style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary(ctx), height: 1.4),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('I Understand')),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151E2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Privacy Policy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(
            '1. 100% On-Device Storage: All prescription records, dosages, timings, intake histories, and allergy profiles are stored strictly within local Hive encrypted storage on this device.\n\n'
            '2. Zero Remote Telemetry: MediSync makes zero network requests to any remote cloud servers. No personal identifiable health information (PHI) is ever transmitted.\n\n'
            '3. External Lookups: Public drug monograph lookups query official medical databases (e.g. Drugs.com / FDA) using ONLY the generic medicine name, with zero patient identifiers attached.\n\n'
            '4. Complete Erasure: Deleting a medication or clearing app data permanently removes all associated records from memory.',
            style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary(ctx), height: 1.4),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Accept & Close')),
        ],
      ),
    );
  }

  Widget _buildFontPresetChip({
    required String label,
    required double scale,
    required double current,
  }) {
    final isSelected = (current - scale).abs() < 0.04;
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
      selectedColor: Theme.of(context).colorScheme.primary,
      backgroundColor: AppTheme.surfaceVariant(context),
      side: BorderSide(
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : AppTheme.cardBorder(context),
      ),
      onSelected: (_) {
        ref.read(fontScaleNotifierProvider.notifier).setFontScale(scale);
      },
    );
  }

  Widget _buildRoutinePreviewChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String time,
  }) {
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppTheme.cardBorder(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary(context),
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary(context),
            ),
          ),
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
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              icon,
              color: primary,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                time,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textMuted(context),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
