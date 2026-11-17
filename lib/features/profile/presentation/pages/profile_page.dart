import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medisync/core/models/user_profile.dart';
import 'package:medisync/core/services/notification_service.dart';
import 'package:medisync/core/services/storage_service.dart';
import 'package:medisync/core/theme/app_theme.dart';
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

  // Collapsible Allergies Section State (Starts collapsed by default)
  bool _isAllergiesExpanded = false;

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

  bool get _hasChanges {
    final profile = ref.read(profileNotifierProvider);
    if (_nameController.text.trim() != profile.name) return true;
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
        backgroundColor: AppTheme.isDark(context) ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
      ),
    );
  }

  String _maskText(String text) {
    if (!_isPrivacyMaskActive) return text;
    if (text.isEmpty) return '••••••';
    return '${text[0]}${'•' * (text.length - 1).clamp(4, 10)}';
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
                    icon: const Icon(Icons.close),
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
                    Icons.person_outline,
                    color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                  ),
                ),
                onChanged: (_) => setState(() {}),
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
          // Save button only appears if changes have been made
          if (hasChanges)
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
          // 1. COMPACT USER ACCOUNT CARD (Tap to Edit Details)
          // ==========================================
          InkWell(
            onTap: _openEditProfileDialog,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.cardColor(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.cardBorder(context)),
                boxShadow: AppTheme.softShadow(context),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
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
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.security,
                              size: 13,
                              color: isDark ? AppTheme.successGreenLight : AppTheme.successGreen,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Offline Encrypted Local Storage (100% Private)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ==========================================
          // 2. USER SETTINGS & PREFERENCES GROUP
          // ==========================================
          _buildSectionHeader(
            icon: Icons.tune_rounded,
            title: 'User Settings & Preferences',
            subtitle: 'Appearance themes, overflow-proof text scaling, and alerts',
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.cardBorder(context)),
              boxShadow: AppTheme.softShadow(context),
            ),
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
                // Overflow-Safe Theme Selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SegmentedButton<ThemeMode>(
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
                ),
                const SizedBox(height: 18),

                // Theme Palette Suggestion Section
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
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: CircleAvatar(
                            radius: 6,
                            backgroundColor: pal.primary,
                          ),
                          label: Text(pal.label),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
                            ref.read(paletteNotifierProvider.notifier).setPalette(pal);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Font Size & Text Scaling (Guaranteed Overflow-Safe at ALL Scales 85%-145%)
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
                // Horizontal Scroll for Font Presets (Guarantees zero overflow at all scale percentages)
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

                // Reminders, Sound & Haptics Section
                const Divider(height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      Icons.notifications_active_outlined,
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
          const SizedBox(height: 20),

          // ==========================================
          // 3. DAILY ROUTINE & MEAL SCHEDULE (Outside Settings)
          // ==========================================
          _buildSectionHeader(
            icon: Icons.access_time_filled_rounded,
            title: 'Daily Routine & Meal Schedule',
            subtitle: 'Smart engine aligns doses 20 min post-meal for comfortable absorption',
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.cardBorder(context)),
              boxShadow: AppTheme.softShadow(context),
            ),
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
          const SizedBox(height: 20),

          // ==========================================
          // 4. COLLAPSIBLE ALLERGIES & EXCIPIENTS SECTION (Outside Settings)
          // ==========================================
          _buildSectionHeader(
            icon: Icons.health_and_safety_rounded,
            title: 'Allergies & Excipient Sensitivities',
            subtitle: 'Clinical screening against drugs, food fillers (lactose), additives & latex',
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.cardBorder(context)),
              boxShadow: AppTheme.softShadow(context),
            ),
            child: Column(
              children: [
                // Collapsible Header Row
                InkWell(
                  onTap: () {
                    setState(() {
                      _isAllergiesExpanded = !_isAllergiesExpanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.shield_rounded,
                            size: 20,
                            color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_allergies.length} Active Safety Trigger${_allergies.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                              Text(
                                _isAllergiesExpanded
                                    ? 'Tap to collapse allergy triggers'
                                    : 'Tap to view and manage all allergy triggers',
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
                          size: 26,
                        ),
                      ],
                    ),
                  ),
                ),

                // Collapsed Preview Pills (always visible when collapsed)
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

                // Expanded Full Taxonomy Selector
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
              ],
            ),
          ),
          const SizedBox(height: 24),

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
