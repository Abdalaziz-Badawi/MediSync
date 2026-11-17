import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medisync/core/data/medicines_database.dart';
import 'package:medisync/core/models/condition.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/models/safety_flag.dart';
import 'package:medisync/core/models/side_effect.dart';
import 'package:medisync/core/services/scheduler_service.dart';
import 'package:medisync/core/services/storage_service.dart';
import 'package:medisync/core/theme/app_theme.dart';
import 'package:uuid/uuid.dart';

class AddEditMedicationPage extends ConsumerStatefulWidget {
  final Medication? medicationToEdit;

  const AddEditMedicationPage({super.key, this.medicationToEdit});

  @override
  ConsumerState<AddEditMedicationPage> createState() =>
      _AddEditMedicationPageState();
}

class _AddEditMedicationPageState extends ConsumerState<AddEditMedicationPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _durationDaysController;
  late TextEditingController _refillsController;
  late TextEditingController _notesController;

  MedicationForm _selectedForm = MedicationForm.pill;
  int _timesPerDay = 1;
  bool _isOngoing = false; // Defaulted to false as requested
  ScheduleFrequency _frequency = ScheduleFrequency.daily;
  int _intervalDays = 2; // For everyXDays
  List<int> _monthlyDays = [1]; // For monthly / twiceMonthly
  List<String> _scheduledTimes = ['08:00'];
  String _clinicalRationale = '';
  List<CompanionMealReminder> _companionMealReminders = [];

  // Weekly Schedule: 1 = Mon, 7 = Sun
  List<int> _daysOfWeek = [1, 2, 3, 4, 5, 6, 7];

  // Conditions & Side Effects
  final Set<ConditionType> _selectedPreConditions = {};
  final Set<ConditionType> _selectedPostConditions = {};
  final Set<SideEffectType> _selectedSideEffects = {};

  List<SafetyFlag> _activeSafetyFlags = [];
  MedicineTemplate? _matchedTemplate;
  List<MedicineTemplate> _filteredDatabaseResults = [];

  @override
  void initState() {
    super.initState();
    final med = widget.medicationToEdit;
    _nameController = TextEditingController(text: med?.name ?? '');
    _dosageController = TextEditingController(text: med?.dosage ?? '');
    _durationDaysController =
        TextEditingController(text: med?.durationDays?.toString() ?? '');
    _refillsController =
        TextEditingController(text: med?.refillsRemaining?.toString() ?? '');
    _notesController = TextEditingController(text: med?.doctorNotes ?? '');

    if (med != null) {
      _selectedForm = med.form;
      _timesPerDay = med.timesPerDay;
      _isOngoing = med.isOngoing;
      _frequency = med.scheduleFrequency;
      _intervalDays = med.intervalDays ?? 2;
      _monthlyDays = List.from(med.monthlyDays);
      _scheduledTimes = List.from(med.scheduledTimes);
      _daysOfWeek = List.from(med.daysOfWeek);
      for (final c in med.preConditions) {
        _selectedPreConditions.add(c.type);
      }
      for (final c in med.postConditions) {
        _selectedPostConditions.add(c.type);
      }
      for (final s in med.sideEffects) {
        _selectedSideEffects.add(s.type);
      }
      _activeSafetyFlags = List.from(med.safetyFlags);
    }

    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _durationDaysController.dispose();
    _refillsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final query = _nameController.text.trim();
    if (query.isNotEmpty) {
      setState(() {
        _filteredDatabaseResults = MedicinesDatabase.search(query);
      });
    } else {
      setState(() {
        _filteredDatabaseResults = [];
        _matchedTemplate = null;
      });
    }
    _checkSafetyAndRecompute();
  }

  void _selectMedicineTemplate(MedicineTemplate template) {
    setState(() {
      _matchedTemplate = template;
      _nameController.text = template.name;
      _filteredDatabaseResults = [];
      _selectedForm = template.defaultForm;

      if (template.commonDosages.isNotEmpty &&
          _dosageController.text.isEmpty) {
        _dosageController.text = template.commonDosages.first;
      }

      if (_notesController.text.isEmpty &&
          template.standardInstructions.isNotEmpty) {
        _notesController.text = template.standardInstructions;
      }

      // Pre-fill studied conditions & side effects from medical database
      for (final pre in template.preConditions) {
        _selectedPreConditions.add(pre);
      }
      for (final post in template.postConditions) {
        _selectedPostConditions.add(post);
      }
      for (final effect in template.knownSideEffects) {
        _selectedSideEffects.add(effect);
      }
    });

    _checkSafetyAndRecompute();
    _generateStudiedSmartSchedule(silent: true);
  }

  void _checkSafetyAndRecompute() {
    final profile = ref.read(profileNotifierProvider);
    final allMeds = ref.read(medicationsNotifierProvider);
    final existing = allMeds
        .where((m) => m.id != widget.medicationToEdit?.id)
        .toList();

    final flags = SchedulerService.checkSafety(
      medicationName: _nameController.text,
      profile: profile,
      existingMeds: existing,
      matchedTemplate: _matchedTemplate,
    );

    setState(() {
      _activeSafetyFlags = flags;
    });
  }

  void _generateStudiedSmartSchedule({bool silent = false}) {
    final profile = ref.read(profileNotifierProvider);

    final preList = _selectedPreConditions.map((type) {
      return MedicationCondition(
        type: type,
        timing: ConditionTiming.before,
        description: type.name,
      );
    }).toList();

    final postList = _selectedPostConditions.map((type) {
      return MedicationCondition(
        type: type,
        timing: ConditionTiming.after,
        description: type.name,
      );
    }).toList();

    final sideEffectsList = _selectedSideEffects.map((type) {
      return SideEffect(
        type: type,
        description: type.name,
        scheduleHint: SideEffect.defaultHintFor(type),
      );
    }).toList();

    final result = SchedulerService.calculateSmartScheduleWithRationale(
      timesPerDay: _timesPerDay,
      profile: profile,
      sideEffects: sideEffectsList,
      preConditions: preList,
      postConditions: postList,
      medicationName: _nameController.text.trim(),
    );

    setState(() {
      _scheduledTimes = result.times;
      _clinicalRationale = result.rationale;
      _companionMealReminders = result.companionMealReminders;
    });

    if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Smart Timing Generated: ${result.times.join(", ")}',
          ),
          backgroundColor: AppTheme.isDark(context) ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
        ),
      );
    }
  }

  Future<void> _pickTimeForIndex(int index) async {
    final current = _scheduledTimes[index];
    final parts = current.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );

    final isDark = AppTheme.isDark(context);

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              hourMinuteTextStyle: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
              dayPeriodTextStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              dialTextStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              dialBackgroundColor:
                  isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              hourMinuteColor:
                  isDark ? const Color(0xFF0C4A6E) : const Color(0xFFE0F2FE),
              hourMinuteTextColor:
                  isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
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

    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        _scheduledTimes[index] = formatted;
      });
    }
  }

  void _saveMedication() {
    if (!_formKey.currentState!.validate()) return;

    final preList = _selectedPreConditions.map((type) {
      return MedicationCondition(
        type: type,
        timing: ConditionTiming.before,
        description: _conditionLabel(type),
      );
    }).toList();

    final postList = _selectedPostConditions.map((type) {
      return MedicationCondition(
        type: type,
        timing: ConditionTiming.after,
        description: _conditionLabel(type),
      );
    }).toList();

    final sideEffectsList = _selectedSideEffects.map((type) {
      return SideEffect(
        type: type,
        description: _sideEffectLabel(type),
        scheduleHint: SideEffect.defaultHintFor(type),
      );
    }).toList();

    final durationDays = _isOngoing
        ? null
        : int.tryParse(_durationDaysController.text.trim());
    final refills = int.tryParse(_refillsController.text.trim());

    final isMealLinked = _selectedPreConditions.contains(ConditionType.meal) ||
        _selectedPostConditions.contains(ConditionType.meal);

    final med = Medication(
      id: widget.medicationToEdit?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      dosage: _dosageController.text.trim(),
      form: _selectedForm,
      timesPerDay: _timesPerDay,
      scheduledTimes: _scheduledTimes,
      durationDays: durationDays,
      startDate: widget.medicationToEdit?.startDate ?? DateTime.now(),
      preConditions: preList,
      postConditions: postList,
      sideEffects: sideEffectsList,
      refillsRemaining: refills,
      refillAlertThreshold: refills != null ? 1 : null,
      doctorNotes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      safetyFlags: _activeSafetyFlags,
      daysOfWeek: _daysOfWeek.isEmpty ? const [1, 2, 3, 4, 5, 6, 7] : _daysOfWeek,
      scheduleFrequency: _frequency,
      intervalDays: _intervalDays,
      monthlyDays: _monthlyDays,
      foodRestrictions: _matchedTemplate?.foodRestrictions ?? (widget.medicationToEdit?.foodRestrictions ?? const []),
      inactiveExcipients: _matchedTemplate?.inactiveExcipients ?? (widget.medicationToEdit?.inactiveExcipients ?? const []),
      mealCondition: isMealLinked ? 'after_meal' : null,
      doseLog: widget.medicationToEdit?.doseLog ?? {},
    );

    ref.read(medicationsNotifierProvider.notifier).addOrUpdate(med);
    Navigator.of(context).pop();
  }

  String _conditionLabel(ConditionType type) {
    switch (type) {
      case ConditionType.meal:
        return 'Eat Food / Meal (Take 20m After)';
      case ConditionType.emptyStomach:
        return 'Empty Stomach (1h before)';
      case ConditionType.sleep:
        return 'Go to Sleep / Bedtime';
      case ConditionType.drinkWater:
        return 'Drink Full Glass of Water';
      case ConditionType.rest:
        return 'Rest / Lie Down';
      case ConditionType.avoidDriving:
        return 'Avoid Driving / Machinery';
      case ConditionType.custom:
        return 'Special condition';
    }
  }

  String _sideEffectLabel(SideEffectType type) {
    switch (type) {
      case SideEffectType.drowsiness:
        return 'Causes Drowsiness (Sleepy)';
      case SideEffectType.stomachUpset:
        return 'Causes Stomach Ache / Heavy';
      case SideEffectType.nausea:
        return 'Nausea';
      case SideEffectType.dizziness:
        return 'Dizziness';
      case SideEffectType.insomnia:
        return 'Insomnia / Keeps Awake';
      case SideEffectType.headache:
        return 'Headache';
      case SideEffectType.dryMouth:
        return 'Dry Mouth';
      case SideEffectType.custom:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.medicationToEdit != null;
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Medication' : 'Add Medication',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary(context),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _saveMedication,
            icon: Icon(
              Icons.check,
              color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
            ),
            label: Text(
              'Save',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Critical Allergy Alert Banner
            if (_activeSafetyFlags.isNotEmpty) ...[
              for (final flag in _activeSafetyFlags)
                Card(
                  color: flag.severity == FlagSeverity.critical
                      ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2))
                      : (isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: flag.severity == FlagSeverity.critical
                          ? (isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed)
                          : (isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber),
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: flag.severity == FlagSeverity.critical
                              ? (isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed)
                              : (isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber),
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                flag.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: flag.severity == FlagSeverity.critical
                                      ? (isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed)
                                      : (isDark ? AppTheme.warningAmberLight : const Color(0xFFB45309)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                flag.message,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.3,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],

            // Section 1: Medicine Name & Database Autocomplete
            Text(
              '1. Medication Identification',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Search medical database to auto-populate conditions & verify allergy safety.',
              style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
            ),
            const SizedBox(height: 8),

            TextFormField(
              controller: _nameController,
              style: TextStyle(color: AppTheme.textPrimary(context)),
              decoration: InputDecoration(
                labelText: 'Medicine Name *',
                hintText: 'Type to search (e.g. Panadol, Amoxicillin, Metformin)',
                prefixIcon: Icon(
                  Icons.search,
                  color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                ),
                suffixIcon: _nameController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _nameController.clear();
                        },
                      )
                    : null,
              ),
              validator: (val) => val == null || val.trim().isEmpty
                  ? 'Please enter medicine name'
                  : null,
            ),

            // Live Database Search Results Overlay
            if (_filteredDatabaseResults.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor(context),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: AppTheme.cardBorder(context)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredDatabaseResults.length.clamp(0, 4),
                  separatorBuilder: (_, index) => Divider(
                    height: 1,
                    color: AppTheme.cardBorder(context),
                  ),
                  itemBuilder: (context, i) {
                    final item = _filteredDatabaseResults[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.medical_services_outlined,
                        color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                      ),
                      title: Text(
                        '${item.name} (${item.genericName})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                      subtitle: Text(
                        '${item.drugClass} • Dosages: ${item.commonDosages.join(", ")}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: AppTheme.textMuted(context),
                      ),
                      onTap: () => _selectMedicineTemplate(item),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (_matchedTemplate != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Matched: ${_matchedTemplate!.name} (${_matchedTemplate!.drugClass})',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Clinical Food Restrictions & Dietary Precautions
              if (_matchedTemplate!.foodRestrictions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF3B1D0B) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.restaurant_menu_rounded,
                            color: isDark ? AppTheme.warningAmberLight : const Color(0xFFB45309),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Suggested Food & Dietary Precautions:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? AppTheme.warningAmberLight : const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (final r in _matchedTemplate!.foodRestrictions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $r',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF78350F),
                              height: 1.3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],

            const SizedBox(height: 12),
            // Responsive Overflow-Safe Dosage & Form Fields
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 360;
                if (isNarrow) {
                  return Column(
                    children: [
                      TextFormField(
                        controller: _dosageController,
                        style: TextStyle(color: AppTheme.textPrimary(context)),
                        decoration: const InputDecoration(
                          labelText: 'Dosage *',
                          hintText: 'e.g. 500 mg, 1 tablet',
                          prefixIcon: Icon(Icons.fitness_center_rounded),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Enter dosage'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<MedicationForm>(
                        initialValue: _selectedForm,
                        decoration: const InputDecoration(
                          labelText: 'Form',
                          prefixIcon: Icon(Icons.category_rounded),
                        ),
                        dropdownColor: AppTheme.cardColor(context),
                        items: MedicationForm.values.map((f) {
                          return DropdownMenuItem(
                            value: f,
                            child: Text(
                              f.name[0].toUpperCase() + f.name.substring(1),
                              style: TextStyle(color: AppTheme.textPrimary(context)),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedForm = val);
                        },
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dosageController,
                        style: TextStyle(color: AppTheme.textPrimary(context)),
                        decoration: const InputDecoration(
                          labelText: 'Dosage *',
                          hintText: 'e.g. 500 mg, 1 tablet',
                          prefixIcon: Icon(Icons.fitness_center_rounded),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Enter dosage'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<MedicationForm>(
                        initialValue: _selectedForm,
                        decoration: const InputDecoration(
                          labelText: 'Form',
                          prefixIcon: Icon(Icons.category_rounded),
                        ),
                        dropdownColor: AppTheme.cardColor(context),
                        items: MedicationForm.values.map((f) {
                          return DropdownMenuItem(
                            value: f,
                            child: Text(
                              f.name[0].toUpperCase() + f.name.substring(1),
                              style: TextStyle(color: AppTheme.textPrimary(context)),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedForm = val);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Section 2: Conditions (Before & After Taking)
            Text(
              '2. Pre & Post Conditions (Usage Instructions)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Specify physical actions or meal states needed before or after taking this medicine.',
              style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Before Taking (Pre-conditions):',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ConditionType.meal,
                        ConditionType.emptyStomach,
                        ConditionType.drinkWater,
                      ].map((t) {
                        final isSelected = _selectedPreConditions.contains(t);
                        return FilterChip(
                          label: Text(_conditionLabel(t)),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedPreConditions.add(t);
                              } else {
                                _selectedPreConditions.remove(t);
                              }
                            });
                            _generateStudiedSmartSchedule(silent: true);
                          },
                        );
                      }).toList(),
                    ),
                    Divider(height: 24, color: AppTheme.cardBorder(context)),
                    Text(
                      'After Taking (Post-conditions & Immediate States):',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ConditionType.sleep,
                        ConditionType.rest,
                        ConditionType.meal,
                        ConditionType.avoidDriving,
                      ].map((t) {
                        final isSelected = _selectedPostConditions.contains(t);
                        return FilterChip(
                          label: Text(_conditionLabel(t)),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedPostConditions.add(t);
                              } else {
                                _selectedPostConditions.remove(t);
                              }
                            });
                            _generateStudiedSmartSchedule(silent: true);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Section 3: Side Effects
            Text(
              '3. Known Side Effects',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Drowsiness maps dose to bedtime; stomach distress maps dose after meals.',
              style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SideEffectType.drowsiness,
                    SideEffectType.stomachUpset,
                    SideEffectType.nausea,
                    SideEffectType.dizziness,
                    SideEffectType.insomnia,
                  ].map((s) {
                    final isSelected = _selectedSideEffects.contains(s);
                    return FilterChip(
                      label: Text(_sideEffectLabel(s)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSideEffects.add(s);
                          } else {
                            _selectedSideEffects.remove(s);
                          }
                        });
                        _generateStudiedSmartSchedule(silent: true);
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Section 4: Schedule Frequency & Recurrence
            Text(
              '4. Schedule Frequency & Recurrence',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select whether this medication is daily, specific days, bi-weekly, monthly, or as needed.',
              style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Frequency Selector (Horizontal scrolling to prevent overflow at all scales)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildFrequencyChip(
                            label: 'Daily',
                            frequency: ScheduleFrequency.daily,
                          ),
                          const SizedBox(width: 8),
                          _buildFrequencyChip(
                            label: 'Specific Days',
                            frequency: ScheduleFrequency.weekly,
                          ),
                          const SizedBox(width: 8),
                          _buildFrequencyChip(
                            label: 'Every X Days',
                            frequency: ScheduleFrequency.everyXDays,
                          ),
                          const SizedBox(width: 8),
                          _buildFrequencyChip(
                            label: 'Bi-Weekly (2 Wks)',
                            frequency: ScheduleFrequency.biWeekly,
                          ),
                          const SizedBox(width: 8),
                          _buildFrequencyChip(
                            label: 'Monthly (1x/Mo)',
                            frequency: ScheduleFrequency.monthly,
                          ),
                          const SizedBox(width: 8),
                          _buildFrequencyChip(
                            label: 'Twice a Month',
                            frequency: ScheduleFrequency.twiceMonthly,
                          ),
                          const SizedBox(width: 8),
                          _buildFrequencyChip(
                            label: 'As Needed (PRN)',
                            frequency: ScheduleFrequency.asNeeded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Sub-panel for Frequency Details
                    if (_frequency == ScheduleFrequency.daily ||
                        _frequency == ScheduleFrequency.weekly ||
                        _frequency == ScheduleFrequency.biWeekly) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _daysOfWeek.length == 7
                                  ? (_frequency == ScheduleFrequency.biWeekly ? 'Every 2 Weeks: All Days' : 'Active: Every Day')
                                  : 'Active: ${_daysOfWeek.length} days/week',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                if (_daysOfWeek.length == 7) {
                                  _daysOfWeek = [DateTime.now().weekday];
                                } else {
                                  _daysOfWeek = [1, 2, 3, 4, 5, 6, 7];
                                }
                              });
                            },
                            child: Text(
                              _daysOfWeek.length == 7 ? 'Custom Days' : 'Select All',
                              style: TextStyle(
                                color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Horizontal scroll for days guarantees zero overflow at any text scale
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _DayChip(label: 'M', dayInt: 1, selectedDays: _daysOfWeek, onChanged: _toggleDay),
                            const SizedBox(width: 8),
                            _DayChip(label: 'T', dayInt: 2, selectedDays: _daysOfWeek, onChanged: _toggleDay),
                            const SizedBox(width: 8),
                            _DayChip(label: 'W', dayInt: 3, selectedDays: _daysOfWeek, onChanged: _toggleDay),
                            const SizedBox(width: 8),
                            _DayChip(label: 'T', dayInt: 4, selectedDays: _daysOfWeek, onChanged: _toggleDay),
                            const SizedBox(width: 8),
                            _DayChip(label: 'F', dayInt: 5, selectedDays: _daysOfWeek, onChanged: _toggleDay),
                            const SizedBox(width: 8),
                            _DayChip(label: 'S', dayInt: 6, selectedDays: _daysOfWeek, onChanged: _toggleDay),
                            const SizedBox(width: 8),
                            _DayChip(label: 'S', dayInt: 7, selectedDays: _daysOfWeek, onChanged: _toggleDay),
                          ],
                        ),
                      ),
                    ] else if (_frequency == ScheduleFrequency.monthly) ...[
                      Text(
                        'Scheduled Day of Each Month:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary(context),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [1, 5, 10, 15, 20, 25, 28].map((dayNum) {
                            final isSel = _monthlyDays.contains(dayNum);
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text('Day $dayNum'),
                                selected: isSel,
                                onSelected: (_) {
                                  setState(() {
                                    _monthlyDays = [dayNum];
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ] else if (_frequency == ScheduleFrequency.twiceMonthly) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant(context),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Scheduled on the 1st and 15th of each month (~15-day intervals)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_frequency == ScheduleFrequency.everyXDays) ...[
                      Text(
                        'Select Day Interval:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary(context),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [2, 3, 4, 5, 7].map((interval) {
                            final isSel = _intervalDays == interval;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text('Every $interval Days'),
                                selected: isSel,
                                onSelected: (_) {
                                  setState(() {
                                    _intervalDays = interval;
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ] else if (_frequency == ScheduleFrequency.asNeeded) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.primaryTealLight.withValues(alpha: 0.3)
                                : AppTheme.primaryTeal.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.healing_rounded,
                                  color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'PRN / As-Needed Clinical Condition',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppTheme.textPrimary(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '• Administration Condition: Take only on demand when symptoms arise.\n• Non-intake Continuity: If asymptomatic, skip dose and mark as "Not Needed" to preserve accurate adherence records.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary(context),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Section 5: Studied Smart Scheduled Times
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '5. Dose Times & Daily Frequency',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: _timesPerDay,
                          dropdownColor: AppTheme.cardColor(context),
                          items: [1, 2, 3, 4, 5].map((n) {
                            return DropdownMenuItem(
                              value: n,
                              child: Text(
                                '$n time${n > 1 ? 's' : ''} / day',
                                style: TextStyle(color: AppTheme.textPrimary(context)),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _timesPerDay = val;
                              });
                              _generateStudiedSmartSchedule(silent: true);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _generateStudiedSmartSchedule(),
                      icon: Icon(
                        Icons.auto_awesome,
                        color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                      ),
                      label: Text(
                        'Re-calculate Meal & Routine Timing',
                        style: TextStyle(
                          color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                        ),
                      ),
                    ),

                    // Meal Alignment Advice (if companion meal reminders exist)
                    if (_companionMealReminders.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF064E3B) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF047857) : const Color(0xFFBBF7D0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.restaurant_menu,
                                  color: isDark ? AppTheme.successGreenLight : AppTheme.successGreen,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Meal Coordination Active:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isDark ? const Color(0xFFD1FAE5) : const Color(0xFF166534),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            for (final r in _companionMealReminders)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '• ${r.advice}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF14532D),
                                    height: 1.3,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],

                    if (_clinicalRationale.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.cardBorder(context)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.science_outlined,
                                  color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Clinical Scheduling Rationale:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppTheme.textPrimary(context),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _clinicalRationale,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary(context),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    Text(
                      'Scheduled Times (tap to customize):',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_scheduledTimes.length, (i) {
                        return ActionChip(
                          avatar: Icon(
                            Icons.access_time,
                            size: 16,
                            color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                          ),
                          label: Text(
                            'Dose ${i + 1}: ${_scheduledTimes[i]}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                          backgroundColor: AppTheme.surfaceVariant(context),
                          side: BorderSide(color: AppTheme.cardBorder(context)),
                          onPressed: () => _pickTimeForIndex(i),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Section 6: Duration & Refills
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '6. Duration & Refills',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Ongoing Medication (No fixed end date)',
                        style: TextStyle(color: AppTheme.textPrimary(context)),
                      ),
                      value: _isOngoing,
                      activeThumbColor: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                      onChanged: (val) {
                        setState(() => _isOngoing = val);
                      },
                    ),
                    if (!_isOngoing) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _durationDaysController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: AppTheme.textPrimary(context)),
                        decoration: const InputDecoration(
                          labelText: 'Course Duration in Days',
                          hintText: 'e.g. 5 for a 5-day antibiotic course',
                          prefixIcon: Icon(Icons.date_range),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _refillsController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: AppTheme.textPrimary(context)),
                      decoration: const InputDecoration(
                        labelText: 'Remaining Refills (optional)',
                        hintText: 'e.g. 2',
                        prefixIcon: Icon(Icons.repeat),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Section 7: Doctor & Pharmacist Notes
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              style: TextStyle(color: AppTheme.textPrimary(context)),
              decoration: const InputDecoration(
                labelText: 'Special Doctor / Pharmacist Instructions',
                hintText: 'e.g. Take with plenty of fluids, do not crush tablet.',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _saveMedication,
              child: Text(
                isEditing ? 'Update Medication' : 'Save Medication',
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencyChip({
    required String label,
    required ScheduleFrequency frequency,
  }) {
    final isSelected = _frequency == frequency;
    final isDark = AppTheme.isDark(context);

    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
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
        setState(() {
          _frequency = frequency;
        });
      },
    );
  }

  void _toggleDay(int day) {
    setState(() {
      if (_daysOfWeek.contains(day)) {
        if (_daysOfWeek.length > 1) {
          _daysOfWeek.remove(day);
        }
      } else {
        _daysOfWeek.add(day);
        _daysOfWeek.sort();
      }
    });
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final int dayInt;
  final List<int> selectedDays;
  final Function(int) onChanged;

  const _DayChip({
    required this.label,
    required this.dayInt,
    required this.selectedDays,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedDays.contains(dayInt);
    final isDark = AppTheme.isDark(context);
    final activeColor = isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal;

    return GestureDetector(
      onTap: () => onChanged(dayInt),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? activeColor : AppTheme.surfaceVariant(context),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? activeColor : AppTheme.cardBorder(context),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected
                ? (isDark ? const Color(0xFF042F2E) : Colors.white)
                : AppTheme.textSecondary(context),
          ),
        ),
      ),
    );
  }
}
