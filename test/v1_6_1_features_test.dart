import 'package:flutter_test/flutter_test.dart';
import 'package:medisync/core/data/medicines_database.dart';
import 'package:medisync/core/models/medication.dart';
import 'package:medisync/core/models/user_profile.dart';
import 'package:medisync/core/services/device_integration_service.dart';
import 'package:medisync/core/services/streak_service.dart';

void main() {
  group('v1.6.1 Multi-Dose Calendar Sync, Clinical Cautions & Setup Wizard Tests', () {
    test('Multi-Dose & Multi-Medication Calendar Event Generation generates all dose instances', () {
      final now = DateTime.now();
      
      final panadol = Medication(
        id: 'pan-1',
        name: 'Panadol',
        dosage: '500 mg',
        timesPerDay: 3,
        scheduledTimes: ['08:00', '14:00', '20:00'],
        startDate: now,
      );

      final metformin = Medication(
        id: 'met-1',
        name: 'Metformin',
        dosage: '850 mg',
        timesPerDay: 2,
        scheduledTimes: ['08:30', '19:30'],
        startDate: now,
      );

      final discontinuedMed = Medication(
        id: 'disc-1',
        name: 'Amoxicillin',
        dosage: '500 mg',
        timesPerDay: 3,
        scheduledTimes: ['06:00', '14:00', '22:00'],
        startDate: now.subtract(const Duration(days: 10)),
        discontinuedDate: now.subtract(const Duration(days: 2)),
      );

      final service = DeviceIntegrationService();
      final calendarEvents = service.buildCalendarEventPayloads(
        medications: [panadol, metformin, discontinuedMed],
      );

      // Panadol (3) + Metformin (2) = 5 events. Discontinued is excluded!
      expect(calendarEvents.length, equals(5));

      // Check Panadol multi-dose titles and dose counters
      final panadolEvents = calendarEvents.where((e) => e['medicationId'] == 'pan-1').toList();
      expect(panadolEvents.length, equals(3));
      expect(panadolEvents[0]['title'], contains('Dose 1 of 3 (08:00)'));
      expect(panadolEvents[1]['title'], contains('Dose 2 of 3 (14:00)'));
      expect(panadolEvents[2]['title'], contains('Dose 3 of 3 (20:00)'));
      expect(panadolEvents[0]['doseTime'], equals('08:00'));
      expect(panadolEvents[1]['doseTime'], equals('14:00'));
      expect(panadolEvents[2]['doseTime'], equals('20:00'));

      // Check Metformin multi-dose titles
      final metforminEvents = calendarEvents.where((e) => e['medicationId'] == 'met-1').toList();
      expect(metforminEvents.length, equals(2));
      expect(metforminEvents[0]['title'], contains('Dose 1 of 2 (08:30)'));
      expect(metforminEvents[1]['title'], contains('Dose 2 of 2 (19:30)'));

      // Check recurring rule
      for (final event in calendarEvents) {
        expect(event['rrule'], equals('FREQ=DAILY'));
        expect(event['hasAlarm'], equals(true));
      }
    });

    test('Medicines Database contains comprehensive clinical cautions, danger levels & powdering warnings', () {
      // Panadol / Paracetamol
      final paracetamol = MedicinesDatabase.findByName('Panadol');
      expect(paracetamol, isNotNull);
      expect(paracetamol!.activeIngredients.any((i) => i.contains('Paracetamol')), isTrue);
      expect(paracetamol.dangerLevel, equals(DangerLevel.low));
      expect(paracetamol.prescriptionRequirement, equals(PrescriptionRequirement.otc));
      
      // Crucial: explicit warning against crushing or making powder out of tablets
      final hasCrushWarning = paracetamol.administrationCautions.any(
        (caution) => caution.toLowerCase().contains('crush') || caution.toLowerCase().contains('powder'),
      );
      expect(hasCrushWarning, isTrue, reason: 'Panadol must explicitly warn against making powder out of tablets');

      // Check max daily dosage warning
      final hasMaxDoseWarning = paracetamol.administrationCautions.any(
        (caution) => caution.contains('4,000 mg') || caution.contains('4000mg') || caution.contains('4000'),
      );
      expect(hasMaxDoseWarning, isTrue);

      // Check Critical medication: Warfarin
      final warfarin = MedicinesDatabase.findByName('Warfarin');
      expect(warfarin, isNotNull);
      expect(warfarin!.dangerLevel, equals(DangerLevel.critical));
      expect(warfarin.prescriptionRequirement, equals(PrescriptionRequirement.prescription));
      expect(warfarin.emergencySigns.isNotEmpty, isTrue);

      // Check Specialist Controlled Substance: Xanax (Alprazolam)
      final xanax = MedicinesDatabase.findByName('Xanax');
      expect(xanax, isNotNull);
      expect(xanax!.prescriptionRequirement, equals(PrescriptionRequirement.specialistControlled));

      // Check High Danger antibiotic: Ciprofloxacin
      final cipro = MedicinesDatabase.findByName('Ciprofloxacin');
      expect(cipro, isNotNull);
      expect(cipro!.dangerLevel, equals(DangerLevel.high));
      expect(cipro.prescriptionRequirement, equals(PrescriptionRequirement.prescription));
      expect(cipro.administrationCautions.any((c) => c.toLowerCase().contains('dairy') || c.toLowerCase().contains('calcium')), isTrue);
    });

    test('UserProfile Demographics model serialization & immutability', () {
      final profile = UserProfile(
        name: 'Sarah Connor',
        age: 38,
        gender: 'Female',
        allergies: ['Penicillin', 'Sulfa'],
        chronicConditions: ['Asthma', 'Hypertension'],
        wakeTime: '06:30',
        sleepTime: '22:30',
      );

      final json = profile.toJson();
      expect(json['age'], equals(38));
      expect(json['gender'], equals('Female'));
      expect(json['chronicConditions'], contains('Asthma'));

      final restored = UserProfile.fromJson(json);
      expect(restored.name, equals('Sarah Connor'));
      expect(restored.age, equals(38));
      expect(restored.gender, equals('Female'));
      expect(restored.chronicConditions, equals(['Asthma', 'Hypertension']));

      // copyWith test
      final updated = restored.copyWith(age: 39, gender: 'Prefer not to say');
      expect(updated.age, equals(39));
      expect(updated.gender, equals('Prefer not to say'));
      expect(updated.name, equals('Sarah Connor'));
    });

    test('StreakMilestones list and Adherence streak computations', () {
      expect(StreakMilestone.all.length, greaterThanOrEqualTo(7));
      expect(StreakMilestone.all.first.requiredDays, equals(3));
      expect(StreakMilestone.all.any((m) => m.requiredDays == 365), isTrue);

      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final med = Medication(
        id: 'med-s1',
        name: 'Aspirin',
        dosage: '81 mg',
        timesPerDay: 1,
        scheduledTimes: ['09:00'],
        startDate: now.subtract(const Duration(days: 5)),
        doseLog: {
          todayStr: ['09:00'],
        },
      );

      final streak = StreakService.computeStreakData([med]);
      expect(streak.currentStreak, greaterThanOrEqualTo(1));
      expect(streak.nextMilestone, isNotNull);
      expect(streak.progressToNext, inInclusiveRange(0.0, 1.0));
    });
  });
}
