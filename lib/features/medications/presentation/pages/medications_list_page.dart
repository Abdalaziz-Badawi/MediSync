import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/models/safety_flag.dart';
import 'package:medisync/core/services/storage_service.dart';
import 'package:medisync/core/theme/app_theme.dart';
import 'package:medisync/features/medications/presentation/pages/add_edit_medication_page.dart';
import 'package:medisync/features/medications/presentation/pages/medication_details_page.dart';

class MedicationsListPage extends ConsumerStatefulWidget {
  const MedicationsListPage({super.key});

  @override
  ConsumerState<MedicationsListPage> createState() =>
      _MedicationsListPageState();
}

class _MedicationsListPageState extends ConsumerState<MedicationsListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'scheduled', 'asNeeded', 'alerts'
  String _selectedSort = 'nameAsc'; // 'nameAsc', 'nameDesc', 'dosesDesc', 'form'
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Medication> _filterAndSort(List<Medication> source) {
    var list = source.where((med) {
      // Search query filter
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final matchName = med.name.toLowerCase().contains(query);
        final matchDosage = med.dosage.toLowerCase().contains(query);
        final matchNotes =
            med.doctorNotes?.toLowerCase().contains(query) ?? false;
        if (!matchName && !matchDosage && !matchNotes) return false;
      }

      // Category filter
      switch (_selectedFilter) {
        case 'scheduled':
          return med.scheduleFrequency != ScheduleFrequency.asNeeded;
        case 'asNeeded':
          return med.scheduleFrequency == ScheduleFrequency.asNeeded;
        case 'alerts':
          return med.safetyFlags.isNotEmpty;
        case 'all':
        default:
          return true;
      }
    }).toList();

    // Sort order
    switch (_selectedSort) {
      case 'nameDesc':
        list.sort(
            (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case 'dosesDesc':
        list.sort((a, b) => b.timesPerDay.compareTo(a.timesPerDay));
        break;
      case 'form':
        list.sort((a, b) => a.form.name.compareTo(b.form.name));
        break;
      case 'nameAsc':
      default:
        list.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }

    return list;
  }

  void _enterSelectionMode([String? initialId]) {
    setState(() {
      _isSelectionMode = true;
      if (initialId != null) {
        _selectedIds.add(initialId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll(List<Medication> visibleMeds) {
    setState(() {
      _selectedIds.addAll(visibleMeds.map((m) => m.id));
    });
  }

  void _selectNone() {
    setState(() {
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _confirmDeleteSelected(List<Medication> allMeds) async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No medications selected to delete.')),
      );
      return;
    }

    final selectedMeds =
        allMeds.where((m) => _selectedIds.contains(m.id)).toList();
    final namesPreview = selectedMeds.take(3).map((m) => m.name).join(', ');
    final extraCount = selectedMeds.length - 3;
    final previewText =
        extraCount > 0 ? '$namesPreview and $extraCount more' : namesPreview;
    final count = _selectedIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count Medication${count == 1 ? '' : 's'}?'),
        content: Text(
          'Are you sure you want to permanently delete $previewText?\n\n'
          'All scheduled reminders, intake histories, and dose tracking will be removed. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final id in _selectedIds.toList()) {
        await ref.read(medicationsNotifierProvider.notifier).remove(id);
      }
      _exitSelectionMode();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Deleted $count medication${count == 1 ? '' : 's'}'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allMedications = ref.watch(medicationsNotifierProvider);
    final visibleMedications = _filterAndSort(allMedications);

    final scheduledCount = allMedications
        .where((m) => m.scheduleFrequency != ScheduleFrequency.asNeeded)
        .length;
    final asNeededCount = allMedications
        .where((m) => m.scheduleFrequency == ScheduleFrequency.asNeeded)
        .length;
    final alertCount =
        allMedications.where((m) => m.safetyFlags.isNotEmpty).length;

    final isDark = AppTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: isDark
                  ? const Color(0xFF1E293B)
                  : primary.withValues(alpha: 0.12),
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _exitSelectionMode,
                tooltip: 'Exit Selection Mode',
              ),
              title: Text(
                '${_selectedIds.length} Selected',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => _selectAll(visibleMedications),
                  child: Text(
                    'Select All',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _selectNone,
                  child: Text(
                    'Select None',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_forever_rounded,
                      color: AppTheme.dangerRed),
                  tooltip: 'Delete Selected',
                  onPressed: () =>
                      _confirmDeleteSelected(allMedications),
                ),
              ],
            )
          : AppBar(
              title: Text(
                'My Medications',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              actions: [
                // Sort Menu
                PopupMenuButton<String>(
                  icon: Icon(Icons.sort_rounded,
                      color: AppTheme.textPrimary(context)),
                  tooltip: 'Sort Medications',
                  color: AppTheme.cardColor(context),
                  onSelected: (val) {
                    setState(() {
                      _selectedSort = val;
                    });
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'nameAsc',
                      child: Row(
                        children: [
                          Icon(Icons.sort_by_alpha_rounded,
                              size: 18,
                              color: _selectedSort == 'nameAsc'
                                  ? primary
                                  : AppTheme.textSecondary(context)),
                          const SizedBox(width: 10),
                          Text(
                            'Name (A → Z)',
                            style: TextStyle(
                              fontWeight: _selectedSort == 'nameAsc'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: _selectedSort == 'nameAsc'
                                  ? primary
                                  : AppTheme.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'nameDesc',
                      child: Row(
                        children: [
                          Icon(Icons.sort_by_alpha_rounded,
                              size: 18,
                              color: _selectedSort == 'nameDesc'
                                  ? primary
                                  : AppTheme.textSecondary(context)),
                          const SizedBox(width: 10),
                          Text(
                            'Name (Z → A)',
                            style: TextStyle(
                              fontWeight: _selectedSort == 'nameDesc'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: _selectedSort == 'nameDesc'
                                  ? primary
                                  : AppTheme.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'dosesDesc',
                      child: Row(
                        children: [
                          Icon(Icons.repeat_rounded,
                              size: 18,
                              color: _selectedSort == 'dosesDesc'
                                  ? primary
                                  : AppTheme.textSecondary(context)),
                          const SizedBox(width: 10),
                          Text(
                            'Doses / Day (High → Low)',
                            style: TextStyle(
                              fontWeight: _selectedSort == 'dosesDesc'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: _selectedSort == 'dosesDesc'
                                  ? primary
                                  : AppTheme.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'form',
                      child: Row(
                        children: [
                          Icon(Icons.category_rounded,
                              size: 18,
                              color: _selectedSort == 'form'
                                  ? primary
                                  : AppTheme.textSecondary(context)),
                          const SizedBox(width: 10),
                          Text(
                            'Form / Type',
                            style: TextStyle(
                              fontWeight: _selectedSort == 'form'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: _selectedSort == 'form'
                                  ? primary
                                  : AppTheme.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Enter Selection Mode Button
                IconButton(
                  icon: Icon(Icons.checklist_rounded,
                      color: AppTheme.textPrimary(context)),
                  tooltip: 'Select Medications to Delete',
                  onPressed: allMedications.isEmpty
                      ? null
                      : () => _enterSelectionMode(),
                ),
              ],
            ),
      body: allMedications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.medication_liquid_rounded,
                    size: 80,
                    color: AppTheme.textMuted(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No medications added yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the button below to add your first medicine',
                    style: TextStyle(color: AppTheme.textSecondary(context)),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddEditMedicationPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Medication'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Filter & Search Controls Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  child: Column(
                    children: [
                      // Search Bar
                      TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search by name, dosage, or note...',
                          hintStyle: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textMuted(context)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded,
                                      size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          filled: true,
                          fillColor: AppTheme.cardColor(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: AppTheme.cardBorder(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: AppTheme.cardBorder(context)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Filter Chips Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(
                              label: 'All (${allMedications.length})',
                              value: 'all',
                              isSelected: _selectedFilter == 'all',
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'Scheduled ($scheduledCount)',
                              value: 'scheduled',
                              isSelected: _selectedFilter == 'scheduled',
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'As Needed ($asNeededCount)',
                              value: 'asNeeded',
                              isSelected: _selectedFilter == 'asNeeded',
                            ),
                            if (alertCount > 0) ...[
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                label: 'Alerts ($alertCount)',
                                value: 'alerts',
                                isSelected: _selectedFilter == 'alerts',
                                isAlert: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Medication List
                Expanded(
                  child: visibleMedications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.filter_alt_off_rounded,
                                size: 52,
                                color: AppTheme.textMuted(context),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No matching medications found',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Try clearing your search query or filter chip',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppTheme.textSecondary(context)),
                              ),
                              const SizedBox(height: 14),
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _selectedFilter = 'all';
                                  });
                                },
                                child: const Text('Reset Filters'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 165),
                          itemCount: visibleMedications.length,
                          itemBuilder: (context, index) {
                            final med = visibleMedications[index];
                            final isSelected = _selectedIds.contains(med.id);
                            return _MedicationCard(
                              medication: med,
                              isSelectionMode: _isSelectionMode,
                              isSelected: isSelected,
                              onToggleSelect: () => _toggleSelection(med.id),
                              onEnterSelection: () =>
                                  _enterSelectionMode(med.id),
                            );
                          },
                        ),
                ),
              ],
            ),

      // Smart Clearance Floating Action Button
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 92, right: 8),
          child: _isSelectionMode
              ? FloatingActionButton.extended(
                  elevation: 4,
                  backgroundColor: _selectedIds.isEmpty
                      ? Colors.grey
                      : AppTheme.dangerRed,
                  foregroundColor: Colors.white,
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () => _confirmDeleteSelected(allMedications),
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: Text('Delete (${_selectedIds.length})'),
                )
              : FloatingActionButton.extended(
                  elevation: 4,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddEditMedicationPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Medicine'),
                ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required bool isSelected,
    bool isAlert = false,
  }) {
    final isDark = AppTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;

    Color bg;
    Color border;
    Color textColor;

    if (isSelected) {
      if (isAlert) {
        bg = isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
        border = isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed;
        textColor = isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed;
      } else {
        bg = primary.withValues(alpha: isDark ? 0.25 : 0.14);
        border = primary;
        textColor = primary;
      }
    } else {
      bg = AppTheme.cardColor(context);
      border = AppTheme.cardBorder(context);
      textColor = AppTheme.textSecondary(context);
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: isSelected ? 1.5 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class _MedicationCard extends ConsumerWidget {
  final Medication medication;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onToggleSelect;
  final VoidCallback onEnterSelection;

  const _MedicationCard({
    required this.medication,
    this.isSelectionMode = false,
    this.isSelected = false,
    required this.onToggleSelect,
    required this.onEnterSelection,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = AppTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;
    final hasCriticalFlag = medication.safetyFlags.any(
      (f) => f.severity == FlagSeverity.critical,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? primary.withValues(alpha: isDark ? 0.20 : 0.10)
            : AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? primary
              : (hasCriticalFlag
                  ? (isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed)
                  : AppTheme.cardBorder(context)),
          width: isSelected || hasCriticalFlag ? 1.8 : 1,
        ),
        boxShadow: isSelected
            ? AppTheme.glowShadow(primary, opacity: 0.22)
            : (hasCriticalFlag
                ? AppTheme.glowShadow(AppTheme.dangerRed, opacity: 0.18)
                : AppTheme.softShadow(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (isSelectionMode) {
            onToggleSelect();
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MedicationDetailsPage(medication: medication),
              ),
            );
          }
        },
        onLongPress: () {
          if (!isSelectionMode) {
            onEnterSelection();
          } else {
            onToggleSelect();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row: Checkbox (if in selection mode) + Icon + Name/Dosage + More menu (if normal)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSelectionMode) ...[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: 12, top: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? primary : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? primary
                              : AppTheme.textMuted(context),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ],
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: hasCriticalFlag
                          ? (isDark
                              ? const Color(0xFF450A0A)
                              : const Color(0xFFFEE2E2))
                          : AppTheme.surfaceVariant(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      medication.icon,
                      color: hasCriticalFlag
                          ? (isDark
                              ? AppTheme.dangerRedLight
                              : AppTheme.dangerRed)
                          : primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medication.name,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          medication.scheduleFrequency ==
                                  ScheduleFrequency.asNeeded
                              ? '${medication.dosage} • As Needed (PRN)'
                              : '${medication.dosage} • ${medication.timesPerDay}x daily',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isSelectionMode)
                    PopupMenuButton<String>(
                      color: AppTheme.cardColor(context),
                      onSelected: (val) {
                        if (val == 'edit') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddEditMedicationPage(
                                medicationToEdit: medication,
                              ),
                            ),
                          );
                        } else if (val == 'delete') {
                          _showDeleteConfirm(context, ref);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text('Edit',
                                  style: TextStyle(
                                      color: AppTheme.textPrimary(context))),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded,
                                  color: AppTheme.dangerRed, size: 18),
                              SizedBox(width: 8),
                              Text('Delete',
                                  style: TextStyle(color: AppTheme.dangerRed)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              // Allergy / Conflict notice
              if (hasCriticalFlag) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF450A0A)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color:
                            isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          medication.safetyFlags.first.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppTheme.dangerRedLight
                                : AppTheme.dangerRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              // Scheduled dose times chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: medication.scheduledTimes.map((time) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant(context),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 12, color: AppTheme.textMuted(context)),
                        const SizedBox(width: 4),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              // Excipients & Clinical Considerations preview if available
              if (medication.inactiveExcipients.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.science_rounded,
                      size: 12,
                      color: AppTheme.textSecondary(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Excipients: ${medication.inactiveExcipients.take(3).join(', ')}${medication.inactiveExcipients.length > 3 ? '...' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Medication?'),
        content: Text(
            'Are you sure you want to delete ${medication.name}? This will cancel all its scheduled notifications.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () {
              ref
                  .read(medicationsNotifierProvider.notifier)
                  .remove(medication.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
