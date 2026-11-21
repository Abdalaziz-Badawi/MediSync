import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/services/device_integration_service.dart';
import 'package:medisync/features/homeboard/presentation/widgets/expandable_add_medication_fab.dart';
import 'package:medisync/features/homeboard/presentation/widgets/missed_dose_guidance_sheet.dart';

void main() {
  group('v1.7.1 Enhancements & Bug Fixes Tests', () {
    test('Vitamin D3 monthly frequency display does not show as daily', () {
      final monthlyMed = Medication(
        id: 'vit_d3',
        name: 'Vitamin D3',
        dosage: '50,000 IU',
        timesPerDay: 1,
        startDate: DateTime.now(),
        scheduleFrequency: ScheduleFrequency.monthly,
        monthlyDays: const [1],
        scheduledTimes: ['09:00'],
      );

      // Verify frequencyDisplay format
      expect(monthlyMed.frequencyDisplay, 'Monthly (Day 1) • 1x');
      expect(monthlyMed.frequencyDisplay.contains('daily'), isFalse);
    });

    test('DeviceIntegrationService.formatDoseLogEntry formats raw logs cleanly', () {
      expect(
        DeviceIntegrationService.formatDoseLogEntry('08:00:taken'),
        '08:00 (Taken On Time ✅)',
      );
      expect(
        DeviceIntegrationService.formatDoseLogEntry('14:30:delayed'),
        '14:30 (Taken Delayed ⏰)',
      );
      expect(
        DeviceIntegrationService.formatDoseLogEntry('20:00:missed'),
        '20:00 (Missed Window ❌)',
      );
      expect(
        DeviceIntegrationService.formatDoseLogEntry('12:00:notNeeded'),
        '12:00 (Not Needed (PRN) ⚪)',
      );
      expect(
        DeviceIntegrationService.formatDoseLogEntry('10:00'),
        '10:00',
      );
    });

    testWidgets('ExpandableAddMedicationFab renders Add Medicine button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            floatingActionButton: ExpandableAddMedicationFab(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Medicine'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('Missed Dose Guidance Sheet renders clinical advice and options', (tester) async {
      final testMed = Medication(
        id: 'atorvastatin',
        name: 'Atorvastatin',
        dosage: '20mg',
        timesPerDay: 1,
        startDate: DateTime.now(),
        scheduledTimes: ['22:00'],
      );

      DoseStatus? chosenStatus;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showMissedDoseGuidanceSheet(
                    ctx,
                    medication: testMed,
                    scheduledTime: '22:00',
                    onSelectStatus: (st) => chosenStatus = st,
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify guidance sheet content
      expect(find.text('Missed Dose Clinical Guidance'), findsOneWidget);
      expect(find.text('RECOMMENDED ACTION'), findsOneWidget);
      expect(find.textContaining('Halfway Rule'), findsOneWidget);
      expect(find.textContaining('NEVER take two doses at once'), findsOneWidget);
      expect(find.text('Skip Dose (Missed)'), findsOneWidget);
      expect(find.text('Take Now (Late)'), findsOneWidget);

      // Tap Skip Dose
      await tester.tap(find.text('Skip Dose (Missed)'));
      await tester.pumpAndSettle();

      expect(chosenStatus, DoseStatus.missed);
    });
  });
}
