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
  final List<String> clinicalConsiderations;
  final List<String> foodRestrictions;
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
    this.clinicalConsiderations = const [],
    this.foodRestrictions = const [],
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
      clinicalConsiderations: [
        'Maximum 4,000 mg in 24 hours to prevent hepatotoxicity',
        'Avoid concurrent alcohol consumption',
        'Check labels of combination cough/cold remedies to prevent accidental overdose',
      ],
      foodRestrictions: [
        'Avoid alcohol consumption to prevent acute liver toxicity',
      ],
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
      clinicalConsiderations: [
        'Safe first-line option for patients with mild NSAID/aspirin intolerance',
        'Monitor liver function with chronic daily administration',
      ],
      foodRestrictions: [
        'Avoid alcoholic beverages while taking acetaminophen',
      ],
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
      clinicalConsiderations: [
        'Always take with food or milk to safeguard gastric mucosa',
        'Contraindicated in active peptic ulcer disease and severe renal impairment',
        'Cross-reactive in Aspirin-Exacerbated Respiratory Disease (AERD / Samter Triad)',
      ],
      foodRestrictions: [
        'Always take with food or milk to buffer gastric acid',
        'Strictly avoid alcohol (sharply increases risk of stomach bleeding and ulcers)',
      ],
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
      clinicalConsiderations: [
        'Report any black/tarry stools or unusual petechial bruising immediately',
        'Never administer to children or adolescents with viral fever (Reye syndrome)',
      ],
      foodRestrictions: [
        'Take with meals or milk to protect stomach lining',
        'Avoid alcohol (significantly heightens gastrointestinal bleeding risk)',
      ],
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
      clinicalConsiderations: [
        'Contains chemical sulfonamide moiety; monitor in documented sulfa allergy',
        'Lower gastrointestinal toxicity risk compared to non-selective NSAIDs',
      ],
      foodRestrictions: [
        'Take with a meal or snack to minimize gastrointestinal discomfort',
      ],
      standardInstructions: 'Take with food. Contains sulfonamide moiety.',
    ),

    // --- Antibiotics (Beta-Lactams, Sulfas, Macrolides, Quinolones, Tetracyclines) ---
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
      clinicalConsiderations: [
        'Cross-reactive with Ampicillin and first-generation cephalosporins (shared R1 side chain)',
        'Complete the entire prescribed antibacterial regimen',
      ],
      foodRestrictions: [
        'Can be taken with or without food; take with food if nausea or stomach discomfort occurs',
      ],
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
      clinicalConsiderations: [
        'Clavulanate increases gastrointestinal motility; take strictly with first bite of food',
        'Avoid in patients with prior amoxicillin/clavulanate cholestatic jaundice history',
      ],
      foodRestrictions: [
        'Take right at the start of a meal to enhance absorption and drastically reduce nausea/diarrhea',
      ],
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
      clinicalConsiderations: [
        'High cross-reactivity with Ampicillin due to identical R1 side chain',
        'Use cautiously if patient had severe anaphylaxis to penicillins',
      ],
      foodRestrictions: [
        'Can be taken with meals or milk if stomach upset occurs',
      ],
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
      clinicalConsiderations: [
        'Maintain daily fluid intake of at least 2 liters to prevent urinary crystalluria',
        'Avoid direct sunlight and tanning beds (high photosensitivity risk)',
        'Monitor potassium levels when co-administered with ACE inhibitors or spironolactone',
      ],
      foodRestrictions: [
        'Drink at least 6-8 full glasses of water daily to prevent renal crystal formation',
        'Avoid potassium-rich salt substitutes without clinician supervision',
      ],
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
      clinicalConsiderations: [
        'Caution in patients with cardiac conduction disorders (risk of QT prolongation)',
        'Contains lactose monohydrate filler; flag for severe dairy anaphylaxis',
      ],
      foodRestrictions: [
        'Can be taken with or without food; take with a light meal if stomach distress occurs',
      ],
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
      clinicalConsiderations: [
        'Do not take with dairy, calcium-fortified juices, or antacids within 2 hours',
        'Black box warning for tendonitis and tendon rupture; stop immediately if pain occurs',
        'Causes severe photosensitivity; wear sunscreen and protective clothing',
      ],
      foodRestrictions: [
        'Strictly avoid milk, yogurt, calcium-fortified juice, or antacids within 2 hours before or after taking (calcium chelates and inhibits absorption)',
        'Limit excessive coffee and caffeinated energy drinks (ciprofloxacin blocks caffeine metabolism)',
      ],
      standardInstructions: 'Avoid calcium, dairy, or antacids within 2 hours of taking.',
    ),
    MedicineTemplate(
      name: 'Vibramycin',
      genericName: 'Doxycycline Hyclate',
      drugClass: 'Tetracycline Antibiotic',
      commonDosages: ['50 mg', '100 mg'],
      defaultForm: MedicationForm.capsule,
      knownSideEffects: [SideEffectType.nausea, SideEffectType.stomachUpset],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['doxycycline', 'tetracycline', 'minocycline'],
      inactiveExcipients: ['gelatin', 'lactose monohydrate', 'magnesium stearate'],
      clinicalConsiderations: [
        'Take with a full 250ml glass of water and remain upright for at least 30 minutes to prevent pill-induced esophagitis',
        'Avoid dairy, iron, calcium, and magnesium within 2 hours',
        'Causes marked cutaneous photosensitivity (sunburn risk)',
      ],
      foodRestrictions: [
        'Do NOT consume dairy products (milk, cheese, yogurt) or iron supplements within 2 hours of dose (cation chelation blocks absorption)',
        'Drink a full glass of water and stay upright for 30 minutes',
      ],
      standardInstructions: 'Take with a full glass of water. Do not lie down for 30 minutes after taking.',
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
      inactiveExcipients: ['lactose monohydrate (contains trace milk proteins)'],
      clinicalConsiderations: [
        'STRICT CONTRAINDICATION for patients with severe IgE-mediated cow milk protein allergy',
        'Rinse mouth thoroughly with water and spit out after each use to prevent oral candidiasis (thrush)',
      ],
      foodRestrictions: [
        'Rinse mouth thoroughly with water and spit out immediately after each dose before eating',
      ],
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
      clinicalConsiderations: [
        'Rescue inhaler for acute bronchospasm; keep immediately accessible at all times',
        'May cause temporary tachycardia, palpitations, and fine skeletal muscle tremor',
      ],
      foodRestrictions: [],
      standardInstructions: 'Inhale 2 puffs every 4-6 hours as needed for bronchospasm. Rinse mouth.',
    ),
    MedicineTemplate(
      name: 'Singulair',
      genericName: 'Montelukast Sodium',
      drugClass: 'Leukotriene Receptor Antagonist (LTRA)',
      commonDosages: ['4 mg chewable', '5 mg chewable', '10 mg tablet'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.headache],
      postConditions: [ConditionType.sleep],
      allergenTriggers: ['montelukast', 'aspartame', 'phenylalanine'],
      inactiveExcipients: ['aspartame (in chewables)', 'cherry flavor', 'hydroxypropyl cellulose'],
      clinicalConsiderations: [
        'Chewable formulation contains Aspartame (metabolizes to Phenylalanine); caution in PKU',
        'FDA Black box advisory for neuropsychiatric events (mood/sleep disturbances); take in evening',
      ],
      foodRestrictions: [
        'Can be taken with or without food. Take in the evening.',
      ],
      standardInstructions: 'Take once daily in the evening. Report changes in mood or sleep behavior.',
    ),

    // --- Cardiovascular, Diabetes & Thyroid ---
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
      clinicalConsiderations: [
        'Always take with meals to reduce gastrointestinal cramps and diarrhea',
        'Temporarily discontinue prior to iodinated contrast radiological procedures',
        'Periodic monitoring of eGFR renal status and serum Vitamin B12 recommended',
      ],
      foodRestrictions: [
        'Take strictly with or right after meals to prevent stomach distress',
        'Strictly avoid excessive or acute alcohol intake (heightens risk of dangerous lactic acidosis)',
      ],
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
      clinicalConsiderations: [
        'Avoid large quantities of grapefruit juice (CYP3A4 inhibition increases statin toxicity)',
        'Report unexplained muscle tenderness, cramps, or dark tea-colored urine promptly',
        'Take in the evening or at bedtime for circadian alignment with hepatic cholesterol synthesis',
      ],
      foodRestrictions: [
        'Strictly avoid grapefruit and grapefruit juice (potent CYP3A4 inhibition causes dangerous toxic blood levels and muscle breakdown/rhabdomyolysis)',
      ],
      standardInstructions: 'Take once daily in the evening or at bedtime. Avoid large amounts of grapefruit juice.',
    ),
    MedicineTemplate(
      name: 'Coumadin',
      genericName: 'Warfarin Sodium',
      drugClass: 'Vitamin K Antagonist Anticoagulant',
      commonDosages: ['1 mg', '2 mg', '2.5 mg', '5 mg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.nausea],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['warfarin', 'coumadin'],
      inactiveExcipients: ['lactose', 'corn starch', 'magnesium stearate'],
      clinicalConsiderations: [
        'High bleeding hazard; requires regular INR monitoring',
        'Avoid sudden changes in diet affecting Vitamin K levels',
      ],
      foodRestrictions: [
        'Keep dietary intake of Vitamin K consistent (kale, spinach, broccoli, brussels sprouts); do not suddenly increase or stop',
        'Strictly avoid cranberry juice and alcohol (destabilizes INR and promotes major hemorrhage)',
      ],
      standardInstructions: 'Take at the same time each evening. Keep Vitamin K food intake consistent.',
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
      clinicalConsiderations: [
        'Seek emergency medical care if angioedema (swelling of lips, tongue, throat) develops',
        'Avoid potassium-containing salt substitutes; risk of hyperkalemia',
        'Dry non-productive cough is bradykinin-mediated and does not indicate allergy',
      ],
      foodRestrictions: [
        'Avoid potassium-containing salt substitutes and excessive high-potassium foods (bananas, dried fruits) without clinical advice',
      ],
      standardInstructions: 'Take at the same time each day. Report any swelling of face, lips, or tongue immediately.',
    ),
    MedicineTemplate(
      name: 'Synthroid',
      genericName: 'Levothyroxine Sodium',
      drugClass: 'Thyroid Hormone',
      commonDosages: ['25 mcg', '50 mcg', '75 mcg', '100 mcg', '125 mcg'],
      defaultForm: MedicationForm.pill,
      knownSideEffects: [SideEffectType.insomnia],
      preConditions: [ConditionType.emptyStomach, ConditionType.drinkWater],
      allergenTriggers: ['levothyroxine', 'thyroid'],
      inactiveExcipients: ['acacia', 'confectioner sugar', 'lactose monohydrate', 'magnesium stearate'],
      clinicalConsiderations: [
        'Take with a full glass of water on an empty stomach 30 to 60 minutes before breakfast',
        'Do not take with calcium, iron, or soy products within 4 hours (drastically reduces absorption)',
      ],
      foodRestrictions: [
        'Take with plain water 30-60 minutes before breakfast on an empty stomach',
        'Strictly avoid soy products, high-fiber cereals, walnuts, espresso/coffee, calcium, or iron within 4 hours (drastically impedes hormone absorption)',
      ],
      standardInstructions: 'Take on an empty stomach 30-60 minutes before breakfast with a full glass of water.',
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
      clinicalConsiderations: [
        'ABSOLUTE HARD-STOP CONTRAINDICATION in patients with documented peanut allergy',
        'Suspended in pharmaceutical peanut oil (Arachis hypogaea); take at bedtime due to sedation',
      ],
      foodRestrictions: [
        'Contraindicated for peanut allergy patients. Take with water at bedtime.',
      ],
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
      clinicalConsiderations: [
        'Vehicle is sesame oil; verify sesame seed allergy status before administration',
        'Deep gluteal intramuscular injection only; monitor hematocrit and liver profiles',
      ],
      foodRestrictions: [],
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
      clinicalConsiderations: [
        'Take 30 to 60 minutes before morning meal for optimal parietal cell proton pump inhibition',
        'Swallow whole; do not chew or crush delayed-release enteric pellets',
      ],
      foodRestrictions: [
        'Take on an empty stomach 30 to 60 minutes before morning breakfast for optimal acid suppression',
      ],
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
      clinicalConsiderations: [
        'Causes pronounced central nervous system sedation; do not drive or operate machinery',
        'Anticholinergic effects (dry mouth, urinary retention, blurred vision); caution in elderly',
      ],
      foodRestrictions: [
        'Strictly avoid alcohol (causes dangerous additive sedation and central nervous system depression)',
      ],
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
