import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/models/user_profile.dart';
import 'package:medisync/core/services/device_integration_service.dart';
import 'package:medisync/core/theme/app_theme.dart';

class EmergencyHealthCardWidget extends StatelessWidget {
  final UserProfile profile;
  final List<Medication> medications;
  final bool isPrintOrExportMode;

  const EmergencyHealthCardWidget({
    super.key,
    required this.profile,
    required this.medications,
    this.isPrintOrExportMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeMeds = medications.where((m) => !m.isDiscontinued).toList();
    final dobStr = profile.dateOfBirth != null
        ? DateFormat('d MMMM yyyy').format(profile.dateOfBirth!)
        : (profile.age != null ? 'Age ${profile.age}' : 'Not specified');
    final ageStr = profile.age != null ? ' (${profile.age} yrs)' : '';
    final bloodType = profile.bloodType ?? 'Unknown';
    final healthId = profile.healthId ?? 'Not Registered';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        boxShadow: isPrintOrExportMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: Container(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Emergency Header Banner (Red)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  gradient: LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EMERGENCY MEDICAL ID',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'OFFLINE VERIFIED • HIGH-ALERT TRIAGE PROFILE',
                        style: TextStyle(
                          color: Color(0xFFFEE2E2),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'OFFLINE',
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Patient Demographics & Health Badges
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient Name
                Text(
                  profile.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'BORN: $dobStr$ageStr   •   GENDER: ${profile.gender ?? 'Not Specified'}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 14),

                // 1. HERO TRIAGE VITALS ROW: Blood Group & Organ Donor Status (50/50 split)
                Row(
                  children: [
                    // Blood Group Hero Badge (High Alert Crimson)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFDC2626), width: 2.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.bloodtype_rounded, color: Color(0xFFDC2626), size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  'BLOOD: $bloodType',
                                  style: const TextStyle(
                                    color: Color(0xFFB91C1C),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              bloodType,
                              style: const TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'TRANSFUSION VITAL',
                              style: TextStyle(
                                color: Color(0xFF991B1B),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Organ Donor Hero Badge
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          color: profile.isOrganDonor ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: profile.isOrganDonor ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                            width: 2.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (profile.isOrganDonor ? const Color(0xFF059669) : Colors.black).withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.volunteer_activism_rounded,
                                  color: profile.isOrganDonor ? const Color(0xFF047857) : const Color(0xFF64748B),
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'ORGAN DONOR',
                                  style: TextStyle(
                                    color: Color(0xFF475569),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              profile.isOrganDonor ? 'YES' : 'NO',
                              style: TextStyle(
                                color: profile.isOrganDonor ? const Color(0xFF059669) : const Color(0xFF475569),
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              profile.isOrganDonor ? 'REGISTERED DONOR' : 'NOT REGISTERED',
                              style: TextStyle(
                                color: profile.isOrganDonor ? const Color(0xFF047857) : const Color(0xFF94A3B8),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 2. Full-Width National Health / Medical ID Bar (100% width, ZERO truncation)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF94A3B8), width: 1.6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.badge_rounded, color: Color(0xFF1E293B), size: 21),
                      const SizedBox(width: 8),
                      const Text(
                        'NATIONAL HEALTH ID:',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          healthId,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Physical Metrics Row (Height, Weight & Dynamic BMI Badges)
                if (profile.heightCm != null || profile.weightKg != null || profile.bmi != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (profile.heightCm != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                          ),
                          child: Text(
                            'HT: ${profile.heightCm!.toInt()} cm',
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (profile.weightKg != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                          ),
                          child: Text(
                            'WT: ${profile.weightKg!.toStringAsFixed(1)} kg',
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (profile.bmi != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF3B82F6), width: 1),
                          ),
                          child: Text(
                            'BMI: ${profile.bmi!.toStringAsFixed(1)} (${profile.bmiCategory})',
                            style: const TextStyle(
                              color: Color(0xFF1D4ED8),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                // 3. PRIORITY 1: High-Alert Danger Box (Critical Allergies & Contraindications)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: profile.allergies.isNotEmpty ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: profile.allergies.isNotEmpty ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (profile.allergies.isNotEmpty ? const Color(0xFFDC2626) : const Color(0xFF16A34A))
                            .withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            profile.allergies.isNotEmpty ? Icons.warning_rounded : Icons.check_circle_rounded,
                            color: profile.allergies.isNotEmpty ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'CRITICAL ALLERGIES & CONTRAINDICATIONS:',
                            style: TextStyle(
                              color: profile.allergies.isNotEmpty ? const Color(0xFF991B1B) : const Color(0xFF166534),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        profile.allergies.isNotEmpty
                            ? profile.allergies.join('   ⚠️   ')
                            : 'NO KNOWN DRUG ALLERGIES (NKDA)',
                        style: TextStyle(
                          color: profile.allergies.isNotEmpty ? const Color(0xFF7F1D1D) : const Color(0xFF14532D),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (profile.allergies.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'STOP • SEVERE ANAPHYLAXIS RISK • VERIFY BEFORE DRUG ADMINISTRATION',
                          style: TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 4. PRIORITY 2: Clinical Conditions & Procedural History
                if (profile.chronicConditions.isNotEmpty || profile.pastSurgeries.isNotEmpty || profile.medicalHistory.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (profile.chronicConditions.isNotEmpty) ...[
                          const Row(
                            children: [
                              Icon(Icons.monitor_heart_rounded, color: Color(0xFF0F766E), size: 18),
                              SizedBox(width: 6),
                              Text(
                                'CHRONIC CONDITIONS & ORGAN RISKS:',
                                style: TextStyle(
                                  color: Color(0xFF0F766E),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.chronicConditions.join('   •   '),
                            style: const TextStyle(
                              color: Color(0xFF134E4A),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        if (profile.pastSurgeries.isNotEmpty) ...[
                          if (profile.chronicConditions.isNotEmpty) const SizedBox(height: 10),
                          const Row(
                            children: [
                              Icon(Icons.healing_rounded, color: Color(0xFF4338CA), size: 18),
                              SizedBox(width: 6),
                              Text(
                                'PAST SURGERIES & PROCEDURES:',
                                style: TextStyle(
                                  color: Color(0xFF4338CA),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.pastSurgeries.join('   •   '),
                            style: const TextStyle(
                              color: Color(0xFF1E1B4B),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        if (profile.medicalHistory.isNotEmpty) ...[
                          if (profile.chronicConditions.isNotEmpty || profile.pastSurgeries.isNotEmpty) const SizedBox(height: 10),
                          const Row(
                            children: [
                              Icon(Icons.history_edu_rounded, color: Color(0xFF0369A1), size: 18),
                              SizedBox(width: 6),
                              Text(
                                'PAST MEDICAL HISTORY / DISEASES:',
                                style: TextStyle(
                                  color: Color(0xFF0369A1),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.medicalHistory.join('   •   '),
                            style: const TextStyle(
                              color: Color(0xFF0C4A6E),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 16),

                // 4. Active Medications Table
                Row(
                  children: [
                    const Icon(Icons.medication_rounded, size: 20, color: Color(0xFF0F172A)),
                    const SizedBox(width: 6),
                    const Text(
                      'ACTIVE MEDICATIONS',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        '${activeMeds.length} Active',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (activeMeds.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      'No regularly scheduled active medications recorded.',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                    ),
                  )
                else
                  ...activeMeds.take(6).map((med) {
                    final timesStr = med.scheduledTimes.isNotEmpty
                        ? med.scheduledTimes.join(', ')
                        : 'As needed';
                    final freqStr = '${med.frequencyDisplay} ($timesStr)';
                    final hasHighNecessity = med.necessityLevel == NecessityLevel.critical || med.necessityLevel == NecessityLevel.vital;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                text: '${med.name} ',
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                ),
                                children: [
                                  if (hasHighNecessity)
                                    TextSpan(
                                      text: '[${med.necessityLevel.badgeText}] ',
                                      style: TextStyle(
                                        color: med.necessityLevel == NecessityLevel.critical
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFFEA580C),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  TextSpan(
                                    text: '(${med.dosage}, ${med.form.name}) — $freqStr',
                                    style: const TextStyle(
                                      color: Color(0xFF334155),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                // 4b. Discontinued High-Risk Medications Section (Clinically Significant)
                Builder(
                  builder: (context) {
                    final significantDiscontinued = medications
                        .where((m) => m.isDiscontinued && m.necessityLevel != NecessityLevel.low)
                        .toList();
                    if (significantDiscontinued.isEmpty) return const SizedBox.shrink();

                    return Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.history_toggle_off_rounded, color: Color(0xFFD97706), size: 16),
                              SizedBox(width: 5),
                              Text(
                                'DISCONTINUED HIGH-RISK MEDICATIONS:',
                                style: TextStyle(
                                  color: Color(0xFFB45309),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ...significantDiscontinued.map((med) {
                            String timeAgo = '';
                            if (med.discontinuedDate != null) {
                              final days = DateTime.now().difference(med.discontinuedDate!).inDays;
                              timeAgo = days <= 0 ? 'Today' : (days == 1 ? '1 day ago' : '$days days ago');
                            }
                            final lastTaken = med.lastTakenDateTime != null
                                ? DateFormat('d MMM, HH:mm').format(med.lastTakenDateTime!)
                                : 'No dose recorded';
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF78350F))),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        text: '${med.name} (${med.dosage}) ',
                                        style: const TextStyle(
                                          color: Color(0xFF78350F),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: '[${med.necessityLevel.badgeText}]',
                                            style: TextStyle(
                                              color: med.necessityLevel == NecessityLevel.critical
                                                  ? const Color(0xFFDC2626)
                                                  : const Color(0xFFB45309),
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          TextSpan(
                                            text: ' — Discontinued $timeAgo • Last: $lastTaken',
                                            style: const TextStyle(
                                              color: Color(0xFF92400E),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),

                // 5. Card Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '⚕️ MediSync Offline Medical ID',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D9488),
                      ),
                    ),
                    Text(
                      DateFormat('d MMM yyyy').format(DateTime.now()),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
  }
}

/// Shows the interactive Emergency Medical Card modal with live preview and 1-tap JPG sharing.
void showEmergencyCardDialog(
  BuildContext context, {
  required UserProfile profile,
  required List<Medication> medications,
}) {
  final cardKey = GlobalKey();
  final isDark = AppTheme.isDark(context);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SafeArea(
            child: Column(
              children: [
                // Modal Handle & Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.credit_card_rounded, color: Color(0xFFDC2626)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Emergency Medical ID Card',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary(ctx),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Card Preview Content
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(18),
                    children: [
                      Text(
                        'This emergency card contains your vital clinical data (Blood Type, Health ID, Allergies, Active Medications). It can be shared as a high-resolution JPG image or saved to your gallery.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textSecondary(ctx),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // RepaintBoundary wrapping the visual card for pixel-perfect solid JPG capture
                      RepaintBoundary(
                        key: cardKey,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: EmergencyHealthCardWidget(
                            profile: profile,
                            medications: medications,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // Bottom Action Buttons
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    border: Border(top: BorderSide(color: AppTheme.cardBorder(ctx))),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          // Save JPG Button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final bytes = await _captureCardBytes(cardKey, profile, medications);
                                if (bytes != null) {
                                  final path = await DeviceIntegrationService().saveEmergencyCardJpg(
                                    imageBytes: bytes,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        content: Text(
                                          path != null
                                              ? '✓ Saved Emergency Card to:\n$path'
                                              : '⚠ Failed to save Emergency Card to gallery. Please verify storage permissions.',
                                        ),
                                        backgroundColor: path != null
                                            ? const Color(0xFF0D9488)
                                            : AppTheme.dangerRed,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        content: Text('⚠ Could not capture card image.'),
                                        backgroundColor: AppTheme.dangerRed,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.download_rounded, size: 17),
                              label: const Text('Save JPG'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Share JPG Button
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final bytes = await _captureCardBytes(cardKey, profile, medications);
                                if (bytes != null) {
                                  try {
                                    await DeviceIntegrationService().shareEmergencyCardJpg(
                                      imageBytes: bytes,
                                      title: 'Emergency Medical ID - ${profile.name}',
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          behavior: SnackBarBehavior.floating,
                                          content: Text('✓ Shared Emergency Medical ID Card'),
                                          backgroundColor: Color(0xFF0D9488),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          behavior: SnackBarBehavior.floating,
                                          content: Text('⚠ Share failed: $e'),
                                          backgroundColor: AppTheme.dangerRed,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              icon: const Icon(Icons.share_rounded, size: 17),
                              label: const Text('Share JPG'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Lockscreen Emergency Sync Action
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await DeviceIntegrationService().syncEmergencyData(
                              profile: profile,
                              medications: medications,
                            );
                            await DeviceIntegrationService().openEmergencySettings();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  content: Text('✓ Refreshed Lockscreen Widget & Opening Android Emergency Settings...'),
                                  backgroundColor: Color(0xFF0D9488),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.screen_lock_portrait_rounded, size: 17),
                          label: const Text('Sync to Lockscreen Emergency Widget'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<Uint8List?> _captureCardBytes(
  GlobalKey key,
  UserProfile profile,
  List<Medication> medications,
) async {
  try {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary != null) {
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    }
  } catch (_) {
    // Fallback to programmatic Canvas renderer if boundary is not ready or in headless test
  }
  return DeviceIntegrationService().renderEmergencyCardBytes(
    profile: profile,
    medications: medications,
  );
}
