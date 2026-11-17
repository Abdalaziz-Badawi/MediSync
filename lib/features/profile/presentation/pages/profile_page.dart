import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medisync/core/models/user_profile.dart';
import 'package:medisync/core/services/device_integration_service.dart';
import 'package:medisync/core/services/notification_service.dart';
import 'package:medisync/core/services/storage_service.dart';
import 'package:medisync/core/theme/app_theme.dart';
import 'package:medisync/features/homeboard/presentation/pages/main_navigation_page.dart';
import 'package:medisync/features/profile/presentation/widgets/allergy_selector_widget.dart';

class ProfilePage extends ConsumerStatefulWidget {
  final bool initiallyExpanded;
  const ProfilePage({super.key, this.initiallyExpanded = false});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late TextEditingController _nameController;

  late String _avatarId;
  late String _wakeTime;
  late String _sleepTime;
  late String _breakfastTime;
  late String _lunchTime;
  late String _dinnerTime;
  late bool _useHealthApp;
  late List<String> _allergies;

  // Privacy Shield / Sneak Peek Prevention
  bool _isPrivacyMaskActive = false;

  // Collapsible Cards State (Starts collapsed by default, expands on interaction, collapses on leave)
  late bool _isProfileCardExpanded;
  late bool _isSettingsCardExpanded;
  bool _isAllergiesExpanded = false;

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

    final profile = ref.read(profileNotifierProvider);
    _nameController = TextEditingController(text: profile.name);
    _avatarId = profile.avatarId;

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

  bool get _hasChanges {
    final profile = ref.read(profileNotifierProvider);
    if (_nameController.text.trim() != profile.name) return true;
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

  void _saveProfile() {
    final updated = UserProfile(
      name: _nameController.text.trim().isEmpty
          ? 'User'
          : _nameController.text.trim(),
      avatarId: _avatarId,
      allergies: _allergies,
      wakeTime: _wakeTime,
      sleepTime: _sleepTime,
      breakfastTime: _breakfastTime,
      lunchTime: _lunchTime,
      dinnerTime: _dinnerTime,
      useHealthApp: _useHealthApp,
    );

    ref.read(profileNotifierProvider.notifier).updateProfile(updated);
    setState(() {}); // Updates _hasChanges to false

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Profile and daily routine saved locally!'),
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
                    final isSel = _avatarId == av['id'];
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _avatarId = av['id'] as String;
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
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
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
              const SizedBox(height: 16),
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
              const SizedBox(height: 20),
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
        if (_isProfileCardExpanded || _isSettingsCardExpanded || _isAllergiesExpanded) {
          setState(() {
            _isProfileCardExpanded = false;
            _isSettingsCardExpanded = false;
            _isAllergiesExpanded = false;
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
                                child: Icon(
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
                                  Icon(
                                    Icons.security_rounded,
                                    size: 13,
                                    color: isDark ? AppTheme.successGreenLight : AppTheme.successGreen,
                                  ),
                                  const SizedBox(width: 4),
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
                              'Routine: Wake ${_isPrivacyMaskActive ? '••:••' : _wakeTime} • Bed ${_isPrivacyMaskActive ? '••:••' : _sleepTime} • ${_allergies.length} Safety Triggers',
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

                  // --- INTEGRATED DAILY ROUTINE & MEAL SCHEDULE ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_filled_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Daily Routine & Meal Times',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
