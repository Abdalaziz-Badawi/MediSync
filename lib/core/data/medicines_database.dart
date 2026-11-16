import '../models/condition.dart';
import '../models/medication.dart';
import '../models/side_effect.dart';

class MedicineTemplate {
  final String name;
  final String genericName;
  final String drugClass;
  final List<String> commonDosages;
  final MedicationForm defaultForm;
  final List<SideEffectType> knownSideEffects;
  final List<ConditionType> preConditions;
  final List<ConditionType> postConditions;
  final List<String> allergenTriggers;
  final String standardInstructions;

  const MedicineTemplate({
    required this.name,
    required this.genericName,
    required this.drugClass,
    required this.commonDosages,
    this.defaultForm = MedicationForm.pill,
    this.knownSideEffects = const [],
    this.preConditions = const [],
    this.postConditions = const [],
    this.allergenTriggers = const [],
    this.standardInstructions = '',
  });
}

class MedicinesDatabase {
  static const List<MedicineTemplate> repository = [
    // Pain & Fever
    MedicineTemplate(
      name: 'Panadol',
      genericName: 'Paracetamol',
      drugClass: 'Analgesic / Antipyretic',
      commonDosages: ['500 mg', '1000 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.nausea],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['paracetamol', 'acetaminophen'],
      standardInstructions: 'Take with a glass of water. Do not exceed 4000 mg in 24 hours.',
    ),
    MedicineTemplate(
      name: 'Tylenol',
      genericName: 'Acetaminophen',
      drugClass: 'Analgesic / Antipyretic',
      commonDosages: ['325 mg', '500 mg', '650 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['acetaminophen', 'paracetamol'],
      standardInstructions: 'Take with water. Avoid alcohol while taking.',
    ),
    MedicineTemplate(
      name: 'Advil',
      genericName: 'Ibuprofen',
      drugClass: 'NSAID (Non-Steroidal Anti-inflammatory)',
      commonDosages: ['200 mg', '400 mg', '600 mg'],
      defaultForm: MedicationForm.capsule,
      knownSideEffects: [SideEffectType.stomachUpset, SideEffectType.nausea],
      preConditions: [ConditionType.meal, ConditionType.drinkWater],
      allergenTriggers: ['ibuprofen', 'nsaid', 'aspirin'],
      standardInstructions: 'Always take with food or milk to prevent stomach upset.',
    ),
    MedicineTemplate(
      name: 'Motrin',
      genericName: 'Ibuprofen',
      drugClass: 'NSAID',
      commonDosages: ['200 mg', '400 mg', '800 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.stomachUpset],
      preConditions: [ConditionType.meal],
      allergenTriggers: ['ibuprofen', 'nsaid'],
      standardInstructions: 'Take after a meal with plenty of water.',
    ),
    MedicineTemplate(
      name: 'Aspirin',
      genericName: 'Acetylsalicylic acid',
      drugClass: 'NSAID / Antiplatelet',
      commonDosages: ['81 mg', '325 mg', '500 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.stomachUpset, SideEffectType.nausea],
      preConditions: [ConditionType.meal],
      allergenTriggers: ['aspirin', 'nsaid', 'salicylate'],
      standardInstructions: 'Take with food to protect stomach lining.',
    ),
    MedicineTemplate(
      name: 'Aleve',
      genericName: 'Naproxen Sodium',
      drugClass: 'NSAID',
      commonDosages: ['220 mg', '500 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.stomachUpset, SideEffectType.drowsiness],
      preConditions: [ConditionType.meal],
      allergenTriggers: ['naproxen', 'nsaid', 'aspirin'],
      standardInstructions: 'Take with meals or milk. Long-acting formula.',
    ),
    MedicineTemplate(
      name: 'Celebrex',
      genericName: 'Celecoxib',
      drugClass: 'COX-2 Inhibitor / NSAID',
      commonDosages: ['100 mg', '200 mg'],
      defaultForm: MedicationForm.capsule,
      knownSideEffects: [SideEffectType.stomachUpset],
      preConditions: [ConditionType.meal],
      allergenTriggers: ['celecoxib', 'nsaid', 'sulfa', 'sulfonamide'],
      standardInstructions: 'Take with food. Contains sulfonamide group.',
    ),

    // Antibiotics
    MedicineTemplate(
      name: 'Amoxicillin',
      genericName: 'Amoxicillin trihydrate',
      drugClass: 'Penicillin Antibiotic',
      commonDosages: ['250 mg', '500 mg', '875 mg'],
      defaultForm: MedicationForm.capsule,
      knownSideEffects: [SideEffectType.stomachUpset, SideEffectType.nausea],
      preConditions: [ConditionType.meal, ConditionType.drinkWater],
      allergenTriggers: ['penicillin', 'amoxicillin', 'ampicillin', 'beta-lactam'],
      standardInstructions: 'Complete the full course even if feeling better.',
    ),
    MedicineTemplate(
      name: 'Augmentin',
      genericName: 'Amoxicillin + Clavulanate',
      drugClass: 'Penicillin Antibiotic',
      commonDosages: ['625 mg', '1000 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.stomachUpset, SideEffectType.nausea],
      preConditions: [ConditionType.meal],
      allergenTriggers: ['penicillin', 'amoxicillin', 'clavulanate', 'beta-lactam'],
      standardInstructions: 'Take at the start of a meal to reduce digestive upset.',
    ),
    MedicineTemplate(
      name: 'Keflex',
      genericName: 'Cephalexin',
      drugClass: 'Cephalosporin Antibiotic',
      commonDosages: ['250 mg', '500 mg'],
      defaultForm: MedicationForm.capsule,
      knownSideEffects: [SideEffectType.nausea],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['cephalosporin', 'penicillin'],
      standardInstructions: 'Can be taken with or without food. Complete full course.',
    ),
    MedicineTemplate(
      name: 'Zithromax (Z-Pak)',
      genericName: 'Azithromycin',
      drugClass: 'Macrolide Antibiotic',
      commonDosages: ['250 mg', '500 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.nausea, SideEffectType.stomachUpset],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['azithromycin', 'macrolide', 'erythromycin'],
      standardInstructions: 'Usually taken once daily for 3 to 5 days.',
    ),
    MedicineTemplate(
      name: 'Cipro',
      genericName: 'Ciprofloxacin',
      drugClass: 'Fluoroquinolone Antibiotic',
      commonDosages: ['250 mg', '500 mg', '750 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.nausea, SideEffectType.dizziness],
      preConditions: [ConditionType.drinkWater],
      postConditions: [ConditionType.avoidDriving],
      allergenTriggers: ['ciprofloxacin', 'fluoroquinolone'],
      standardInstructions: 'Avoid dairy, calcium, and antacids within 2 hours of dose.',
    ),
    MedicineTemplate(
      name: 'Bactrim',
      genericName: 'Sulfamethoxazole + Trimethoprim',
      drugClass: 'Sulfonamide Antibiotic',
      commonDosages: ['400/80 mg', '800/160 mg (DS)'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.nausea],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['sulfa', 'sulfamethoxazole', 'sulfonamide', 'bactrim'],
      standardInstructions: 'Drink plenty of fluids while taking to prevent kidney crystals.',
    ),

    // Diabetes & Metabolic
    MedicineTemplate(
      name: 'Metformin',
      genericName: 'Metformin Hydrochloride',
      drugClass: 'Biguanide Antidiabetic',
      commonDosages: ['500 mg', '850 mg', '1000 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.stomachUpset, SideEffectType.nausea],
      preConditions: [ConditionType.meal, ConditionType.drinkWater],
      allergenTriggers: ['metformin'],
      standardInstructions: 'Take with or immediately after meals to reduce stomach upset.',
    ),
    MedicineTemplate(
      name: 'Jardiance',
      genericName: 'Empagliflozin',
      drugClass: 'SGLT2 Inhibitor',
      commonDosages: ['10 mg', '25 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.dizziness],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['empagliflozin'],
      standardInstructions: 'Take once daily in the morning with a full glass of water.',
    ),
    MedicineTemplate(
      name: 'Glucophage',
      genericName: 'Metformin Extended Release',
      drugClass: 'Antidiabetic',
      commonDosages: ['500 mg', '750 mg', '1000 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.stomachUpset],
      preConditions: [ConditionType.meal],
      allergenTriggers: ['metformin'],
      standardInstructions: 'Swallow whole with dinner; do not crush or chew.',
    ),

    // Cardiovascular & Blood Pressure
    MedicineTemplate(
      name: 'Lisinopril',
      genericName: 'Lisinopril',
      drugClass: 'ACE Inhibitor',
      commonDosages: ['5 mg', '10 mg', '20 mg', '40 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.dizziness],
      preConditions: [ConditionType.drinkWater],
      postConditions: [ConditionType.avoidDriving],
      allergenTriggers: ['lisinopril', 'ace inhibitor'],
      standardInstructions: 'Take at the same time each day. May cause lightheadedness initially.',
    ),
    MedicineTemplate(
      name: 'Amlodipine',
      genericName: 'Amlodipine Besylate',
      drugClass: 'Calcium Channel Blocker',
      commonDosages: ['2.5 mg', '5 mg', '10 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.dizziness, SideEffectType.headache],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['amlodipine'],
      standardInstructions: 'Take once daily with or without food.',
    ),
    MedicineTemplate(
      name: 'Lipitor',
      genericName: 'Atorvastatin Calcium',
      drugClass: 'HMG-CoA Reductase Inhibitor (Statin)',
      commonDosages: ['10 mg', '20 mg', '40 mg', '80 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.headache],
      preConditions: [ConditionType.drinkWater],
      postConditions: [ConditionType.sleep],
      allergenTriggers: ['atorvastatin', 'statin'],
      standardInstructions: 'Best taken in the evening or bedtime for optimal cholesterol regulation.',
    ),
    MedicineTemplate(
      name: 'Metoprolol',
      genericName: 'Metoprolol Tartrate / Succinate',
      drugClass: 'Beta Blocker',
      commonDosages: ['25 mg', '50 mg', '100 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.drowsiness, SideEffectType.dizziness],
      preConditions: [ConditionType.meal],
      postConditions: [ConditionType.rest],
      allergenTriggers: ['metoprolol', 'beta blocker'],
      standardInstructions: 'Take with or immediately following a meal.',
    ),

    // Gastrointestinal & Acid Reflux
    MedicineTemplate(
      name: 'Nexium',
      genericName: 'Esomeprazole Magnesium',
      drugClass: 'Proton Pump Inhibitor (PPI)',
      commonDosages: ['20 mg', '40 mg'],
      defaultForm: MedicationForm.capsule,
      knownSideEffects: [SideEffectType.headache],
      preConditions: [ConditionType.emptyStomach, ConditionType.drinkWater],
      allergenTriggers: ['esomeprazole', 'ppi'],
      standardInstructions: 'Take on an empty stomach at least 30-60 minutes before breakfast.',
    ),
    MedicineTemplate(
      name: 'Prilosec',
      genericName: 'Omeprazole',
      drugClass: 'Proton Pump Inhibitor (PPI)',
      commonDosages: ['20 mg', '40 mg'],
      defaultForm: MedicationForm.capsule,
      knownSideEffects: [SideEffectType.headache],
      preConditions: [ConditionType.emptyStomach],
      allergenTriggers: ['omeprazole', 'ppi'],
      standardInstructions: 'Take 30-60 minutes before first meal of the day.',
    ),

    // Allergies & Antihistamines
    MedicineTemplate(
      name: 'Zyrtec',
      genericName: 'Cetirizine Hydrochloride',
      drugClass: 'Antihistamine (2nd Gen)',
      commonDosages: ['5 mg', '10 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.drowsiness, SideEffectType.dryMouth],
      postConditions: [ConditionType.sleep, ConditionType.avoidDriving],
      allergenTriggers: ['cetirizine', 'antihistamine'],
      standardInstructions: 'Can cause mild drowsiness; recommended in the evening.',
    ),
    MedicineTemplate(
      name: 'Benadryl',
      genericName: 'Diphenhydramine HCl',
      drugClass: 'Antihistamine (1st Gen)',
      commonDosages: ['25 mg', '50 mg'],
      defaultForm: MedicationForm.capsule,
      knownSideEffects: [SideEffectType.drowsiness, SideEffectType.dizziness, SideEffectType.dryMouth],
      postConditions: [ConditionType.sleep, ConditionType.avoidDriving],
      allergenTriggers: ['diphenhydramine'],
      standardInstructions: 'Causes marked drowsiness. Do not drive or operate machinery.',
    ),
    MedicineTemplate(
      name: 'Claritin',
      genericName: 'Loratadine',
      drugClass: 'Non-Drowsy Antihistamine',
      commonDosages: ['10 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.headache],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['loratadine'],
      standardInstructions: 'Take once daily with water. Non-drowsy formulation.',
    ),

    // Sleep & Calming
    MedicineTemplate(
      name: 'Melatonin',
      genericName: 'Melatonin',
      drugClass: 'Pineal Hormone / Sleep Aid',
      commonDosages: ['1 mg', '3 mg', '5 mg', '10 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.drowsiness],
      postConditions: [ConditionType.sleep, ConditionType.avoidDriving],
      allergenTriggers: ['melatonin'],
      standardInstructions: 'Take 30 to 60 minutes before going to bed in a dark room.',
    ),
    MedicineTemplate(
      name: 'Ambien',
      genericName: 'Zolpidem Tartrate',
      drugClass: 'Sedative-Hypnotic',
      commonDosages: ['5 mg', '10 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.drowsiness, SideEffectType.dizziness],
      postConditions: [ConditionType.sleep, ConditionType.avoidDriving],
      allergenTriggers: ['zolpidem'],
      standardInstructions: 'Take immediately before bed. Ensure 7-8 hours available for sleep.',
    ),
  ];

  /// Searches medicines by name or generic name and ranks results
  static List<MedicineTemplate> search(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return [];

    return repository.where((m) {
      return m.name.toLowerCase().contains(clean) ||
          m.genericName.toLowerCase().contains(clean) ||
          m.drugClass.toLowerCase().contains(clean);
    }).toList();
  }
}
