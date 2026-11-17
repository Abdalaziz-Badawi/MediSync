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
  final List<String> inactiveExcipients;
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
    this.inactiveExcipients = const [],
    this.standardInstructions = '',
  });
}

class MedicinesDatabase {
  static const List<MedicineTemplate> repository = [
    // --- Analgesics & Antipyretics ---
    MedicineTemplate(
      name: 'Panadol',
      genericName: 'Paracetamol',
      drugClass: 'Analgesic / Antipyretic',
      commonDosages: ['500 mg', '1000 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.nausea],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['paracetamol', 'acetaminophen'],
      inactiveExcipients: ['corn starch', 'potassium sorbate', 'povidone', 'magnesium stearate'],
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
      inactiveExcipients: ['corn starch', 'sodium starch glycolate', 'powdered cellulose', 'magnesium stearate'],
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
      allergenTriggers: ['ibuprofen', 'nsaid', 'aspirin', 'salicylate'],
      inactiveExcipients: ['gelatin', 'sorbitol', 'corn starch', 'parabens'],
      standardInstructions: 'Always take with food or milk to prevent stomach upset.',
    ),
    MedicineTemplate(
      name: 'Aspirin',
      genericName: 'Acetylsalicylic Acid',
      drugClass: 'Salicylate / Antiplatelet / NSAID',
      commonDosages: ['81 mg', '325 mg', '500 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.stomachUpset, SideEffectType.nausea],
      preConditions: [ConditionType.meal, ConditionType.drinkWater],
      allergenTriggers: ['aspirin', 'salicylate', 'nsaid'],
      inactiveExcipients: ['corn starch', 'hypromellose', 'triacetin'],
      standardInstructions: 'Take with food and full glass of water. Report unusual bruising.',
    ),
    MedicineTemplate(
      name: 'Celebrex',
      genericName: 'Celecoxib',
      drugClass: 'COX-2 Selective NSAID',
      commonDosages: ['100 mg', '200 mg'],
      defaultForm: MedicationForm.capsule,
      knownSideEffects: [SideEffectType.stomachUpset, SideEffectType.headache],
      preConditions: [ConditionType.meal],
      allergenTriggers: ['celebrex', 'celecoxib', 'sulfa', 'sulfonamide', 'nsaid'],
      inactiveExcipients: ['lactose monohydrate', 'gelatin', 'sodium lauryl sulfate', 'povidone'],
      standardInstructions: 'Take with food. Contains sulfonamide moiety.',
    ),

    // --- Antibiotics (Beta-Lactams, Sulfas, Macrolides, Quinolones) ---
    MedicineTemplate(
      name: 'Amoxil',
      genericName: 'Amoxicillin',
      drugClass: 'Penicillin Antibiotic (Beta-Lactam)',
      commonDosages: ['250 mg', '500 mg', '875 mg'],
      defaultForm: MedicationForm.capsule,
      knownSideEffects: [SideEffectType.nausea, SideEffectType.stomachUpset],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['amoxicillin', 'penicillin', 'beta-lactam', 'ampicillin'],
      inactiveExcipients: ['gelatin', 'magnesium stearate', 'titanium dioxide'],
      standardInstructions: 'Complete full prescribed course even if symptoms resolve.',
    ),
    MedicineTemplate(
      name: 'Augmentin',
      genericName: 'Amoxicillin / Clavulanate Potassium',
      drugClass: 'Penicillin / Beta-Lactamase Inhibitor',
      commonDosages: ['375 mg', '625 mg', '1000 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.stomachUpset, SideEffectType.nausea],
      preConditions: [ConditionType.meal],
      allergenTriggers: ['amoxicillin', 'penicillin', 'clavulanate', 'beta-lactam'],
      inactiveExcipients: ['colloidal silicon dioxide', 'hypromellose', 'magnesium stearate'],
      standardInstructions: 'Take at the start of a meal to enhance absorption and reduce GI upset.',
    ),
    MedicineTemplate(
      name: 'Keflex',
      genericName: 'Cephalexin',
      drugClass: 'First-Generation Cephalosporin (Beta-Lactam)',
      commonDosages: ['250 mg', '500 mg'],
      defaultForm: MedicationForm.capsule,
      knownSideEffects: [SideEffectType.nausea, SideEffectType.stomachUpset],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['cephalexin', 'keflex', 'cephalosporin', 'penicillin'],
      inactiveExcipients: ['gelatin', 'magnesium stearate', 'silicon dioxide'],
      standardInstructions: 'Shares R1 side chain with ampicillin. Cross-reacts with severe penicillin allergy.',
    ),
    MedicineTemplate(
      name: 'Bactrim',
      genericName: 'Sulfamethoxazole / Trimethoprim',
      drugClass: 'Sulfonamide Antibiotic (Arylamine)',
      commonDosages: ['400/80 mg', '800/160 mg DS'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.nausea, SideEffectType.stomachUpset],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['sulfamethoxazole', 'sulfa', 'sulfonamide', 'bactrim', 'septra'],
      inactiveExcipients: ['magnesium stearate', 'pregelatinized starch', 'sodium starch glycolate'],
      standardInstructions: 'Drink plenty of water to prevent crystalluria. Avoid prolonged sun exposure.',
    ),
    MedicineTemplate(
      name: 'Zithromax',
      genericName: 'Azithromycin',
      drugClass: 'Macrolide Antibiotic',
      commonDosages: ['250 mg', '500 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.nausea, SideEffectType.stomachUpset],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['azithromycin', 'macrolide', 'erythromycin', 'clarithromycin'],
      inactiveExcipients: ['lactose monohydrate', 'corn starch', 'croscarmellose sodium', 'magnesium stearate'],
      standardInstructions: 'Take once daily. Can be taken with or without meals.',
    ),
    MedicineTemplate(
      name: 'Cipro',
      genericName: 'Ciprofloxacin',
      drugClass: 'Fluoroquinolone Antibiotic',
      commonDosages: ['250 mg', '500 mg', '750 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.nausea, SideEffectType.dizziness, SideEffectType.headache],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['ciprofloxacin', 'fluoroquinolone', 'quinolone', 'levofloxacin'],
      inactiveExcipients: ['corn starch', 'microcrystalline cellulose', 'silicon dioxide', 'hypromellose'],
      standardInstructions: 'Avoid calcium, dairy, or antacids within 2 hours of taking.',
    ),

    // --- Respiratory & Inhalers (Lactose Carrier) ---
    MedicineTemplate(
      name: 'Advair Diskus',
      genericName: 'Fluticasone Propionate / Salmeterol',
      drugClass: 'Inhaled Corticosteroid / LABA Bronchodilator',
      commonDosages: ['100/50 mcg', '250/50 mcg', '500/50 mcg'],
      defaultForm: MedicationForm.inhaler,
      knownSideEffects: [SideEffectType.dryMouth, SideEffectType.headache],
      postConditions: [ConditionType.drinkWater],
      allergenTriggers: ['fluticasone', 'salmeterol', 'milk', 'dairy', 'lactose'],
      inactiveExcipients: ['lactose monohydrate (contains milk proteins)'],
      standardInstructions: 'Rinse mouth with water and spit after inhalation. CONTRAINDICATED in severe milk protein allergy.',
    ),
    MedicineTemplate(
      name: 'Ventolin HFA',
      genericName: 'Albuterol Sulfate',
      drugClass: 'Short-Acting Beta2 Agonist (SABA)',
      commonDosages: ['90 mcg/actuation'],
      defaultForm: MedicationForm.inhaler,
      knownSideEffects: [SideEffectType.insomnia, SideEffectType.dizziness],
      allergenTriggers: ['albuterol', 'salbutamol'],
      inactiveExcipients: ['hfa-134a (propellant)', 'ethanol'],
      standardInstructions: 'Inhale 2 puffs every 4-6 hours as needed for bronchospasm. Rinse mouth.',
    ),

    // --- Cardiovascular, Diabetes & Metabolic ---
    MedicineTemplate(
      name: 'Glucophage',
      genericName: 'Metformin Hydrochloride',
      drugClass: 'Biguanide Antihyperglycemic',
      commonDosages: ['500 mg', '850 mg', '1000 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.stomachUpset, SideEffectType.nausea],
      preConditions: [ConditionType.meal, ConditionType.drinkWater],
      allergenTriggers: ['metformin'],
      inactiveExcipients: ['hypromellose', 'magnesium stearate', 'polyethylene glycol (peg)', 'povidone'],
      standardInstructions: 'Always take with meals to reduce gastrointestinal adverse effects.',
    ),
    MedicineTemplate(
      name: 'Lipitor',
      genericName: 'Atorvastatin Calcium',
      drugClass: 'HMG-CoA Reductase Inhibitor (Statin)',
      commonDosages: ['10 mg', '20 mg', '40 mg', '80 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.headache],
      postConditions: [ConditionType.sleep],
      allergenTriggers: ['atorvastatin', 'statin'],
      inactiveExcipients: ['calcium carbonate', 'lactose monohydrate', 'microcrystalline cellulose', 'polysorbate 80'],
      standardInstructions: 'Take once daily in the evening or at bedtime. Avoid large amounts of grapefruit juice.',
    ),
    MedicineTemplate(
      name: 'Zestril',
      genericName: 'Lisinopril',
      drugClass: 'ACE Inhibitor',
      commonDosages: ['5 mg', '10 mg', '20 mg', '40 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.dizziness, SideEffectType.headache],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['lisinopril', 'ace inhibitor', 'angioedema'],
      inactiveExcipients: ['calcium phosphate', 'mannitol', 'corn starch', 'magnesium stearate'],
      standardInstructions: 'Take at the same time each day. Report any swelling of face, lips, or tongue immediately.',
    ),

    // --- Hormone & Special Excipient Vehicles ---
    MedicineTemplate(
      name: 'Prometrium',
      genericName: 'Progesterone',
      drugClass: 'Progestin Hormone',
      commonDosages: ['100 mg', '200 mg'],
      defaultForm: MedicationForm.capsule,
      knownSideEffects: [SideEffectType.drowsiness, SideEffectType.dizziness],
      postConditions: [ConditionType.sleep],
      allergenTriggers: ['progesterone', 'peanut', 'peanut oil', 'arachis oil'],
      inactiveExcipients: ['peanut oil', 'gelatin', 'glycerin', 'titanium dioxide'],
      standardInstructions: 'Contains peanut oil. ABSOLUTE CONTRAINDICATION for peanut allergy. Take at bedtime.',
    ),
    MedicineTemplate(
      name: 'Depo-Testosterone',
      genericName: 'Testosterone Cypionate',
      drugClass: 'Androgen Anabolic Steroid',
      commonDosages: ['100 mg/mL', '200 mg/mL'],
      defaultForm: MedicationForm.injection,
      knownSideEffects: [],
      allergenTriggers: ['testosterone', 'sesame', 'sesame oil'],
      inactiveExcipients: ['sesame oil', 'benzyl benzoate', 'benzyl alcohol'],
      standardInstructions: 'For deep intramuscular gluteal injection only. Vehicle is sesame oil.',
    ),

    // --- Gastrointestinal & Acid Suppression ---
    MedicineTemplate(
      name: 'Prilosec',
      genericName: 'Omeprazole',
      drugClass: 'Proton Pump Inhibitor (PPI)',
      commonDosages: ['20 mg', '40 mg'],
      defaultForm: MedicationForm.capsule,
      knownSideEffects: [SideEffectType.headache, SideEffectType.stomachUpset],
      preConditions: [ConditionType.emptyStomach, ConditionType.drinkWater],
      allergenTriggers: ['omeprazole', 'ppi', 'esomeprazole'],
      inactiveExcipients: ['gelatin', 'lactose', 'sodium lauryl sulfate', 'tartrazine (in some strengths)'],
      standardInstructions: 'Take 30 to 60 minutes before breakfast on an empty stomach with water.',
    ),

    // --- Sleep & Antihistamines ---
    MedicineTemplate(
      name: 'Benadryl',
      genericName: 'Diphenhydramine Hydrochloride',
      drugClass: 'First-Generation Antihistamine / Sleep Aid',
      commonDosages: ['25 mg', '50 mg'],
      defaultForm: MedicationForm.capsule,
      knownSideEffects: [SideEffectType.drowsiness, SideEffectType.dryMouth, SideEffectType.dizziness],
      postConditions: [ConditionType.sleep],
      allergenTriggers: ['diphenhydramine', 'antihistamine'],
      inactiveExcipients: ['gelatin', 'glycerin', 'sorbitol', 'fd&c red no. 40'],
      standardInstructions: 'Take 30 minutes before bedtime. Do not drive or operate machinery.',
    ),
  ];

  static List<MedicineTemplate> search(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return [];
    return repository.where((t) {
      return t.name.toLowerCase().contains(clean) ||
          t.genericName.toLowerCase().contains(clean) ||
          t.drugClass.toLowerCase().contains(clean);
    }).toList();
  }

  static MedicineTemplate? findByName(String name) {
    final clean = name.trim().toLowerCase();
    for (final template in repository) {
      if (template.name.toLowerCase() == clean ||
          template.genericName.toLowerCase() == clean) {
        return template;
      }
    }
    for (final template in repository) {
      if (clean.contains(template.name.toLowerCase()) ||
          clean.contains(template.genericName.toLowerCase())) {
        return template;
      }
    }
    return null;
  }
}
