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
  bool _isOngoing = true;
  List<String> _scheduledTimes = ['08:00'];
  String _clinicalRationale = '';

  // Conditions & Side Effects (Now placed BEFORE scheduled times!)
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
      _scheduledTimes = List.from(med.scheduledTimes);
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
    );

    setState(() {
      _scheduledTimes = result.times;
      _clinicalRationale = result.rationale;
    });

    if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Studied Schedule generated: ${result.times.join(", ")}',
          ),
          backgroundColor: AppTheme.primaryTeal,
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

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
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
      doseLog: widget.medicationToEdit?.doseLog ?? {},
    );

    ref.read(medicationsNotifierProvider.notifier).addOrUpdate(med);
    Navigator.of(context).pop();
  }

  String _conditionLabel(ConditionType type) {
    switch (type) {
      case ConditionType.meal:
        return 'Eat Food / Meal';
      case ConditionType.emptyStomach:
        return 'Empty Stomach';
      case ConditionType.sleep:
        return 'Go to Sleep';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Medication' : 'Add Medication'),
        actions: [
          TextButton.icon(
            onPressed: _saveMedication,
            icon: const Icon(Icons.check, color: AppTheme.primaryTeal),
            label: const Text(
              'Save',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTeal,
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
                      ? const Color(0xFFFFEBEE)
                      : const Color(0xFFFFF8E1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: flag.severity == FlagSeverity.critical
                          ? AppTheme.dangerRed
                          : AppTheme.warningAmber,
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
                              ? AppTheme.dangerRed
                              : AppTheme.warningAmber,
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
                                      ? AppTheme.dangerRed
                                      : const Color(0xFF8D6E63),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                flag.message,
                                style: const TextStyle(fontSize: 12, height: 1.3),
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
            const Text(
              '1. Medication Identification',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Search medical database to auto-populate conditions & verify allergy safety.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),

            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Medicine Name *',
                hintText: 'Type to search (e.g. Panadol, Amoxicillin, Metformin)',
                prefixIcon: const Icon(Icons.search),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredDatabaseResults.length.clamp(0, 4),
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final item = _filteredDatabaseResults[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.medical_services_outlined,
                          color: AppTheme.primaryTeal),
                      title: Text(
                        '${item.name} (${item.genericName})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${item.drugClass} • Dosages: ${item.commonDosages.join(", ")}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
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
                  color: const Color(0xFFE0F2F1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppTheme.primaryTeal, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Matched: ${_matchedTemplate!.name} (${_matchedTemplate!.drugClass})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryTeal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dosageController,
                    decoration: const InputDecoration(
                      labelText: 'Dosage *',
                      hintText: 'e.g. 500 mg, 1 tablet',
                      prefixIcon: Icon(Icons.fitness_center),
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
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: MedicationForm.values.map((f) {
                      return DropdownMenuItem(
                        value: f,
                        child: Text(
                          f.name[0].toUpperCase() + f.name.substring(1),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedForm = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section 2: Conditions (Before & After Taking)
            // User requested: "the condition and instructions should come before the Scheduled times"
            const Text(
              '2. Pre & Post Conditions (Usage Instructions)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Specify physical actions or states needed before or after taking this medicine.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Before Taking (Pre-conditions):',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF0F172A),
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
                    const Divider(height: 24),
                    const Text(
                      'After Taking (Post-conditions & Immediate States):',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF0F172A),
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
            const Text(
              '3. Known Side Effects',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Drowsiness maps dose to bedtime; stomach distress maps dose after meals.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
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
                      selectedColor:
                          AppTheme.accentCyan.withValues(alpha: 0.2),
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

            // Section 4: Studied Smart Scheduled Times
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '4. Schedule & Dose Timing',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        DropdownButton<int>(
                          value: _timesPerDay,
                          items: [1, 2, 3, 4, 5].map((n) {
                            return DropdownMenuItem(
                              value: n,
                              child: Text('$n time${n > 1 ? 's' : ''} / day'),
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
                      icon: const Icon(
                        Icons.auto_awesome,
                        color: AppTheme.primaryTeal,
                      ),
                      label: const Text(
                        'Re-calculate Studied Timing',
                        style: TextStyle(color: AppTheme.primaryTeal),
                      ),
                    ),

                    if (_clinicalRationale.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.science_outlined,
                                    color: AppTheme.successGreen, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Studied Clinical Rationale:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Color(0xFF166534),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _clinicalRationale,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF14532D),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Text(
                      'Scheduled Times (tap to customize):',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_scheduledTimes.length, (i) {
                        return ActionChip(
                          avatar: const Icon(Icons.access_time, size: 16),
                          label: Text(
                            'Dose ${i + 1}: ${_scheduledTimes[i]}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _pickTimeForIndex(i),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Section 5: Duration & Refills
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '5. Duration & Refills',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ongoing Medication (No fixed end date)'),
                      value: _isOngoing,
                      onChanged: (val) {
                        setState(() => _isOngoing = val);
                      },
                    ),
                    if (!_isOngoing) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _durationDaysController,
                        keyboardType: TextInputType.number,
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

            // Section 6: Doctor & Pharmacist Notes
            TextFormField(
              controller: _notesController,
              maxLines: 3,
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
}
