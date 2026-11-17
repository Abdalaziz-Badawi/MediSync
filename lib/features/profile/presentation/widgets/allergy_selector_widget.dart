import 'package:flutter/material.dart';
import 'package:medisync/core/data/allergy_taxonomy_data.dart';
import 'package:medisync/core/theme/app_theme.dart';

class AllergySelectorWidget extends StatefulWidget {
  final List<String> selectedAllergies;
  final Function(String allergy) onToggleAllergy;
  final Function(String customAllergy)? onAddCustomAllergy;
  final bool isMasked;

  const AllergySelectorWidget({
    super.key,
    required this.selectedAllergies,
    required this.onToggleAllergy,
    this.onAddCustomAllergy,
    this.isMasked = false,
  });

  @override
  State<AllergySelectorWidget> createState() => _AllergySelectorWidgetState();
}

class _AllergySelectorWidgetState extends State<AllergySelectorWidget> {
  AllergyCategoryType _selectedCategory = AllergyCategoryType.all;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TaxonomyAllergen> _getFilteredAllergens() {
    return AllergyTaxonomyData.allAllergens.where((item) {
      final matchesCategory = _selectedCategory == AllergyCategoryType.all ||
          item.category == _selectedCategory;
      if (!matchesCategory) return false;

      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return item.name.toLowerCase().contains(q) ||
          item.subcategory.toLowerCase().contains(q) ||
          item.clinicalNote.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final filtered = _getFilteredAllergens();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Configured Selected Allergies Section
        if (widget.selectedAllergies.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Safety Protection Profile (${widget.selectedAllergies.length}):',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              if (widget.isMasked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_off, size: 12, color: AppTheme.textSecondary(context)),
                      const SizedBox(width: 4),
                      Text(
                        'Masked',
                        style: TextStyle(fontSize: 10, color: AppTheme.textSecondary(context), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: widget.selectedAllergies.map((allergy) {
              final displayText = widget.isMasked ? '••••••••' : allergy;
              return Chip(
                backgroundColor: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                side: BorderSide(
                  color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                ),
                avatar: CircleAvatar(
                  radius: 8,
                  backgroundColor: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                  child: const Icon(Icons.shield, size: 10, color: Colors.white),
                ),
                label: Text(
                  displayText,
                  style: TextStyle(
                    color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                deleteIcon: const Icon(Icons.close, size: 16),
                deleteIconColor: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                onDeleted: () => widget.onToggleAllergy(allergy),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // 2. Search & Filter Bar
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.cardBorder(context)),
          ),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search drugs, excipients, foods, or additives...',
              hintStyle: TextStyle(color: AppTheme.textMuted(context), fontSize: 13),
              prefixIcon: Icon(
                Icons.search,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim();
              });
            },
          ),
        ),
        const SizedBox(height: 12),

        // 3. Category Filter Tabs (Horizontal Scroll)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: AllergyCategoryType.values.map((cat) {
              final isSelected = _selectedCategory == cat;
              final catColor = AllergyTaxonomyData.getCategoryColor(cat, context);

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cat.icon,
                        size: 14,
                        color: isSelected
                            ? (isDark ? const Color(0xFF042F2E) : Colors.white)
                            : catColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cat.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? (isDark ? const Color(0xFF042F2E) : Colors.white)
                              : AppTheme.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: Theme.of(context).colorScheme.primary,
                  backgroundColor: AppTheme.cardColor(context),
                  side: BorderSide(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : AppTheme.cardBorder(context),
                  ),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  onSelected: (_) {
                    setState(() {
                      _selectedCategory = cat;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // 4. Clinical Taxonomy Trigger Selection Chips
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorder(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Clinical Taxonomy Triggers (${filtered.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  Text(
                    'Tap to select / remove',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (filtered.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          'No matches found for "$_searchQuery"',
                          style: TextStyle(color: AppTheme.textMuted(context), fontSize: 13),
                        ),
                        if (_searchQuery.isNotEmpty && widget.onAddCustomAllergy != null) ...[
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              widget.onAddCustomAllergy!(_searchQuery);
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: Text('Add "$_searchQuery" as Custom Allergy'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ] else ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: filtered.map((item) {
                        final isSelected = widget.selectedAllergies.contains(item.name);
                        final catColor = AllergyTaxonomyData.getCategoryColor(item.category, context);

                        return ActionChip(
                          avatar: isSelected
                              ? const Icon(Icons.check_circle, size: 14, color: AppTheme.dangerRed)
                              : Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: catColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                          label: Text(item.name),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? (isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed)
                                : AppTheme.textPrimary(context),
                          ),
                          backgroundColor: isSelected
                              ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2))
                              : AppTheme.cardColor(context),
                          side: BorderSide(
                            color: isSelected
                                ? (isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed)
                                : AppTheme.cardBorder(context),
                          ),
                          onPressed: () => widget.onToggleAllergy(item.name),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
