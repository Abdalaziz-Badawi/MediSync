import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/services/device_integration_service.dart';
import 'package:medisync/core/services/storage_service.dart';
import 'package:medisync/core/theme/app_theme.dart';

class RecordsPage extends ConsumerStatefulWidget {
  const RecordsPage({super.key});

  @override
  ConsumerState<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends ConsumerState<RecordsPage> {
  String? _selectedMedId; // null = all medications
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final medications = ref.watch(medicationsNotifierProvider);
    final profile = ref.watch(profileNotifierProvider);
    final isDark = AppTheme.isDark(context);
    final activeColor = isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Continuity & Intake Log',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary(context),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Export Continuity Report (Consented)',
            icon: const Icon(Icons.description_rounded),
            onPressed: () => _showExportConsentDialog(medications, profile),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Strict Privacy & Local-First Shield Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1E2E) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFDCFCE7),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: 22,
                  color: isDark ? AppTheme.successGreenLight : AppTheme.successGreen,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '100% On-Device Medical Confidentiality',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.successGreenLight : AppTheme.successGreen,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'All medication intake timestamps and patient continuity logs are stored exclusively in your device\'s local encrypted database. No data is shared with external services without your explicit call-to-action consent.',
                        style: TextStyle(
                          fontSize: 11,
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
          const SizedBox(height: 16),

          // 2. Medication Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All Medications'),
                    selected: _selectedMedId == null,
                    selectedColor: activeColor,
                    backgroundColor: AppTheme.surfaceVariant(context),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: _selectedMedId == null ? FontWeight.bold : FontWeight.normal,
                      color: _selectedMedId == null
                          ? (isDark ? const Color(0xFF042F2E) : Colors.white)
                          : AppTheme.textPrimary(context),
                    ),
                    onSelected: (_) => setState(() => _selectedMedId = null),
                  ),
                ),
                ...medications.map((med) {
                  final isSel = _selectedMedId == med.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(med.name),
                      selected: isSel,
                      selectedColor: activeColor,
                      backgroundColor: AppTheme.surfaceVariant(context),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel
                            ? (isDark ? const Color(0xFF042F2E) : Colors.white)
                            : AppTheme.textPrimary(context),
                      ),
                      onSelected: (_) => setState(() => _selectedMedId = med.id),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Continuity Cards (Started, Last Taken, Adherence Rate)
          Text(
            'Patient Continuity & Intake Rates',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          ...medications
              .where((m) => _selectedMedId == null || m.id == _selectedMedId)
              .map((med) => _buildContinuityCard(med, isDark, activeColor)),

          const SizedBox(height: 20),

          // 4. Daily Detailed Timeline Header & Day Picker
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Intake Log',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                icon: const Icon(Icons.calendar_today_rounded, size: 14),
                label: Text(
                  DateFormat('MMM dd, yyyy').format(_selectedDate),
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2025, 1, 1),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Daily Doses Breakdown for Selected Date
          _buildDailyDosesSection(medications, isDark),

          const SizedBox(height: 24),

          // 5. Consent-Gated Export Call-to-Action Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.cardBorder(context)),
              boxShadow: AppTheme.softShadow(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, color: activeColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Physician Continuity Report',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Compile a structured, unencrypted clinical report of all doses taken, delayed, and missed since medication start. Strictly requires your review and consent before generation.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showExportConsentDialog(medications, profile),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Export Continuity Record (Consent Required)'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _buildContinuityCard(Medication med, bool isDark, Color activeColor) {
    final stats = med.continuityStats;
    final total = stats['taken']! + stats['delayed']! + stats['missed']!;
    final rate = total > 0 ? (stats['taken']! / total * 100).round() : 100;
    final lastTaken = med.lastTakenDateTime;
    final lastTakenStr = lastTaken != null
        ? DateFormat('MMM d, hh:mm a').format(lastTaken)
        : 'No doses logged yet';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder(context)),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1),
                child: Icon(med.icon, size: 18, color: activeColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${med.name} (${med.dosage})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    Text(
                      'Form: ${med.form.name.toUpperCase()} • ${med.scheduleFrequency.name}',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: rate >= 80
                      ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5))
                      : (isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$rate% On-Time',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: rate >= 80
                        ? (isDark ? AppTheme.successGreenLight : AppTheme.successGreen)
                        : (isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppTheme.cardBorder(context)),
          const SizedBox(height: 10),

          // Start Date & Last Taken Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Started On',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MMM dd, yyyy').format(med.startDate),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Taken',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastTakenStr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Intake Statistics Breakdown Pills
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildStatPill(
                label: 'Taken On Time: ${stats['taken']}',
                color: isDark ? AppTheme.successGreenLight : AppTheme.successGreen,
                bgColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
                icon: Icons.check_circle_rounded,
              ),
              _buildStatPill(
                label: 'Delayed: ${stats['delayed']}',
                color: isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber,
                bgColor: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
                icon: Icons.schedule_rounded,
              ),
              _buildStatPill(
                label: 'Missed: ${stats['missed']}',
                color: isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed,
                bgColor: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                icon: Icons.cancel_rounded,
              ),
              if (stats['notNeeded']! > 0 || med.scheduleFrequency == ScheduleFrequency.asNeeded)
                _buildStatPill(
                  label: 'Not Needed: ${stats['notNeeded']}',
                  color: isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade700,
                  bgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  icon: Icons.remove_circle_outline_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill({
    required String label,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyDosesSection(List<Medication> medications, bool isDark) {
    final dayMeds = medications.where((m) {
      if (_selectedMedId != null && m.id != _selectedMedId) return false;
      return m.isActiveOn(_selectedDate);
    }).toList();

    if (dayMeds.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder(context)),
        ),
        alignment: Alignment.center,
        child: Text(
          'No scheduled medications active on ${DateFormat('MMMM dd, yyyy').format(_selectedDate)}.',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
        ),
      );
    }

    return Column(
      children: dayMeds.expand((med) {
        return med.scheduledTimes.map((time) {
          final status = med.getDoseStatus(_selectedDate, time);
          return _buildDailyDoseTile(med, time, status, isDark);
        });
      }).toList(),
    );
  }

  Widget _buildDailyDoseTile(
    Medication med,
    String time,
    DoseStatus status,
    bool isDark,
  ) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case DoseStatus.taken:
        statusColor = isDark ? AppTheme.successGreenLight : AppTheme.successGreen;
        statusLabel = 'Taken On Time';
        statusIcon = Icons.check_circle_rounded;
        break;
      case DoseStatus.delayed:
        statusColor = isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber;
        statusLabel = 'Taken Delayed';
        statusIcon = Icons.schedule_rounded;
        break;
      case DoseStatus.missed:
        statusColor = isDark ? AppTheme.dangerRedLight : AppTheme.dangerRed;
        statusLabel = 'Missed Window';
        statusIcon = Icons.cancel_rounded;
        break;
      case DoseStatus.notNeeded:
        statusColor = isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade700;
        statusLabel = 'Not Needed (PRN)';
        statusIcon = Icons.remove_circle_outline_rounded;
        break;
      case DoseStatus.pending:
        statusColor = AppTheme.textSecondary(context);
        statusLabel = 'Pending';
        statusIcon = Icons.hourglass_empty_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder(context)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 20, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${med.name} • ${med.dosage}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                Text(
                  'Scheduled for $time',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExportConsentDialog(List<Medication> medications, dynamic profile) {
    final isDark = AppTheme.isDark(context);
    bool isConsentChecked = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF151E2E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              title: Row(
                children: [
                  Icon(
                    Icons.security_rounded,
                    color: isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Patient Consent Required',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(ctx),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MediSync enforces absolute local privacy. Your medical history cannot leave this device without your explicit call to action.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(ctx), height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant(ctx),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Report Contents:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary(ctx),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('• Start and latest intake timestamps', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(ctx))),
                          Text('• Complete on-time, delayed, missed & PRN stats', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(ctx))),
                          Text('• Recorded drug allergies and dietary advisories', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(ctx))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isConsentChecked,
                      onChanged: (val) {
                        setDialogState(() {
                          isConsentChecked = val ?? false;
                        });
                      },
                      title: Text(
                        'I explicitly consent to generate an unencrypted patient continuity file on this device.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary(ctx),
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isConsentChecked
                      ? () {
                          Navigator.pop(ctx);
                          _generateAndDisplayReport(medications, profile);
                        }
                      : null,
                  child: const Text('Authorize & Generate'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _generateAndDisplayReport(List<Medication> medications, dynamic profile) {
    final integrationService = ref.read(deviceIntegrationServiceProvider);
    final reportContent = integrationService.generateContinuityReport(
      medications: medications,
      profile: profile,
    );

    final isDark = AppTheme.isDark(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF151E2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (dCtx, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Continuity Clinical Record',
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
                  const SizedBox(height: 6),
                  Text(
                    'Generated on-device with verified patient consent.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(ctx)),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.cardBorder(ctx)),
                      ),
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: SelectableText(
                          reportContent,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: AppTheme.textPrimary(ctx),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // Copy to clipboard
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Continuity report generated successfully on device.'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                          label: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
