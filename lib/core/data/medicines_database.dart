// Comprehensive Clinical Medicines Database for MediSync
// Contains clinical profiles, active ingredients, danger levels, prescription
// requirements, administration cautions (including crushing & powdering prohibitions),
// allergy cross-reactivities, and emergency adverse signs.

import '../models/condition.dart';
import '../models/medication.dart';
import '../models/side_effect.dart';

enum DangerLevel {
  low,       // OTC, wide safety margin, low organ toxicity risk
  moderate,  // Prescription required, moderate monitoring or specific dietary rules
  high,      // Narrow therapeutic margin, potential organ toxicity, strict adherence required
  critical,  // Controlled substance, black box caution, severe dependence or life-threatening toxicity
}

enum PrescriptionRequirement {
  otc,                  // Over-the-counter (no prescription needed)
  prescription,         // Doctor prescription required (Rx)
  specialistControlled, // Controlled substance or strict hospital/specialist oversight
}

class MedicineTemplate {
  final String name;
  final String genericName;
  final String drugClass;
  final List<String> activeIngredients;
  final List<String> commonDosages;
  final MedicationForm defaultForm;
  final DangerLevel dangerLevel;
  final NecessityLevel necessityLevel;
  final String? skipConsequences;
  final PrescriptionRequirement prescriptionRequirement;
  final List<SideEffectType> knownSideEffects;
  final List<ConditionType> preConditions;
  final List<ConditionType> postConditions;
  final List<String> allergenTriggers;
  final List<String> inactiveExcipients;
  final List<String> clinicalConsiderations;
  final List<String> administrationCautions;
  final List<String> emergencySigns;
  final String afterEffectsAndRecovery;
  final String storageInstructions;
  final List<String> foodRestrictions;
  final String standardInstructions;

  const MedicineTemplate({
    required this.name,
    required this.genericName,
    required this.drugClass,
    required this.commonDosages,
    this.activeIngredients = const [],
    this.defaultForm = MedicationForm.pill,
    this.dangerLevel = DangerLevel.low,
    this.necessityLevel = NecessityLevel.moderate,
    this.skipConsequences,
    this.prescriptionRequirement = PrescriptionRequirement.prescription,
    this.knownSideEffects = const [],
    this.preConditions = const [],
    this.postConditions = const [],
    this.allergenTriggers = const [],
    this.inactiveExcipients = const [],
    this.clinicalConsiderations = const [],
    this.administrationCautions = const [],
    this.emergencySigns = const [],
    this.afterEffectsAndRecovery = '',
    this.storageInstructions = 'Store below 25°C in a dry place away from direct sunlight.',
    this.foodRestrictions = const [],
    this.standardInstructions = '',
  });
}

class MedicinesDatabase {
  static const List<MedicineTemplate> repository = [
    MedicineTemplate(
      name: 'Panadol',
      genericName: 'Paracetamol',
      drugClass: 'Analgesic / Antipyretic',
      activeIngredients: ['Paracetamol (Acetaminophen) 500 mg'],
      commonDosages: ['500 mg', '1000 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.low,
      prescriptionRequirement: PrescriptionRequirement.otc,
      knownSideEffects: [SideEffectType.nausea],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['paracetamol', 'acetaminophen'],
      inactiveExcipients: ['corn starch', 'potassium sorbate', 'povidone', 'magnesium stearate'],
      administrationCautions: [
        '❌ NEVER crush, chew, or make powder out of tablets to swallow or snort. Swallow whole with a full glass of water.',
        '❌ ABSOLUTE MAXIMUM: Never exceed 4,000 mg (8 x 500mg tablets) in 24 hours. Exceeding this limit causes irreversible liver necrosis.',
        '❌ NEVER combine with other cough, cold, sinus, or flu remedies without checking their labels for Paracetamol / Acetaminophen.',
        '⚠️ Strictly avoid alcohol consumption while taking Paracetamol; concurrent alcohol drastically accelerates liver toxicity.',
      ],
      emergencySigns: [
        'Upper right abdominal pain, yellowing of skin or eyes (jaundice), severe nausea/vomiting, dark urine.',
      ],
      afterEffectsAndRecovery: 'Takes 30 to 45 minutes to relieve pain or reduce fever. Duration of action is 4 to 6 hours. Cleared from body within 24 hours.',
      storageInstructions: 'Store below 25°C in a dry place protected from heat and direct sunlight.',
      clinicalConsiderations: [
        'Maximum 4,000 mg in 24 hours to prevent hepatotoxicity',
        'Avoid concurrent alcohol consumption',
        'Check labels of combination cough/cold remedies to prevent accidental overdose',
      ],
      foodRestrictions: [
        'Avoid alcohol consumption to prevent acute liver toxicity',
      ],
      standardInstructions: 'Take with a glass of water. Do not exceed 4000 mg in 24 hours.',
    )
,
    MedicineTemplate(
      name: 'Tylenol',
      genericName: 'Acetaminophen',
      drugClass: 'Analgesic / Antipyretic',
      activeIngredients: ['Acetaminophen 325 mg / 500 mg / 650 mg'],
      commonDosages: ['325 mg', '500 mg', '650 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.low,
      prescriptionRequirement: PrescriptionRequirement.otc,
      knownSideEffects: [SideEffectType.nausea],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['acetaminophen', 'paracetamol'],
      inactiveExcipients: ['corn starch', 'sodium starch glycolate', 'powdered cellulose', 'magnesium stearate'],
      administrationCautions: [
        '❌ NEVER crush, chew, or turn into powder. Extended-release caplets must be swallowed intact.',
        '❌ Overdose risk: maximum single adult dose is 1,000 mg; maximum 24-hour total is 4,000 mg.',
        '⚠️ Avoid taking alongside other OTC pain or allergy formulations containing acetaminophen.',
      ],
      emergencySigns: [
        'Severe abdominal cramping, pale skin, sweating, extreme fatigue, yellowing eyes.',
      ],
      afterEffectsAndRecovery: 'Pain relief within 30-60 minutes. Cleared by liver metabolism in 12-24 hours.',
      storageInstructions: 'Store at 20°C to 25°C (68°F to 77°F). Avoid excess humidity.',
      clinicalConsiderations: [
        'Safe first-line option for patients with mild NSAID/aspirin intolerance',
        'Monitor liver function with chronic daily administration',
      ],
      foodRestrictions: [
        'Avoid alcoholic beverages while taking acetaminophen',
      ],
      standardInstructions: 'Take with water. Avoid alcohol while taking.',
    )
,
    MedicineTemplate(
      name: 'Advil',
      genericName: 'Ibuprofen',
      drugClass: 'NSAID (Non-Steroidal Anti-inflammatory)',
      activeIngredients: ['Ibuprofen 200 mg / 400 mg'],
      commonDosages: ['200 mg', '400 mg', '600 mg'],
      defaultForm: MedicationForm.capsule,
      dangerLevel: DangerLevel.moderate,
      prescriptionRequirement: PrescriptionRequirement.otc,
      knownSideEffects: [SideEffectType.stomachUpset, SideEffectType.nausea],
      preConditions: [ConditionType.meal, ConditionType.drinkWater],
      allergenTriggers: ['ibuprofen', 'nsaid', 'aspirin', 'salicylate'],
      inactiveExcipients: ['gelatin', 'sorbitol', 'corn starch', 'parabens'],
      administrationCautions: [
        '❌ NEVER take on an empty stomach. Always take with or immediately after a full meal or glass of milk.',
        '❌ DO NOT crush, chew, or open liquid-filled softgels or coated tablets.',
        '❌ CONTRAINDICATED in active stomach ulcers, GI bleeding, severe kidney failure, or late pregnancy.',
        '⚠️ Strictly avoid alcohol; mixing NSAIDs with alcohol multiplies the risk of gastric perforation and bleeding.',
      ],
      emergencySigns: [
        'Black/tarry stools, coughing or vomiting blood (coffee-ground emesis), sudden severe stomach pain, chest tightness.',
      ],
      afterEffectsAndRecovery: 'Anti-inflammatory effect begins in 1-2 hours. Mild stomach sensitivity may linger. Drink plenty of fluids.',
      storageInstructions: 'Store at 20°C to 25°C. Avoid excessive heat above 40°C.',
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
    )
,
    MedicineTemplate(
      name: 'Aspirin',
      genericName: 'Acetylsalicylic Acid',
      drugClass: 'Salicylate / Antiplatelet / NSAID',
      activeIngredients: ['Acetylsalicylic Acid 81 mg (Cardio) / 325 mg / 500 mg'],
      commonDosages: ['81 mg', '325 mg', '500 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.moderate,
      prescriptionRequirement: PrescriptionRequirement.otc,
      knownSideEffects: [SideEffectType.stomachUpset, SideEffectType.nausea],
      preConditions: [ConditionType.meal, ConditionType.drinkWater],
      allergenTriggers: ['aspirin', 'salicylate', 'nsaid'],
      inactiveExcipients: ['corn starch', 'hypromellose', 'triacetin'],
      administrationCautions: [
        '❌ FATAL WARNING: NEVER give aspirin to children or teenagers under 18 suffering from fever or viral illness (causes fatal Reye Syndrome).',
        '❌ DO NOT crush or chew enteric-coated (EC) or extended-release tablets; doing so destroys gastric protection.',
        '⚠️ Always take with a full meal and a large glass of water to protect gastric mucosa.',
        '⚠️ Consult your surgeon before any planned dental or surgical procedures due to prolonged antiplatelet bleeding risk.',
      ],
      emergencySigns: [
        'Ringing in ears (tinnitus), black tarry stools, unexplained large bruises, blood in urine.',
      ],
      afterEffectsAndRecovery: 'Antiplatelet effect lasts for the lifetime of the platelet (7-10 days). Minor bruising may occur.',
      storageInstructions: 'Store below 25°C in a tightly closed container away from moisture. Discard if it smells of vinegar.',
      clinicalConsiderations: [
        'Report any black/tarry stools or unusual petechial bruising immediately',
        'Never administer to children or adolescents with viral fever (Reye syndrome)',
      ],
      foodRestrictions: [
        'Take with meals or milk to protect stomach lining',
        'Avoid alcohol (significantly heightens gastrointestinal bleeding risk)',
      ],
      standardInstructions: 'Take with food and full glass of water. Report unusual bruising.',
    )
,
    MedicineTemplate(
      name: 'Aleve',
      genericName: 'Naproxen Sodium',
      drugClass: 'NSAID (Long-Acting Anti-inflammatory)',
      activeIngredients: ['Naproxen Sodium 220 mg'],
      commonDosages: ['220 mg', '500 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.moderate,
      prescriptionRequirement: PrescriptionRequirement.otc,
      knownSideEffects: [SideEffectType.stomachUpset, SideEffectType.headache, SideEffectType.dizziness],
      preConditions: [ConditionType.meal, ConditionType.drinkWater],
      allergenTriggers: ['naproxen', 'nsaid', 'aspirin'],
      inactiveExcipients: ['microcrystalline cellulose', 'povidone', 'magnesium stearate'],
      administrationCautions: [
        '❌ NEVER take on an empty stomach. Always consume with food or milk.',
        '❌ DO NOT take for more than 10 consecutive days for pain unless directed by a physician.',
        '⚠️ Do not lie down for at least 10 minutes after swallowing to prevent esophageal irritation.',
      ],
      emergencySigns: [
        'Severe epigastric pain, vomiting blood, swelling of ankles or sudden weight gain, chest pain.',
      ],
      afterEffectsAndRecovery: 'Long-lasting relief (up to 12 hours). Drink 6-8 glasses of water daily.',
      storageInstructions: 'Store at 20°C to 25°C away from heat and light.',
      clinicalConsiderations: [
        'Longer half-life than ibuprofen (dosed every 12 hours)',
        'Monitor blood pressure in hypertensive patients',
      ],
      foodRestrictions: [
        'Always take with food or milk. Strictly avoid alcohol.',
      ],
      standardInstructions: 'Take 1 tablet every 8 to 12 hours with food and full glass of water.',
    )
,
    MedicineTemplate(
      name: 'Voltaren',
      genericName: 'Diclofenac Sodium',
      drugClass: 'NSAID (Potent Anti-inflammatory)',
      activeIngredients: ['Diclofenac Sodium 50 mg / 75 mg'],
      commonDosages: ['50 mg', '75 mg', '100 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.high,
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [SideEffectType.stomachUpset, SideEffectType.nausea, SideEffectType.dizziness],
      preConditions: [ConditionType.meal],
      allergenTriggers: ['diclofenac', 'nsaid', 'aspirin'],
      inactiveExcipients: ['lactose monohydrate', 'colloidal silica', 'povidone', 'magnesium stearate'],
      administrationCautions: [
        '❌ MUST be swallowed whole with water. NEVER crush, divide, or chew enteric-coated tablets.',
        '⚠️ Requires prescription; monitor cardiovascular and liver enzyme parameters with chronic use.',
        '❌ Contraindicated in patients with active coronary artery disease or recent CABG surgery.',
      ],
      emergencySigns: [
        'Shortness of breath, chest pressure, severe stomach pain, jaundice.',
      ],
      afterEffectsAndRecovery: 'Rapid pain relief. May cause slight lightheadedness; avoid high-speed driving if affected.',
      storageInstructions: 'Store below 30°C in a dry place.',
      clinicalConsiderations: [
        'Highest cardiovascular risk profile among common NSAIDs',
        'Co-prescription with a proton pump inhibitor (PPI) recommended for elderly patients',
      ],
      foodRestrictions: ['Take with or after food. Strictly avoid alcohol.'],
      standardInstructions: 'Take with food. Swallow tablet whole without chewing or crushing.',
    )
,
    MedicineTemplate(
      name: 'Ultram',
      genericName: 'Tramadol Hydrochloride',
      drugClass: 'Centrally-Acting Opioid Analgesic',
      activeIngredients: ['Tramadol Hydrochloride 50 mg'],
      commonDosages: ['50 mg', '100 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.critical,
      prescriptionRequirement: PrescriptionRequirement.specialistControlled,
      knownSideEffects: [SideEffectType.dizziness, SideEffectType.drowsiness, SideEffectType.nausea],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['tramadol', 'opioid'],
      inactiveExcipients: ['corn starch', 'lactose', 'magnesium stearate', 'hypromellose'],
      administrationCautions: [
        '❌ CONTROLLED SUBSTANCE: High risk of dependence and addiction. Take strictly as directed by a specialist.',
        '❌ NEVER CRUSH OR DISSOLVE: Crushing extended-release tablets can lead to fatal rapid opioid absorption.',
        '❌ NEVER combine with alcohol, sedatives, benzodiazepines, or other CNS depressants (causes fatal respiratory depression).',
        '⚠️ High risk of Serotonin Syndrome when taken with SSRIs/SNRIs (antidepressants).',
      ],
      emergencySigns: [
        'Extremely slow/shallow breathing, bluish lips or fingernails, severe confusion, seizure, inability to wake up.',
      ],
      afterEffectsAndRecovery: 'Causes marked drowsiness and impaired motor reflexes. DO NOT drive or operate machinery for 8 hours.',
      storageInstructions: 'Store securely locked below 25°C out of reach of children and unauthorized individuals.',
      clinicalConsiderations: [
        'Dual mechanism: mu-opioid agonist and weak serotonin/norepinephrine reuptake inhibitor',
        'Lowers seizure threshold; avoid in epileptic patients',
      ],
      foodRestrictions: ['Strictly zero alcohol. Can be taken with or without food.'],
      standardInstructions: 'Take strictly according to doctor instructions. Do not exceed prescribed frequency.',
    )
,
    MedicineTemplate(
      name: 'Amoxil',
      genericName: 'Amoxicillin',
      drugClass: 'Penicillin Antibiotic (Beta-Lactam)',
      activeIngredients: ['Amoxicillin Trihydrate 250 mg / 500 mg / 875 mg'],
      commonDosages: ['250 mg', '500 mg', '875 mg'],
      defaultForm: MedicationForm.capsule,
      dangerLevel: DangerLevel.moderate,
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [SideEffectType.nausea, SideEffectType.stomachUpset],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['amoxicillin', 'penicillin', 'beta-lactam', 'ampicillin'],
      inactiveExcipients: ['gelatin', 'magnesium stearate', 'titanium dioxide'],
      administrationCautions: [
        '⚠️ COMPLETE THE ENTIRE PRESCRIBED COURSE: Stopping early causes bacterial resistance and recurrent severe infection.',
        '❌ STRICT CONTRAINDICATION: Do NOT take if you have a documented allergy to Penicillin or Ampicillin.',
        '⚠️ Swallow capsules whole with water. Can be taken with food if stomach upset occurs.',
      ],
      emergencySigns: [
        'Sudden skin rash, hives, swelling of lips/tongue/throat, wheezing, severe watery diarrhea.',
      ],
      afterEffectsAndRecovery: 'Begins clearing infection within 48 hours. Mild digestive loose stools common; replenish with fluids or probiotic yogurt.',
      storageInstructions: 'Store capsules at room temperature (20°C to 25°C). Reconstituted oral suspension must be refrigerated.',
      clinicalConsiderations: [
        'Cross-reactive with Ampicillin and first-generation cephalosporins (shared R1 side chain)',
        'Complete the entire prescribed antibacterial regimen',
      ],
      foodRestrictions: [
        'Can be taken with or without food; take with food if nausea or stomach discomfort occurs',
      ],
      standardInstructions: 'Complete full prescribed course even if symptoms resolve.',
    )
,
    MedicineTemplate(
      name: 'Augmentin',
      genericName: 'Amoxicillin / Clavulanate Potassium',
      drugClass: 'Penicillin / Beta-Lactamase Inhibitor',
      activeIngredients: ['Amoxicillin 500 mg / 875 mg', 'Clavulanate Potassium 125 mg'],
      commonDosages: ['375 mg', '625 mg', '1000 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.moderate,
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [SideEffectType.stomachUpset, SideEffectType.nausea],
      preConditions: [ConditionType.meal],
      allergenTriggers: ['amoxicillin', 'penicillin', 'clavulanate', 'beta-lactam'],
      inactiveExcipients: ['colloidal silicon dioxide', 'hypromellose', 'magnesium stearate'],
      administrationCautions: [
        '⚠️ ALWAYS TAKE WITH THE FIRST BITE OF A MEAL: Clavulanate accelerates bowel motility; taking with food drastically reduces nausea and diarrhea.',
        '❌ COMPLETE FULL COURSE: Never stop halfway even when feeling better.',
        '❌ CONTRAINDICATED in patients with history of penicillin allergy or amoxicillin-associated cholestatic jaundice.',
        '❌ DO NOT crush film-coated tablets.',
      ],
      emergencySigns: [
        'Facial or laryngeal edema, acute wheezing, persistent bloody diarrhea (C. difficile colitis), yellow eyes/skin.',
      ],
      afterEffectsAndRecovery: 'High efficacy against resistant bacteria. Temporary altered bowel habits may take 3-5 days to normalize post-course.',
      storageInstructions: 'Store in moisture-proof blister foil below 25°C. Suspensions must be refrigerated and discarded after 10 days.',
      clinicalConsiderations: [
        'Clavulanate increases gastrointestinal motility; take strictly with first bite of food',
        'Avoid in patients with prior amoxicillin/clavulanate cholestatic jaundice history',
      ],
      foodRestrictions: [
        'Take right at the start of a meal to enhance absorption and drastically reduce nausea/diarrhea',
      ],
      standardInstructions: 'Take at the start of a meal to enhance absorption and reduce GI upset.',
    )
,
    MedicineTemplate(
      name: 'Flagyl',
      genericName: 'Metronidazole',
      drugClass: 'Nitroimidazole Antibacterial / Antiprotozoal',
      activeIngredients: ['Metronidazole 250 mg / 500 mg'],
      commonDosages: ['250 mg', '500 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.high,
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [SideEffectType.nausea, SideEffectType.headache, SideEffectType.stomachUpset],
      preConditions: [ConditionType.meal, ConditionType.drinkWater],
      allergenTriggers: ['metronidazole', 'nitroimidazole'],
      inactiveExcipients: ['hydroxypropyl cellulose', 'lactose', 'polyethylene glycol', 'titanium dioxide'],
      administrationCautions: [
        '❌ STRICT ZERO ALCOHOL WARNING: Absolutely DO NOT drink alcohol or consume alcohol-containing cough syrups during treatment AND for 48 hours after! Causes a violent disulfiram-like reaction (severe vomiting, racing pulse, chest pain).',
        '❌ Swallow tablets whole with water; do not crush due to intensely bitter metallic taste.',
        '⚠️ Harmless dark or reddish-brown urine may occur during therapy.',
      ],
      emergencySigns: [
        'Numbness, tingling or burning in hands or feet (peripheral neuropathy), seizures, stiff neck, confusion.',
      ],
      afterEffectsAndRecovery: 'Lingering metallic taste in mouth usually resolves 24-48 hours after completing the regimen.',
      storageInstructions: 'Store below 25°C protected from light.',
      clinicalConsiderations: [
        'Disulfiram-like reaction with ethanol',
        'Inhibits warfarin metabolism (increases INR substantially)',
      ],
      foodRestrictions: [
        'STRICTLY FORBIDDEN: Alcohol, wine, beer, and propylene glycol during and for 48 hours after therapy.',
      ],
      standardInstructions: 'Take with food and full glass of water. Strictly avoid all alcohol.',
    )
,
    MedicineTemplate(
      name: 'Zithromax',
      genericName: 'Azithromycin',
      drugClass: 'Macrolide Antibiotic',
      activeIngredients: ['Azithromycin Dihydrate 250 mg / 500 mg'],
      commonDosages: ['250 mg', '500 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.moderate,
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [SideEffectType.stomachUpset, SideEffectType.nausea, SideEffectType.stomachUpset],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['azithromycin', 'macrolide', 'erythromycin', 'clarithromycin'],
      inactiveExcipients: ['corn starch', 'calcium phosphate dibasic', 'lactose', 'titanium dioxide'],
      administrationCautions: [
        '⚠️ Take at least 1 hour before or 2 hours after aluminum- or magnesium-containing antacids.',
        '❌ DO NOT crush or break film-coated tablets.',
        '⚠️ Complete the exact prescribed 3-day or 5-day "Z-Pak" dosing schedule.',
      ],
      emergencySigns: [
        'Palpitations, irregular heart rhythm (QT prolongation), fainting, severe diarrhea.',
      ],
      afterEffectsAndRecovery: 'Very long tissue half-life (~68 hours). The antibiotic continues working for days after the last dose.',
      storageInstructions: 'Store below 30°C.',
      clinicalConsiderations: [
        'Can prolong cardiac QT interval; use caution with antiarrhythmics or in known arrhythmia',
        'Excellent option for penicillin-allergic respiratory infections',
      ],
      foodRestrictions: [
        'Can be taken with or without food. Separate from antacids by 2 hours.',
      ],
      standardInstructions: 'Take once daily at the same time. Separate from antacids.',
    )
,
    MedicineTemplate(
      name: 'Cipro',
      genericName: 'Ciprofloxacin',
      drugClass: 'Fluoroquinolone Antibiotic',
      activeIngredients: ['Ciprofloxacin Hydrochloride 250 mg / 500 mg'],
      commonDosages: ['250 mg', '500 mg', '750 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.high,
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [SideEffectType.nausea, SideEffectType.dizziness, SideEffectType.headache],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['ciprofloxacin', 'fluoroquinolone', 'quinolone'],
      inactiveExcipients: ['corn starch', 'microcrystalline cellulose', 'silicon dioxide'],
      administrationCautions: [
        '❌ BLACK BOX WARNING: High risk of Tendonitis and Tendon Rupture (especially Achilles tendon). Cease medication and stop exercising if joint or tendon pain occurs.',
        '❌ DO NOT take with milk, yogurt, calcium-fortified juice, or iron/zinc supplements (chelates drug, preventing absorption). Separate by 2-4 hours.',
        '⚠️ Drink 2 to 3 liters of water daily to prevent crystal formation in urine (crystalluria).',
        '⚠️ Avoid strong sunlight; causes extreme skin photosensitivity and rapid sunburn.',
      ],
      emergencySigns: [
        'Sudden popping or pain in Achilles tendon, numbness/tingling, hallucinations, rapid heartbeat.',
      ],
      afterEffectsAndRecovery: 'Rest joints during and for weeks after completing therapy. Avoid strenuous physical contact sports.',
      storageInstructions: 'Store below 25°C in a dry place.',
      clinicalConsiderations: [
        'Avoid in myasthenia gravis and elderly patients with prior tendon issues',
        'Strong inhibitor of CYP1A2 (drastically increases caffeine and theophylline levels)',
      ],
      foodRestrictions: [
        'Separate from dairy products (milk, yogurt, cheese) and calcium-fortified drinks by at least 2 hours.',
      ],
      standardInstructions: 'Drink abundant water. Separate from dairy products and antacids by 2 hours.',
    )
,
    MedicineTemplate(
      name: 'Glucophage',
      genericName: 'Metformin Hydrochloride',
      drugClass: 'Biguanide Antidiabetic',
      activeIngredients: ['Metformin Hydrochloride 500 mg / 850 mg / 1000 mg'],
      commonDosages: ['500 mg', '850 mg', '1000 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.moderate,
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [SideEffectType.stomachUpset, SideEffectType.nausea, SideEffectType.stomachUpset],
      preConditions: [ConditionType.meal, ConditionType.drinkWater],
      allergenTriggers: ['metformin', 'biguanide'],
      inactiveExcipients: ['povidone', 'magnesium stearate', 'hypromellose', 'polyethylene glycol'],
      administrationCautions: [
        '❌ NEVER crush, chew, or split Extended-Release (XR) tablets. Swallow whole with water.',
        '⚠️ ALWAYS take with or immediately after meals to reduce stomach cramps, gas, and loose stools.',
        '❌ STRICT WARNING: Temporarily withhold before and 48 hours after iodinated radiological contrast scans (protects kidney function).',
        '⚠️ Avoid excessive alcohol consumption due to the rare but life-threatening risk of Lactic Acidosis.',
      ],
      emergencySigns: [
        'Deep rapid breathing, severe muscle pain, extreme cold feeling, severe dizziness, slow irregular heartbeat (Lactic Acidosis).',
      ],
      afterEffectsAndRecovery: 'Long-term glycemic stabilization. Gastrointestinal tolerance improves significantly after 2-3 weeks of continuous therapy.',
      storageInstructions: 'Store at 20°C to 25°C away from heat and light.',
      clinicalConsiderations: [
        'First-line pharmacological agent for Type 2 Diabetes Mellitus',
        'Check serum eGFR and B12 levels annually',
      ],
      foodRestrictions: [
        'Take with meals. Strictly avoid binge drinking of alcohol.',
      ],
      standardInstructions: 'Take with or immediately after meals. Swallow extended release tablets whole.',
    )
,
    MedicineTemplate(
      name: 'Lipitor',
      genericName: 'Atorvastatin Calcium',
      drugClass: 'HMG-CoA Reductase Inhibitor (Statin)',
      activeIngredients: ['Atorvastatin Calcium 10 mg / 20 mg / 40 mg / 80 mg'],
      commonDosages: ['10 mg', '20 mg', '40 mg', '80 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.moderate,
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [SideEffectType.drowsiness, SideEffectType.nausea],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['atorvastatin', 'statin'],
      inactiveExcipients: ['calcium carbonate', 'microcrystalline cellulose', 'lactose monohydrate'],
      administrationCautions: [
        '❌ AVOID GRAPEFRUIT AND GRAPEFRUIT JUICE: Grapefruit inhibits CYP3A4, causing dangerous accumulation of atorvastatin and muscle breakdown.',
        '⚠️ Take once daily at the same time each day (evening or bedtime preferred).',
        '⚠️ Immediately report unexplained muscle ache, tenderness, or weakness.',
      ],
      emergencySigns: [
        'Severe muscle tenderness or weakness accompanied by cola-colored/tea-colored dark urine (Rhabdomyolysis), jaundice.',
      ],
      afterEffectsAndRecovery: 'Continuously lowers LDL-C. Muscle stiffness typically resolves if dose is adjusted by doctor.',
      storageInstructions: 'Store at 20°C to 25°C away from moisture.',
      clinicalConsiderations: [
        'Strongest lipid-lowering efficacy in broad clinical trials',
        'Routine liver enzymes check recommended at therapy baseline',
      ],
      foodRestrictions: [
        'Strictly avoid grapefruit and grapefruit juice (blocks liver breakdown).',
      ],
      standardInstructions: 'Take once daily at the same time. Avoid grapefruit products.',
    )
,
    MedicineTemplate(
      name: 'Norvasc',
      genericName: 'Amlodipine Besylate',
      drugClass: 'Dihydropyridine Calcium Channel Blocker',
      activeIngredients: ['Amlodipine Besylate 2.5 mg / 5 mg / 10 mg'],
      commonDosages: ['2.5 mg', '5 mg', '10 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.moderate,
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [SideEffectType.dizziness, SideEffectType.headache, SideEffectType.drowsiness],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['amlodipine', 'calcium-channel-blocker'],
      inactiveExcipients: ['microcrystalline cellulose', 'dibasic calcium phosphate anhydrous', 'sodium starch glycolate'],
      administrationCautions: [
        '⚠️ Take once daily with water. Can be taken with or without food.',
        '⚠️ Rise slowly from sitting or lying down to prevent orthostatic dizziness or fainting.',
        '⚠️ Monitor for peripheral edema (swelling of ankles or lower legs).',
      ],
      emergencySigns: [
        'Chest pain, rapid or pounding heartbeat, fainting, sudden facial flushing with severe lightheadedness.',
      ],
      afterEffectsAndRecovery: 'Very gradual blood pressure lowering over 24 hours. Peripheral ankle swelling is reversible upon dose adjustment.',
      storageInstructions: 'Store below 25°C protected from light.',
      clinicalConsiderations: [
        'Excellent once-daily antihypertensive with 24-hour hemodynamic coverage',
        'Dose-dependent peripheral ankle edema occurs in 5-10% of patients',
      ],
      foodRestrictions: ['Can be taken with or without food. Avoid excessive alcohol.'],
      standardInstructions: 'Take once daily. Rise slowly when standing up.',
    )
,
    MedicineTemplate(
      name: 'Zestril',
      genericName: 'Lisinopril',
      drugClass: 'ACE Inhibitor (Antihypertensive)',
      activeIngredients: ['Lisinopril 5 mg / 10 mg / 20 mg'],
      commonDosages: ['5 mg', '10 mg', '20 mg', '40 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.moderate,
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [SideEffectType.dizziness, SideEffectType.headache],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['lisinopril', 'ace-inhibitor'],
      inactiveExcipients: ['calcium phosphate', 'mannitol', 'corn starch', 'magnesium stearate'],
      administrationCautions: [
        '❌ BLACK BOX WARNING: CONTRAINDICATED IN PREGNANCY (causes fetal renal failure and deformity).',
        '❌ DO NOT use potassium supplements or potassium-based salt substitutes without physician approval (risk of hyperkalemia).',
        '⚠️ A persistent dry tickling cough is a known class effect; report to your doctor if unbearable.',
      ],
      emergencySigns: [
        'Swelling of face, lips, tongue, or throat (Angioedema - seek immediate ER care!), severe fainting, inability to urinate.',
      ],
      afterEffectsAndRecovery: 'Smooth blood pressure stabilization. Dry cough usually resolves within 1-2 weeks after discontinuation.',
      storageInstructions: 'Store at 20°C to 25°C protected from moisture.',
      clinicalConsiderations: [
        'Renal-protective in diabetic nephropathy',
        'Monitor serum creatinine and potassium 2 weeks after initiation',
      ],
      foodRestrictions: [
        'Avoid high-potassium dietary salt substitutes.',
      ],
      standardInstructions: 'Take once daily with water. Avoid potassium salt substitutes.',
    )
,
    MedicineTemplate(
      name: 'Ventolin HFA',
      genericName: 'Albuterol Sulfate',
      drugClass: 'Short-Acting Beta-2 Agonist (Rescue Bronchodilator)',
      activeIngredients: ['Albuterol Sulfate 90 mcg per actuation'],
      commonDosages: ['90 mcg / actuation (1-2 puffs)'],
      defaultForm: MedicationForm.inhaler,
      dangerLevel: DangerLevel.moderate,
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [SideEffectType.dizziness, SideEffectType.custom, SideEffectType.headache],
      preConditions: [],
      allergenTriggers: ['albuterol', 'salbutamol', 'beta-agonist'],
      inactiveExcipients: ['HFA-134a (propellant, chlorofluorocarbon-free)'],
      administrationCautions: [
        '⚠️ RESCUE INHALER: Shake canister thoroughly before every single actuation.',
        '⚠️ Breathe out fully, place mouthpiece in lips, depress canister while inhaling slowly and deeply, then hold breath for 10 seconds.',
        '❌ DO NOT use more than prescribed: overuse causes tachycardia, cardiac arrhythmias, and hypokalemia.',
        '⚠️ Keep track of remaining puffs on dose counter; always keep a spare in case of asthma attacks.',
      ],
      emergencySigns: [
        'Severe worsening of breathing that fails to improve within 15 minutes of inhalation, chest pain, irregular pulse.',
      ],
      afterEffectsAndRecovery: 'Opens airways within 3-5 minutes. Peak effect at 15-30 minutes. Mild hand tremors or heart flutter usually fade in 30 minutes.',
      storageInstructions: 'Store between 15°C and 25°C. Never puncture or incinerate pressurized canister.',
      clinicalConsiderations: [
        'First-line fast-acting rescue therapy for acute bronchospasm',
        'Rinse plastic actuator weekly under warm running water to prevent clogging',
      ],
      foodRestrictions: ['No food restrictions. Limit caffeine to reduce jitteriness.'],
      standardInstructions: 'Shake well. Inhale 1 to 2 puffs as needed for acute wheezing. Wait 1 min between puffs.',
    )
,
    MedicineTemplate(
      name: 'Prilosec',
      genericName: 'Omeprazole',
      drugClass: 'Proton Pump Inhibitor (PPI)',
      activeIngredients: ['Omeprazole Magnesium 20 mg / 40 mg'],
      commonDosages: ['20 mg', '40 mg'],
      defaultForm: MedicationForm.capsule,
      dangerLevel: DangerLevel.low,
      prescriptionRequirement: PrescriptionRequirement.otc,
      knownSideEffects: [SideEffectType.headache, SideEffectType.stomachUpset],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['omeprazole', 'proton-pump-inhibitor'],
      inactiveExcipients: ['hydroxypropyl cellulose', 'lactose', 'sodium lauryl sulfate', 'sugar spheres'],
      administrationCautions: [
        '⚠️ MUST be taken 30 to 60 minutes BEFORE breakfast with a full glass of water for maximal acid suppression.',
        '❌ DO NOT crush or chew delayed-release capsules or pellets. Swallow whole.',
        '⚠️ Chronic use (>1 year) requires monitoring of magnesium, calcium, and vitamin B12 levels.',
      ],
      emergencySigns: [
        'Severe watery diarrhea accompanied by fever (C. difficile), sudden wrist/hip pain (osteoporotic fracture risk), seizure.',
      ],
      afterEffectsAndRecovery: 'Suppresses stomach acid production for up to 72 hours. Rebound hyperacidity may occur if stopped abruptly after months.',
      storageInstructions: 'Store below 25°C in a dry place protected from light.',
      clinicalConsiderations: [
        'Takes 1 to 4 days of daily dosing for maximum clinical symptom relief',
        'CYP2C19 competitive inhibitor: reduces clopidogrel (Plavix) active conversion',
      ],
      foodRestrictions: [
        'Take on an empty stomach at least 30-60 minutes before morning meal.',
      ],
      standardInstructions: 'Take 30 to 60 minutes before breakfast. Swallow whole.',
    )
,
    MedicineTemplate(
      name: 'Nexium',
      genericName: 'Esomeprazole Magnesium',
      drugClass: 'Proton Pump Inhibitor (PPI)',
      activeIngredients: ['Esomeprazole Magnesium 20 mg / 40 mg'],
      commonDosages: ['20 mg', '40 mg'],
      defaultForm: MedicationForm.capsule,
      dangerLevel: DangerLevel.low,
      prescriptionRequirement: PrescriptionRequirement.otc,
      knownSideEffects: [SideEffectType.headache, SideEffectType.stomachUpset],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['esomeprazole', 'omeprazole', 'proton-pump-inhibitor'],
      inactiveExcipients: ['glyceryl monostearate', 'hydroxypropyl cellulose', 'magnesium stearate', 'sugar spheres'],
      administrationCautions: [
        '⚠️ Take 30-60 minutes before a meal (typically breakfast).',
        '❌ DO NOT crush or chew delayed-release capsules. Swallow whole.',
        '⚠️ If unable to swallow, capsule contents may be opened and sprinkled onto a tablespoon of cool applesauce and swallowed immediately.',
      ],
      emergencySigns: [
        'Persistent severe diarrhea, joint pain accompanied by skin rash (Lupus erythematous), irregular heartbeat.',
      ],
      afterEffectsAndRecovery: 'Effective gastric acid control for 24 hours. Cleared mainly by hepatic CYP2C19.',
      storageInstructions: 'Store at 20°C to 25°C with cap tightly closed.',
      clinicalConsiderations: [
        'S-isomer of omeprazole with higher bioavailability and slower elimination',
        'Standard treatment for severe erosive esophagitis',
      ],
      foodRestrictions: ['Take on an empty stomach 30 to 60 minutes before food.'],
      standardInstructions: 'Take 30 to 60 minutes before breakfast. Swallow capsule whole.',
    )
,
    MedicineTemplate(
      name: 'Zyrtec',
      genericName: 'Cetirizine Hydrochloride',
      drugClass: 'Second-Generation Antihistamine',
      activeIngredients: ['Cetirizine Hydrochloride 10 mg'],
      commonDosages: ['5 mg', '10 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.low,
      prescriptionRequirement: PrescriptionRequirement.otc,
      knownSideEffects: [SideEffectType.drowsiness, SideEffectType.dryMouth, SideEffectType.drowsiness],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['cetirizine', 'hydroxyzine', 'antihistamine'],
      inactiveExcipients: ['lactose monohydrate', 'microcrystalline cellulose', 'silicon dioxide'],
      administrationCautions: [
        '⚠️ Although non-sedating for most, it may cause mild drowsiness in ~10% of users. Exercise caution before driving.',
        '❌ Avoid consuming alcohol; alcohol amplifies drowsiness and slow reflexes.',
        '⚠️ Can be taken with or without food at any time of day (often taken at bedtime).',
      ],
      emergencySigns: [
        'Difficulty swallowing or breathing, severe dizziness, hives covering large skin surface.',
      ],
      afterEffectsAndRecovery: 'Relieves allergy symptoms (sneezing, runny nose, itchy watery eyes) within 1 hour. Effects last for 24 hours.',
      storageInstructions: 'Store at 20°C to 25°C.',
      clinicalConsiderations: [
        'Faster onset of action compared to loratadine',
        'Adjust dose in moderate to severe renal impairment',
      ],
      foodRestrictions: ['Avoid alcohol to prevent increased sedative effects.'],
      standardInstructions: 'Take 1 tablet once daily with water.',
    )
,
    MedicineTemplate(
      name: 'Claritin',
      genericName: 'Loratadine',
      drugClass: 'Non-Sedating Second-Generation Antihistamine',
      activeIngredients: ['Loratadine 10 mg'],
      commonDosages: ['10 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.low,
      prescriptionRequirement: PrescriptionRequirement.otc,
      knownSideEffects: [SideEffectType.headache, SideEffectType.drowsiness],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['loratadine', 'desloratadine', 'antihistamine'],
      inactiveExcipients: ['corn starch', 'lactose monohydrate', 'magnesium stearate'],
      administrationCautions: [
        '⚠️ True non-drowsy formulation for virtually all adults.',
        '⚠️ Take once every 24 hours with a glass of water.',
        '❌ Do not exceed 10 mg in a 24-hour period.',
      ],
      emergencySigns: [
        'Fast heart rate, severe dizziness, jaundice.',
      ],
      afterEffectsAndRecovery: 'Allergy relief begins in 1-3 hours. Cleared from body smoothly over 24-28 hours.',
      storageInstructions: 'Store below 25°C in a dry place.',
      clinicalConsiderations: [
        'Preferred choice for daytime allergic rhinitis when driving or concentrating',
        'Substantially less sedative than diphenhydramine or cetirizine',
      ],
      foodRestrictions: ['Can be taken with or without food.'],
      standardInstructions: 'Take 1 tablet once daily with water.',
    )
,
    MedicineTemplate(
      name: 'Benadryl',
      genericName: 'Diphenhydramine Hydrochloride',
      drugClass: 'First-Generation Antihistamine / Sedative',
      activeIngredients: ['Diphenhydramine Hydrochloride 25 mg / 50 mg'],
      commonDosages: ['25 mg', '50 mg'],
      defaultForm: MedicationForm.capsule,
      dangerLevel: DangerLevel.moderate,
      prescriptionRequirement: PrescriptionRequirement.otc,
      knownSideEffects: [SideEffectType.drowsiness, SideEffectType.dryMouth, SideEffectType.dizziness],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['diphenhydramine', 'ethanolamine-antihistamine'],
      inactiveExcipients: ['gelatin', 'glycerin', 'polyethylene glycol', 'sorbitol'],
      administrationCautions: [
        '❌ SEVERE DROWSINESS WARNING: DO NOT drive, operate machinery, or ride bicycles after taking.',
        '❌ STRICTLY AVOID ALCOHOL: Alcohol dramatically increases sedation and respiratory slowing.',
        '⚠️ Anticholinergic cautions: avoid in elderly patients, glaucoma, or benign prostatic hyperplasia (causes urinary retention).',
      ],
      emergencySigns: [
        'Extreme confusion, delirium, urinary retention, blurred vision, rapid fluttering heartbeat.',
      ],
      afterEffectsAndRecovery: 'Causes marked sleepiness lasting 4 to 8 hours. "Morning hangover" effect common if taken late at night.',
      storageInstructions: 'Store below 25°C.',
      clinicalConsiderations: [
        'Potent first-line treatment for acute allergic reactions and urticaria',
        'Listed on Beers Criteria for medications to avoid in elderly patients',
      ],
      foodRestrictions: ['Strictly avoid alcohol and central nervous system sedatives.'],
      standardInstructions: 'Take 25 to 50 mg before bedtime or as directed for acute allergy.',
    )
,
    MedicineTemplate(
      name: 'Synthroid',
      genericName: 'Levothyroxine Sodium',
      drugClass: 'Synthetic Thyroid Hormone (T4)',
      activeIngredients: ['Levothyroxine Sodium 25 to 200 mcg'],
      commonDosages: ['25 mcg', '50 mcg', '75 mcg', '88 mcg', '100 mcg', '112 mcg', '125 mcg', '150 mcg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.high,
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [SideEffectType.dizziness, SideEffectType.headache, SideEffectType.custom],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['levothyroxine', 'thyroid-hormone'],
      inactiveExcipients: ['acacia', 'confectioner sugar', 'lactose monohydrate', 'magnesium stearate'],
      administrationCautions: [
        '⚠️ STRICT FASTING RULE: Take FIRST THING IN THE MORNING on an empty stomach with a full glass of plain water, at least 30 to 60 minutes before breakfast, coffee, or tea.',
        '❌ SEPARATE BY 4 HOURS from calcium, iron supplements, antacids, or soy products (severely impairs absorption).',
        '⚠️ Narrow therapeutic index: requires routine TSH blood tests every 6-12 months. Do not switch brands without doctor approval.',
      ],
      emergencySigns: [
        'Chest pain, rapid irregular pulse (atrial fibrillation), extreme nervousness, excessive sweating and heat intolerance.',
      ],
      afterEffectsAndRecovery: 'Very long elimination half-life (6-7 days). Full clinical effect requires 4 to 6 weeks of continuous daily dosing.',
      storageInstructions: 'Store at 20°C to 25°C protected from light and moisture.',
      clinicalConsiderations: [
        'Lifelong replacement therapy for hypothyroidism',
        'Monitor serum TSH 6 to 8 weeks after any dose adjustment',
      ],
      foodRestrictions: [
        'Must be taken on an empty stomach with plain water. Avoid coffee, dairy, and food for 60 minutes.',
      ],
      standardInstructions: 'Take on empty stomach upon waking with a full glass of water. Wait 60 min before breakfast.',
    )
,
    MedicineTemplate(
      name: 'Zoloft',
      genericName: 'Sertraline Hydrochloride',
      drugClass: 'SSRI (Selective Serotonin Reuptake Inhibitor)',
      activeIngredients: ['Sertraline Hydrochloride 25 mg / 50 mg / 100 mg'],
      commonDosages: ['25 mg', '50 mg', '100 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.moderate,
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [SideEffectType.nausea, SideEffectType.headache, SideEffectType.drowsiness],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['sertraline', 'ssri'],
      inactiveExcipients: ['calcium hydrogen phosphate anhydrous', 'hydroxypropyl cellulose', 'magnesium stearate'],
      administrationCautions: [
        '⚠️ DO NOT STOP ABRUPTLY: Sudden cessation causes withdrawal symptoms (electric-shock sensations, dizziness, flu-like symptoms). Taper slowly under medical supervision.',
        '⚠️ May take 2 to 4 weeks of daily use before noticeable mood improvement occurs.',
        '❌ CONTRAINDICATED with MAO inhibitors or within 14 days of discontinuing an MAOI (fatal Serotonin Syndrome risk).',
      ],
      emergencySigns: [
        'High fever, muscle rigidity, tremors, hallucinations, extreme agitation, seizures (Serotonin Syndrome).',
      ],
      afterEffectsAndRecovery: 'Initial nausea or mild insomnia usually resolves within the first 1-2 weeks of starting therapy.',
      storageInstructions: 'Store at 20°C to 25°C away from moisture.',
      clinicalConsiderations: [
        'First-line SSRI for Major Depressive Disorder, Panic Disorder, and OCD',
        'Lowest drug interaction liability among older SSRIs',
      ],
      foodRestrictions: ['Can be taken with or without food. Avoid alcohol.'],
      standardInstructions: 'Take once daily in the morning or evening consistently.',
    )
,
    MedicineTemplate(
      name: 'Lexapro',
      genericName: 'Escitalopram Oxalate',
      drugClass: 'SSRI Antidepressant / Anxiolytic',
      activeIngredients: ['Escitalopram Oxalate 5 mg / 10 mg / 20 mg'],
      commonDosages: ['5 mg', '10 mg', '20 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.moderate,
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [SideEffectType.nausea, SideEffectType.headache, SideEffectType.drowsiness],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['escitalopram', 'citalopram', 'ssri'],
      inactiveExcipients: ['microcrystalline cellulose', 'colloidal anhydrous silica', 'magnesium stearate'],
      administrationCautions: [
        '⚠️ Highly selective SSRI. Full therapeutic effect typically requires 3 to 4 weeks.',
        '❌ DO NOT discontinue abruptly; requires gradual tapering.',
        '⚠️ Maximum dose is 20 mg/day (10 mg/day in elderly) to avoid cardiac QT prolongation.',
      ],
      emergencySigns: [
        'Irregular heartbeat, severe dizziness, muscle twitches, intense restlessness.',
      ],
      afterEffectsAndRecovery: 'Mild initial stomach upset fades within 7-10 days. Take consistently once daily.',
      storageInstructions: 'Store below 25°C in a dry place.',
      clinicalConsiderations: [
        'Pure S-enantiomer with highest selectivity for serotonin transporter',
        'Fewer side effects and drug interactions than racemic citalopram',
      ],
      foodRestrictions: ['Can be taken with or without food. Avoid alcohol.'],
      standardInstructions: 'Take once daily morning or evening.',
    )
,
    MedicineTemplate(
      name: 'Xanax',
      genericName: 'Alprazolam',
      drugClass: 'Benzodiazepine (Anxiolytic / Sedative)',
      activeIngredients: ['Alprazolam 0.25 mg / 0.5 mg / 1.0 mg / 2.0 mg'],
      commonDosages: ['0.25 mg', '0.5 mg', '1 mg', '2 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.critical,
      prescriptionRequirement: PrescriptionRequirement.specialistControlled,
      knownSideEffects: [SideEffectType.drowsiness, SideEffectType.dizziness, SideEffectType.drowsiness],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['alprazolam', 'benzodiazepine'],
      inactiveExcipients: ['cellulose', 'corn starch', 'docusate sodium', 'lactose', 'magnesium stearate'],
      administrationCautions: [
        '❌ BLACK BOX WARNING: HIGH RISK OF DEPENDENCE, ADDICTION, AND LIFE-THREATENING WITHDRAWAL. Strictly for short-term use under direct specialist care.',
        '❌ FATAL WARNING: NEVER combine with opioids, alcohol, or other sedative drugs. Combination causes fatal respiratory arrest.',
        '❌ NEVER stop taking suddenly; abrupt cessation can cause status epilepticus (continuous seizures) and death.',
        '❌ DO NOT drive or operate dangerous equipment after taking.',
      ],
      emergencySigns: [
        'Extremely shallow or stopped breathing, blue lips, unresponsiveness, severe slurred speech, profound loss of coordination.',
      ],
      afterEffectsAndRecovery: 'Rapid calming effect within 20-40 minutes. Lingering sedation and slowed reaction times last 6 to 12 hours.',
      storageInstructions: 'Store locked in a secure cabinet below 25°C out of reach of anyone else.',
      clinicalConsiderations: [
        'High potency, rapid absorption, and short elimination half-life (high rebound anxiety potential)',
        'Limit prescription to 2-4 weeks maximum',
      ],
      foodRestrictions: [
        'ABSOLUTE CONTRAINDICATION: Alcohol. Avoid grapefruit juice.',
      ],
      standardInstructions: 'Take strictly as prescribed. Do not increase dose or stop suddenly.',
    )
,
    MedicineTemplate(
      name: 'Neurontin',
      genericName: 'Gabapentin',
      drugClass: 'GABA Analog / Neuropathic Pain Agent / Anticonvulsant',
      activeIngredients: ['Gabapentin 100 mg / 300 mg / 400 mg / 600 mg'],
      commonDosages: ['100 mg', '300 mg', '400 mg', '600 mg', '800 mg'],
      defaultForm: MedicationForm.capsule,
      dangerLevel: DangerLevel.moderate,
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [SideEffectType.drowsiness, SideEffectType.dizziness, SideEffectType.drowsiness],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['gabapentin', 'gabapentinoid'],
      inactiveExcipients: ['lactose monohydrate', 'corn starch', 'talc', 'gelatin'],
      administrationCautions: [
        '⚠️ Causes significant drowsiness, dizziness, and unsteadiness upon standing, especially in early weeks.',
        '❌ DO NOT stop abruptly; abrupt cessation in epilepsy triggers breakthrough seizures.',
        '⚠️ Separate by at least 2 hours from antacids (antacids reduce gabapentin bioavailability by ~20%).',
      ],
      emergencySigns: [
        'Extreme mood changes or suicidal thoughts, severe unsteadiness/falls, difficulty breathing when combined with sedatives.',
      ],
      afterEffectsAndRecovery: 'Effective for diabetic nerve pain and shingles neuralgia. Sedation typically attenuates over 2-3 weeks.',
      storageInstructions: 'Store at 20°C to 25°C.',
      clinicalConsiderations: [
        'Eliminated 100% renally: dose adjustment imperative in kidney impairment',
        'Commonly titrated upward in divided daily doses (e.g. 300 mg TID)',
      ],
      foodRestrictions: ['Can be taken with or without food. Separate from antacids by 2 hours.'],
      standardInstructions: 'Take with water. Avoid driving until you know how it affects you.',
    )
,
    MedicineTemplate(
      name: 'Coumadin',
      genericName: 'Warfarin Sodium',
      drugClass: 'Vitamin K Antagonist (Anticoagulant)',
      activeIngredients: ['Warfarin Sodium 1 mg / 2 mg / 2.5 mg / 5 mg'],
      commonDosages: ['1 mg', '2 mg', '2.5 mg', '5 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.critical,
      necessityLevel: NecessityLevel.critical,
      skipConsequences: 'CRITICAL DANGER: Skipping Warfarin leads to acute subtherapeutic INR, drastically heightening the risk of fatal pulmonary embolism, deep vein thrombosis (DVT), or stroke.',
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['warfarin', 'coumarin'],
      inactiveExcipients: ['lactose', 'starch', 'magnesium stearate'],
      administrationCautions: [
        '❌ BLACK BOX WARNING: HIGH RISK OF MAJOR OR FATAL BLEEDING. Regular blood monitoring (INR testing) is mandatory.',
        '⚠️ MAINTAIN CONSISTENT DIETARY VITAMIN K: Do not drastically increase or decrease intake of dark green leafy vegetables (spinach, kale, broccoli). Sudden changes alter your blood thinness.',
        '❌ STRICTLY AVOID ASPIRIN, NSAIDs (Ibuprofen, Naproxen), and alcohol unless explicitly cleared by your hematologist.',
        '⚠️ Take once daily at the exact same time (usually evening around 6 PM).',
      ],
      emergencySigns: [
        'Unusual bleeding from gums, non-stop nosebleeds (>15 min), blood in urine, black tarry stools, coughing up blood, sudden severe headache.',
      ],
      afterEffectsAndRecovery: 'Anticoagulant effects take 2-5 days to develop and 3-5 days to clear upon stopping. Reversible with Vitamin K1 (Phytonadione).',
      storageInstructions: 'Store at 20°C to 25°C protected from light.',
      clinicalConsiderations: [
        'Target INR typically 2.0 to 3.0 (2.5 to 3.5 for mechanical heart valves)',
        'Countless drug and herbal interactions (St. Johns Wort, cranberry, fluconazole, amiodarone)',
      ],
      foodRestrictions: [
        'Keep dietary intake of Vitamin K (green leafy vegetables) stable and consistent.',
        'Avoid cranberry juice and alcohol.',
      ],
      standardInstructions: 'Take at the exact same time every evening. Maintain consistent vegetable intake.',
    )
,
    MedicineTemplate(
      name: 'Ferrous Sulfate',
      genericName: 'Iron (Ferrous Sulfate)',
      drugClass: 'Essential Mineral / Hematinic',
      activeIngredients: ['Elemental Iron 65 mg (from 325 mg Ferrous Sulfate)'],
      commonDosages: ['325 mg (65 mg elemental iron)'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.low,
      prescriptionRequirement: PrescriptionRequirement.otc,
      knownSideEffects: [SideEffectType.stomachUpset, SideEffectType.nausea],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['iron', 'ferrous-sulfate'],
      inactiveExcipients: ['calcium carbonate', 'povidone', 'croscarmellose sodium'],
      administrationCautions: [
        '⚠️ Absorption is best on an empty stomach with a glass of orange juice (Vitamin C enhances iron absorption).',
        '⚠️ If stomach upset occurs, it may be taken with a small non-dairy meal.',
        '❌ DO NOT take with milk, tea, coffee, eggs, or calcium supplements (blocks iron absorption by up to 80%). Separate by at least 2 hours.',
        '⚠️ Harmless black stools are expected and normal during iron supplementation.',
        '❌ KEEP SECURELY OUT OF REACH OF CHILDREN: Accidental iron ingestion is a leading cause of fatal pediatric poisoning.',
      ],
      emergencySigns: [
        'Severe persistent abdominal pain, vomiting blood, extreme dehydration.',
      ],
      afterEffectsAndRecovery: 'Gradually restores red blood cells and ferritin reserves over 3 to 6 months of therapy.',
      storageInstructions: 'Store in child-resistant container below 25°C away from humidity.',
      clinicalConsiderations: [
        'First-line treatment for iron-deficiency anemia',
        'Constipation common; recommend high fiber and adequate hydration',
      ],
      foodRestrictions: [
        'Do not take within 2 hours of milk, cheese, yogurt, coffee, black tea, or eggs.',
      ],
      standardInstructions: 'Take on empty stomach with water or orange juice. Avoid dairy or tea within 2 hours.',
    )
,
    MedicineTemplate(
      name: 'Vitamin D3',
      genericName: 'Cholecalciferol',
      drugClass: 'Vitamin Supplement / Bone Metabolism',
      activeIngredients: ['Cholecalciferol (Vitamin D3) 1,000 IU / 5,000 IU / 50,000 IU'],
      commonDosages: ['1000 IU', '2000 IU', '5000 IU', '50000 IU'],
      defaultForm: MedicationForm.capsule,
      dangerLevel: DangerLevel.low,
      prescriptionRequirement: PrescriptionRequirement.otc,
      knownSideEffects: [],
      preConditions: [ConditionType.meal],
      allergenTriggers: ['vitamin-d', 'cholecalciferol'],
      inactiveExcipients: ['soybean oil', 'gelatin', 'glycerin'],
      administrationCautions: [
        '⚠️ TAKE WITH A MEAL CONTAINING HEALTHY FATS (olive oil, avocado, eggs, or dinner): Vitamin D is fat-soluble; taking with fat boosts absorption by over 50%.',
        '❌ High-dose formulations (50,000 IU) are taken once WEEKLY or once MONTHLY, NOT daily. Always verify your doctor prescription schedule.',
      ],
      emergencySigns: [
        'Confusion, extreme thirst, frequent urination, nausea, vomiting, muscle weakness (signs of Hypercalcemia from massive overdose).',
      ],
      afterEffectsAndRecovery: 'Replenishes systemic Vitamin D stores over weeks to months, optimizing bone density and immune defense.',
      storageInstructions: 'Store at 15°C to 25°C away from heat and direct sunlight.',
      clinicalConsiderations: [
        'Check 25-hydroxyvitamin D [25(OH)D] blood levels after 3 months of supplementation',
        'Superior bioavailability compared to Ergocalciferol (D2)',
      ],
      foodRestrictions: ['Best absorbed when taken with a meal containing dietary fats.'],
      standardInstructions: 'Take with a meal containing healthy fats for optimal absorption.',
    )
,
    MedicineTemplate(
      name: 'Vitamin B12',
      genericName: 'Methylcobalamin',
      drugClass: 'Essential Vitamin / Neurological Support',
      activeIngredients: ['Methylcobalamin 1000 mcg / 5000 mcg'],
      commonDosages: ['500 mcg', '1000 mcg', '5000 mcg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.low,
      prescriptionRequirement: PrescriptionRequirement.otc,
      knownSideEffects: [],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['vitamin-b12', 'cobalamin'],
      inactiveExcipients: ['mannitol', 'microcrystalline cellulose', 'stearic acid'],
      administrationCautions: [
        '⚠️ Water-soluble vitamin with extremely high safety margin. Excess is safely excreted in urine.',
        '⚠️ Sublingual tablets should be dissolved under the tongue for 30 seconds before swallowing.',
        '⚠️ Indispensable for strict vegans and long-term metformin or omeprazole users.',
      ],
      emergencySigns: [
        'None under standard dosages (extremely non-toxic). Report any unexpected allergic rash.',
      ],
      afterEffectsAndRecovery: 'Supports nerve myelin preservation and healthy red blood cell production.',
      storageInstructions: 'Store at 20°C to 25°C away from bright light.',
      clinicalConsiderations: [
        'Active coenzyme form of B12 with direct neurological bioavailability',
        'Recommended for diabetic patients on long-term Metformin',
      ],
      foodRestrictions: ['Can be taken with or without food.'],
      standardInstructions: 'Dissolve sublingual tablet under tongue or swallow with water once daily.',
    )
,
    MedicineTemplate(
      name: 'Calcium + D3',
      genericName: 'Calcium Carbonate + Cholecalciferol',
      drugClass: 'Mineral & Vitamin Supplement',
      activeIngredients: ['Calcium Carbonate 600 mg elemental', 'Vitamin D3 400 IU'],
      commonDosages: ['600 mg / 400 IU', '500 mg / 1000 IU'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.low,
      prescriptionRequirement: PrescriptionRequirement.otc,
      knownSideEffects: [SideEffectType.stomachUpset],
      preConditions: [ConditionType.meal, ConditionType.drinkWater],
      allergenTriggers: ['calcium', 'vitamin-d'],
      inactiveExcipients: ['croscarmellose sodium', 'magnesium stearate', 'titanium dioxide'],
      administrationCautions: [
        '⚠️ MUST BE TAKEN WITH FOOD: Calcium carbonate requires stomach acid for proper dissolution and absorption.',
        '❌ Separate by at least 2 hours from thyroid medication (Synthroid), antibiotics (Cipro, Doxycycline), or Iron supplements.',
        '⚠️ Maximum single absorbable dose is 500-600 mg elemental calcium; divide doses if taking twice daily.',
      ],
      emergencySigns: [
        'Kidney stones (severe flank pain, blood in urine), constipation accompanied by severe abdominal distension.',
      ],
      afterEffectsAndRecovery: 'Strengthens bone mineral density. Mild constipation can be managed with hydration.',
      storageInstructions: 'Store below 25°C in a dry place.',
      clinicalConsiderations: [
        'First-line prophylaxis and therapy for osteoporosis and osteopenia',
        'Calcium citrate is preferred for elderly patients on acid-reducing PPI medications',
      ],
      foodRestrictions: [
        'Always take with food. Separate from iron and antibiotic doses by 2 hours.',
      ],
      standardInstructions: 'Take with food and a full glass of water. Separate from other mineral supplements.',
    )
,
    MedicineTemplate(
      name: 'Cozaar',
      genericName: 'Losartan Potassium',
      drugClass: 'Angiotensin II Receptor Blocker (ARB)',
      activeIngredients: ['Losartan Potassium 25 mg / 50 mg / 100 mg'],
      commonDosages: ['25 mg', '50 mg', '100 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.moderate,
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [SideEffectType.dizziness, SideEffectType.drowsiness],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['losartan', 'arb'],
      inactiveExcipients: ['microcrystalline cellulose', 'lactose hydrous', 'magnesium stearate'],
      administrationCautions: [
        '❌ BLACK BOX WARNING: CONTRAINDICATED IN PREGNANCY (causes fetal injury and death).',
        '⚠️ Does not cause the dry cough associated with ACE inhibitors.',
        '⚠️ Avoid potassium supplements without medical authorization (can cause hyperkalemia).',
      ],
      emergencySigns: [
        'Facial swelling, severe dizzy spells when standing, acute kidney failure signs (oliguria).',
      ],
      afterEffectsAndRecovery: 'Smooth 24-hour blood pressure reduction and kidney protection in diabetic patients.',
      storageInstructions: 'Store at 20°C to 25°C protected from light.',
      clinicalConsiderations: [
        'Uricosuric effect: uniquely lowers serum uric acid (beneficial in hypertensive patients with gout)',
        'Monitor renal function and electrolytes periodically',
      ],
      foodRestrictions: ['Can be taken with or without food. Avoid potassium salt substitutes.'],
      standardInstructions: 'Take once daily at the same time with water.',
    )
,
    MedicineTemplate(
      name: 'Toprol XL',
      genericName: 'Metoprolol Succinate',
      drugClass: 'Beta-1 Selective Adrenergic Blocker',
      activeIngredients: ['Metoprolol Succinate 25 mg / 50 mg / 100 mg / 200 mg'],
      commonDosages: ['25 mg', '50 mg', '100 mg', '200 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.high,
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [SideEffectType.drowsiness, SideEffectType.dizziness, SideEffectType.drowsiness],
      preConditions: [ConditionType.meal, ConditionType.drinkWater],
      allergenTriggers: ['metoprolol', 'beta-blocker'],
      inactiveExcipients: ['silicon dioxide', 'cellulose', 'polyethylene glycol', 'titanium dioxide'],
      administrationCautions: [
        '❌ NEVER CRUSH OR CHEW EXTENDED-RELEASE TABLETS. Tablets may be split along the scored line if prescribed, but halves must be swallowed whole without crushing.',
        '❌ NEVER STOP TAKING SUDDENLY: Abrupt cessation can cause rebound severe hypertension, chest pain (angina), or heart attack.',
        '⚠️ Monitor resting pulse rate. If resting pulse drops below 50 beats per minute, contact your doctor.',
      ],
      emergencySigns: [
        'Extreme bradycardia (<50 bpm), severe shortness of breath, cold pale extremities, fainting.',
      ],
      afterEffectsAndRecovery: 'Lowers heart rate and blood pressure, reducing cardiac workload and stabilizing arrhythmias.',
      storageInstructions: 'Store below 30°C in a tightly closed bottle.',
      clinicalConsiderations: [
        'Mortality-proven benefit in chronic heart failure (NYHA Class II-IV)',
        'May mask warning symptoms of hypoglycemia (tachycardia, tremors) in diabetic patients',
      ],
      foodRestrictions: ['Best taken with or immediately following a meal.'],
      standardInstructions: 'Take once daily with or right after a meal. Swallow whole or halved along score.',
    )
,
    MedicineTemplate(
      name: 'Jardiance',
      genericName: 'Empagliflozin',
      drugClass: 'SGLT2 Inhibitor (Antidiabetic / Cardiorenal Agent)',
      activeIngredients: ['Empagliflozin 10 mg / 25 mg'],
      commonDosages: ['10 mg', '25 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.moderate,
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [SideEffectType.nausea],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['empagliflozin', 'sglt2-inhibitor'],
      inactiveExcipients: ['lactose monohydrate', 'microcrystalline cellulose', 'hydroxypropyl cellulose'],
      administrationCautions: [
        '⚠️ Drink plenty of water throughout the day to avoid dehydration and hypotension.',
        '⚠️ Maintain good genital hygiene: SGLT2 inhibitors excrete excess glucose in the urine, increasing the risk of genital fungal infections (thrush) and urinary tract infections.',
        '❌ Withhold during periods of severe illness, fasting, or major surgery to avoid Euglycemic Diabetic Ketoacidosis (DKA).',
      ],
      emergencySigns: [
        'Severe abdominal pain, nausea/vomiting, difficulty breathing, sweet fruity breath odor (DKA), perineal tenderness/swelling (Fournier gangrene).',
      ],
      afterEffectsAndRecovery: 'Provides glucose control, modest weight loss, and strong cardiorenal protection.',
      storageInstructions: 'Store at 20°C to 25°C.',
      clinicalConsiderations: [
        'Significant reduction in cardiovascular death and heart failure hospitalizations',
        'Delays progression of chronic kidney disease',
      ],
      foodRestrictions: ['Can be taken with or without food. Stay well hydrated.'],
      standardInstructions: 'Take once daily in the morning with a glass of water.',
    )
,
    MedicineTemplate(
      name: 'Zofran',
      genericName: 'Ondansetron Hydrochloride',
      drugClass: '5-HT3 Receptor Antagonist (Antiemetic)',
      activeIngredients: ['Ondansetron Hydrochloride 4 mg / 8 mg'],
      commonDosages: ['4 mg', '8 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.moderate,
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [SideEffectType.headache, SideEffectType.drowsiness],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['ondansetron', 'setron-antiemetic'],
      inactiveExcipients: ['lactose', 'microcrystalline cellulose', 'pregelatinized starch'],
      administrationCautions: [
        '⚠️ For Orally Disintegrating Tablets (ODT): Place on tongue with dry hands, allow to dissolve within seconds, then swallow with saliva. Do not chew.',
        '⚠️ Take 30 minutes before chemotherapy, radiation, or surgery as directed.',
        '⚠️ May cause mild transient headache or constipation.',
      ],
      emergencySigns: [
        'Palpitations, chest pain, fainting (QT prolongation), severe constipation with bowel blockage.',
      ],
      afterEffectsAndRecovery: 'Very fast-acting nausea suppression (within 30 minutes). Lasts 4-8 hours.',
      storageInstructions: 'Store below 30°C protected from light.',
      clinicalConsiderations: [
        'Gold standard antiemetic for post-operative and chemotherapy-induced nausea',
        'Does not cause sedation or extrapyramidal symptoms common in dopamine antagonists',
      ],
      foodRestrictions: ['Can be taken with or without food.'],
      standardInstructions: 'Take 30 minutes before nausea-inducing trigger. Dissolve ODT on tongue.',
    )
,
    MedicineTemplate(
      name: 'Diflucan',
      genericName: 'Fluconazole',
      drugClass: 'Triazole Antifungal',
      activeIngredients: ['Fluconazole 150 mg'],
      commonDosages: ['50 mg', '100 mg', '150 mg', '200 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.moderate,
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [SideEffectType.headache, SideEffectType.nausea],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['fluconazole', 'azole-antifungal'],
      inactiveExcipients: ['microcrystalline cellulose', 'dibasic calcium phosphate', 'povidone'],
      administrationCautions: [
        '⚠️ For vaginal candidiasis (yeast infection), a single 150 mg oral dose is often curative.',
        '❌ CONTRAINDICATED in pregnancy (risk of spontaneous abortion and congenital anomalies).',
        '⚠️ Strong CYP2C9/CYP3A4 inhibitor: check for major interactions with Warfarin, Statins, and oral hypoglycemic drugs.',
      ],
      emergencySigns: [
        'Severe skin peeling or rash (Stevens-Johnson syndrome), jaundice, dark urine, persistent vomiting.',
      ],
      afterEffectsAndRecovery: 'High oral bioavailability. Eliminates fungal infection within 24-72 hours.',
      storageInstructions: 'Store below 30°C in a dry place.',
      clinicalConsiderations: [
        'Single dose regimen convenient for uncomplicated fungal infections',
        'Monitor liver enzymes if taken chronically (>14 days)',
      ],
      foodRestrictions: ['Can be taken with or without food with a full glass of water.'],
      standardInstructions: 'Take with a full glass of water with or without food as prescribed.',
    )
,
    MedicineTemplate(
      name: 'Singulair',
      genericName: 'Montelukast Sodium',
      drugClass: 'Leukotriene Receptor Antagonist (LTRA)',
      activeIngredients: ['Montelukast Sodium 10 mg'],
      commonDosages: ['4 mg', '5 mg', '10 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.moderate,
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [SideEffectType.headache],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['montelukast', 'leukotriene-antagonist'],
      inactiveExcipients: ['microcrystalline cellulose', 'lactose monohydrate', 'croscarmellose sodium'],
      administrationCautions: [
        '⚠️ TAKE ONCE DAILY IN THE EVENING: Most asthma symptoms and allergic cascades peak overnight and early morning.',
        '❌ NOT FOR ACUTE ATTACKS: This is a maintenance medication; keep your rescue inhaler (Albuterol) available for acute bronchospasm.',
        '❌ BLACK BOX WARNING: Monitor for neuro-psychiatric changes (abnormal dreams, sleep walking, depression, aggressive behavior). Report immediately.',
      ],
      emergencySigns: [
        'Severe mood swings, suicidal thoughts, widespread rash with numbness and fever (Churg-Strauss syndrome).',
      ],
      afterEffectsAndRecovery: 'Provides continuous baseline protection against allergen and exercise-induced asthma.',
      storageInstructions: 'Store at 20°C to 25°C protected from moisture and light.',
      clinicalConsiderations: [
        'Especially effective for aspirin-induced asthma and combined allergic rhinitis + asthma',
        'Well-tolerated daily oral tablet',
      ],
      foodRestrictions: ['Can be taken with or without food. Take in the evening.'],
      standardInstructions: 'Take 1 tablet once daily in the evening with water.',
    ),
    MedicineTemplate(
      name: 'Lantus',
      genericName: 'Insulin Glargine',
      drugClass: 'Long-Acting Basal Insulin',
      activeIngredients: ['Insulin Glargine 100 units/mL'],
      commonDosages: ['10 units', '15 units', '20 units', '30 units'],
      defaultForm: MedicationForm.injection,
      dangerLevel: DangerLevel.critical,
      necessityLevel: NecessityLevel.critical,
      skipConsequences: 'CRITICAL DANGER: Skipping basal insulin triggers acute Diabetic Ketoacidosis (DKA), severe hyperglycemia, and rapid metabolic destabilization.',
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [SideEffectType.dizziness],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['insulin', 'insulin-glargine'],
      inactiveExcipients: ['glycerol', 'm-cresol', 'zinc chloride', 'hydrochloric acid'],
      administrationCautions: [
        '❌ NEVER skip or double-up doses. Basal insulin maintains vital glucose regulation 24/7.',
        '⚠️ Rotate injection sites (abdomen, thighs, upper arms) to prevent lipodystrophy.',
        '❌ NEVER freeze or expose open pens/vials to direct sunlight or temperatures above 30°C.',
      ],
      emergencySigns: [
        'Fruity breath odor, severe nausea, confusion, deep rapid breathing (Kussmaul breathing), blood glucose > 250 mg/dL.',
      ],
      afterEffectsAndRecovery: 'Smooth peakless baseline glucose reduction over 24 hours.',
      storageInstructions: 'Unopened: refrigerate 2°C-8°C. In-use: store room temperature below 30°C for up to 28 days.',
      foodRestrictions: ['Maintain consistent meal schedules. Always monitor blood glucose before injecting.'],
      standardInstructions: 'Inject subcutaneously once daily at the exact same hour.',
    ),
    MedicineTemplate(
      name: 'Keppra',
      genericName: 'Levetiracetam',
      drugClass: 'Anticonvulsant / Antiepileptic',
      activeIngredients: ['Levetiracetam 250 mg / 500 mg / 750 mg / 1000 mg'],
      commonDosages: ['250 mg', '500 mg', '750 mg', '1000 mg'],
      defaultForm: MedicationForm.pill,
      dangerLevel: DangerLevel.critical,
      necessityLevel: NecessityLevel.critical,
      skipConsequences: 'CRITICAL DANGER: Missing antiepileptic doses precipitates sudden breakthrough seizures, status epilepticus, and traumatic injury.',
      prescriptionRequirement: PrescriptionRequirement.prescription,
      knownSideEffects: [SideEffectType.drowsiness, SideEffectType.dizziness],
      preConditions: [ConditionType.drinkWater],
      allergenTriggers: ['levetiracetam', 'pyrrolidone'],
      inactiveExcipients: ['corn starch', 'povidone', 'talc', 'magnesium stearate'],
      administrationCautions: [
        '❌ STRICT ADHERENCE: Doses must be taken exactly 12 hours apart (BID) to maintain anticonvulsant threshold.',
        '❌ NEVER abruptly discontinue; sudden withdrawal can trigger refractory seizures.',
      ],
      emergencySigns: [
        'Sudden seizure activity, severe behavioral agitation, extreme depression or suicidal thoughts.',
      ],
      afterEffectsAndRecovery: 'Rapidly absorbed, stabilizes neuronal excitability throughout 12-hour window.',
      storageInstructions: 'Store at 15°C to 30°C.',
      foodRestrictions: ['Can be taken with or without food. Avoid alcohol.'],
      standardInstructions: 'Take every 12 hours with a full glass of water.',
    ),
    MedicineTemplate(
      name: 'Prograf',
      genericName: 'Tacrolimus',
      drugClass: 'Calcineurin Inhibitor (Immunosuppressant)',
      activeIngredients: ['Tacrolimus 0.5 mg / 1 mg / 5 mg'],
      commonDosages: ['0.5 mg', '1 mg', '2 mg', '5 mg'],
      defaultForm: MedicationForm.capsule,
      dangerLevel: DangerLevel.critical,
      necessityLevel: NecessityLevel.critical,
      skipConsequences: 'CRITICAL DANGER: Missing immunosuppressant doses destroys graft tolerance and precipitates acute organ transplant rejection.',
      prescriptionRequirement: PrescriptionRequirement.specialistControlled,
      knownSideEffects: [SideEffectType.headache, SideEffectType.nausea],
      preConditions: [ConditionType.emptyStomach],
      allergenTriggers: ['tacrolimus', 'macrolide'],
      inactiveExcipients: ['lactose monohydrate', 'hypromellose', 'croscarmellose sodium', 'magnesium stearate'],
      administrationCautions: [
        '❌ STRICT 12-HOUR SPACING: Take consistently on an empty stomach (1 hour before or 2 hours after meals).',
        '❌ ABSOLUTELY AVOID GRAPEFRUIT and St. John\'s Wort; they unpredictably alter blood concentrations to toxic or subtherapeutic levels.',
      ],
      emergencySigns: [
        'Decreased urination, fever, graft tenderness, sudden elevated blood pressure, severe tremor.',
      ],
      afterEffectsAndRecovery: 'Requires precise blood trough monitoring (5-15 ng/mL target).',
      storageInstructions: 'Store at 20°C to 25°C protected from moisture.',
      foodRestrictions: ['STRICT: No grapefruit or grapefruit juice. Take consistently either always with food or always empty stomach.'],
      standardInstructions: 'Take exactly every 12 hours on an empty stomach.',
    ),
  ];

  /// Infers clinical necessity level from drug name, drug class, or matched database profile.
  static NecessityLevel inferNecessityLevel(
    String name, {
    String? category,
    DangerLevel? dangerLevel,
  }) {
    final clean = name.trim().toLowerCase();

    // 1. Life-Critical triggers (Anticoagulants, Insulins, Anticonvulsants, Immunosuppressants, Cardiac Glycosides/Antiarrhythmics)
    if (clean.contains('insulin') ||
        clean.contains('lantus') ||
        clean.contains('novolog') ||
        clean.contains('humalog') ||
        clean.contains('levemir') ||
        clean.contains('tresiba') ||
        clean.contains('toujeo') ||
        clean.contains('basaglar') ||
        clean.contains('apidra') ||
        clean.contains('glargine') ||
        clean.contains('lispro') ||
        clean.contains('aspart') ||
        clean.contains('warfarin') ||
        clean.contains('coumadin') ||
        clean.contains('eliquis') ||
        clean.contains('apixaban') ||
        clean.contains('xarelto') ||
        clean.contains('rivaroxaban') ||
        clean.contains('pradaxa') ||
        clean.contains('dabigatran') ||
        clean.contains('plavix') ||
        clean.contains('clopidogrel') ||
        clean.contains('brilinta') ||
        clean.contains('ticagrelor') ||
        clean.contains('heparin') ||
        clean.contains('lovenox') ||
        clean.contains('enoxaparin') ||
        clean.contains('keppra') ||
        clean.contains('levetiracetam') ||
        clean.contains('carbamazepine') ||
        clean.contains('tegretol') ||
        clean.contains('phenytoin') ||
        clean.contains('dilantin') ||
        clean.contains('valproat') ||
        clean.contains('depakote') ||
        clean.contains('depakene') ||
        clean.contains('lamotrigine') ||
        clean.contains('lamictal') ||
        clean.contains('oxcarbazepine') ||
        clean.contains('trileptal') ||
        clean.contains('lacosamide') ||
        clean.contains('vimpat') ||
        clean.contains('topiramate') ||
        clean.contains('topamax') ||
        clean.contains('prograf') ||
        clean.contains('tacrolimus') ||
        clean.contains('cyclosporine') ||
        clean.contains('neoral') ||
        clean.contains('sandimmune') ||
        clean.contains('mycophenolate') ||
        clean.contains('cellcept') ||
        clean.contains('sirolimus') ||
        clean.contains('rapamune') ||
        clean.contains('digoxin') ||
        clean.contains('lanoxin') ||
        clean.contains('amiodarone') ||
        clean.contains('cordarone') ||
        clean.contains('flecainide') ||
        clean.contains('sotalol')) {
      return NecessityLevel.critical;
    }

    // 2. Vital triggers (Antihypertensives, Antibiotics, Thyroid, Diabetes Non-Insulin, Steroids, Respiratory, Psychiatric, Statins, Glaucoma)
    if (clean.contains('metoprolol') ||
        clean.contains('toprol') ||
        clean.contains('atenolol') ||
        clean.contains('carvedilol') ||
        clean.contains('bisoprolol') ||
        clean.contains('propranolol') ||
        clean.contains('labetalol') ||
        clean.contains('amlodipine') ||
        clean.contains('norvasc') ||
        clean.contains('nifedipine') ||
        clean.contains('diltiazem') ||
        clean.contains('cardizem') ||
        clean.contains('verapamil') ||
        clean.contains('lisinopril') ||
        clean.contains('zestril') ||
        clean.contains('prinivil') ||
        clean.contains('enalapril') ||
        clean.contains('ramipril') ||
        clean.contains('losartan') ||
        clean.contains('cozaar') ||
        clean.contains('valsartan') ||
        clean.contains('diovan') ||
        clean.contains('candesartan') ||
        clean.contains('olmesartan') ||
        clean.contains('telmisartan') ||
        clean.contains('hydrochlorothiazide') ||
        clean.contains('hctz') ||
        clean.contains('furosemide') ||
        clean.contains('lasix') ||
        clean.contains('spironolactone') ||
        clean.contains('amoxicillin') ||
        clean.contains('amoxil') ||
        clean.contains('augmentin') ||
        clean.contains('penicillin') ||
        clean.contains('cephalexin') ||
        clean.contains('keflex') ||
        clean.contains('cefdinir') ||
        clean.contains('cipro') ||
        clean.contains('levofloxacin') ||
        clean.contains('azithromycin') ||
        clean.contains('zithromax') ||
        clean.contains('doxycycline') ||
        clean.contains('flagyl') ||
        clean.contains('metronidazole') ||
        clean.contains('bactrim') ||
        clean.contains('clindamycin') ||
        clean.contains('nitrofurantoin') ||
        clean.contains('macrobid') ||
        clean.contains('acyclovir') ||
        clean.contains('valacyclovir') ||
        clean.contains('synthroid') ||
        clean.contains('levothyroxine') ||
        clean.contains('liothyronine') ||
        clean.contains('methimazole') ||
        clean.contains('metformin') ||
        clean.contains('glucophage') ||
        clean.contains('glipizide') ||
        clean.contains('glimepiride') ||
        clean.contains('januvia') ||
        clean.contains('sitagliptin') ||
        clean.contains('jardiance') ||
        clean.contains('farxiga') ||
        clean.contains('ozempic') ||
        clean.contains('semaglutide') ||
        clean.contains('mounjaro') ||
        clean.contains('tirzepatide') ||
        clean.contains('trulicity') ||
        clean.contains('prednisone') ||
        clean.contains('prednisolone') ||
        clean.contains('dexamethasone') ||
        clean.contains('methylprednisolone') ||
        clean.contains('medrol') ||
        clean.contains('albuterol') ||
        clean.contains('ventolin') ||
        clean.contains('proair') ||
        clean.contains('symbicort') ||
        clean.contains('advair') ||
        clean.contains('fluticasone') ||
        clean.contains('spiriva') ||
        clean.contains('tiotropium') ||
        clean.contains('montelukast') ||
        clean.contains('singulair') ||
        clean.contains('sertraline') ||
        clean.contains('zoloft') ||
        clean.contains('escitalopram') ||
        clean.contains('lexapro') ||
        clean.contains('citalopram') ||
        clean.contains('fluoxetine') ||
        clean.contains('prozac') ||
        clean.contains('paroxetine') ||
        clean.contains('venlafaxine') ||
        clean.contains('duloxetine') ||
        clean.contains('cymbalta') ||
        clean.contains('bupropion') ||
        clean.contains('wellbutrin') ||
        clean.contains('xanax') ||
        clean.contains('alprazolam') ||
        clean.contains('clonazepam') ||
        clean.contains('klonopin') ||
        clean.contains('lorazepam') ||
        clean.contains('ativan') ||
        clean.contains('diazepam') ||
        clean.contains('valium') ||
        clean.contains('quetiapine') ||
        clean.contains('olanzapine') ||
        clean.contains('risperidone') ||
        clean.contains('aripiprazole') ||
        clean.contains('lithium') ||
        clean.contains('atorvastatin') ||
        clean.contains('lipitor') ||
        clean.contains('rosuvastatin') ||
        clean.contains('crestor') ||
        clean.contains('simvastatin') ||
        clean.contains('latanoprost') ||
        clean.contains('timolol')) {
      return NecessityLevel.vital;
    }

    // 3. Low triggers (Vitamins, Supplements, Minerals, OTC Symptomatics)
    if (clean.contains('vitamin') ||
        clean.contains('multivitamin') ||
        clean.contains('mineral') ||
        clean.contains('calcium') ||
        clean.contains('iron') ||
        clean.contains('ferrous') ||
        clean.contains('zinc') ||
        clean.contains('magnesium') ||
        clean.contains('b12') ||
        clean.contains('folic') ||
        clean.contains('fish oil') ||
        clean.contains('omega') ||
        clean.contains('melatonin') ||
        clean.contains('biotin') ||
        clean.contains('probiotic') ||
        clean.contains('acetaminophen') ||
        clean.contains('tylenol') ||
        clean.contains('paracetamol')) {
      return NecessityLevel.low;
    }

    if (dangerLevel == DangerLevel.critical) return NecessityLevel.critical;
    if (dangerLevel == DangerLevel.high) return NecessityLevel.vital;
    if (dangerLevel == DangerLevel.moderate) return NecessityLevel.moderate;
    return NecessityLevel.moderate; // Standard default for prescription drugs
  }

  /// Plain-language clinical description of the danger and consequences of skipping a dose.
  static String defaultSkipConsequences(String name, NecessityLevel level) {
    final clean = name.trim().toLowerCase();

    if (clean.contains('insulin') ||
        clean.contains('lantus') ||
        clean.contains('novolog') ||
        clean.contains('humalog')) {
      return 'DANGER: Skipping insulin can rapidly trigger life-threatening Diabetic Ketoacidosis (DKA), severe hyperglycemia, and metabolic emergency.';
    }
    if (clean.contains('warfarin') ||
        clean.contains('coumadin') ||
        clean.contains('eliquis') ||
        clean.contains('xarelto')) {
      return 'CRITICAL DANGER: Skipping anticoagulants causes rapid loss of clot prevention, dramatically elevating the risk of fatal stroke, pulmonary embolism, or deep vein thrombosis (DVT).';
    }
    if (clean.contains('keppra') ||
        clean.contains('levetiracetam') ||
        clean.contains('antiepileptic') ||
        clean.contains('carbamazepine')) {
      return 'CRITICAL DANGER: Abruptly skipping antiepileptic doses can precipitate sudden breakthrough seizures, status epilepticus, or head trauma.';
    }
    if (clean.contains('prograf') ||
        clean.contains('tacrolimus') ||
        clean.contains('cyclosporine')) {
      return 'CRITICAL DANGER: Missing an immunosuppressant dose jeopardizes graft survival and can trigger acute organ transplant rejection.';
    }
    if (clean.contains('amoxil') ||
        clean.contains('amoxicillin') ||
        clean.contains('augmentin') ||
        clean.contains('cipro') ||
        clean.contains('flagyl') ||
        clean.contains('zithromax')) {
      return 'Skipping doses causes antibiotic blood levels to plunge below therapeutic strength, resulting in infection recurrence and dangerous bacterial drug resistance.';
    }
    if (clean.contains('metoprolol') ||
        clean.contains('toprol') ||
        clean.contains('atenolol') ||
        clean.contains('norvasc') ||
        clean.contains('amlodipine') ||
        clean.contains('lisinopril') ||
        clean.contains('zestril') ||
        clean.contains('losartan') ||
        clean.contains('cozaar')) {
      return 'Missing doses can trigger dangerous blood pressure spikes, acute rebound tachycardia, and excessive cardiovascular strain.';
    }
    if (clean.contains('synthroid') || clean.contains('levothyroxine')) {
      return 'Skipping disrupts endocrine hormone stability, causing persistent fatigue, brain fog, cold intolerance, and metabolic disturbance.';
    }
    if (clean.contains('glucophage') ||
        clean.contains('metformin') ||
        clean.contains('jardiance')) {
      return 'Skipping causes blood glucose spikes, osmotic diuresis, and long-term glycemic instability.';
    }
    if (clean.contains('ventolin') || clean.contains('albuterol')) {
      return 'Failure to take during bronchospasm leads to progressive hypoxemia, acute airway constriction, and severe respiratory distress.';
    }
    if (clean.contains('zoloft') ||
        clean.contains('lexapro') ||
        clean.contains('xanax') ||
        clean.contains('sertraline')) {
      return 'Skipping doses can precipitate acute withdrawal symptoms (dizziness, brain zaps, severe rebound panic, and restlessness).';
    }

    switch (level) {
      case NecessityLevel.critical:
        return 'CRITICAL DANGER: Missing or skipping this dose causes acute, life-threatening complications. Take immediately or consult urgent care.';
      case NecessityLevel.vital:
        return 'Essential daily medication: missing this dose compromises therapeutic control, raises disease recurrence risk, or causes rebound symptoms.';
      case NecessityLevel.moderate:
        return 'Missing doses delays optimal therapeutic maintenance; adhere to regular schedule.';
      case NecessityLevel.low:
        return 'Symptomatic medication; can be safely skipped if symptoms have resolved.';
    }
  }

  static List<MedicineTemplate> search(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return [];
    return repository.where((t) {
      return t.name.toLowerCase().contains(clean) ||
          t.genericName.toLowerCase().contains(clean) ||
          t.drugClass.toLowerCase().contains(clean);
    }).toList();
  }

  static MedicineTemplate? findTemplate(String name) => findByName(name);

  static MedicineTemplate? findByName(String name) {
    final clean = name.trim().toLowerCase();
    if (clean.isEmpty) return null;

    // 1. Exact match against name or genericName
    for (final template in repository) {
      if (template.name.toLowerCase() == clean ||
          template.genericName.toLowerCase() == clean) {
        return template;
      }
    }

    // 2. Bidirectional contains match across name, generic name, and active ingredients
    for (final template in repository) {
      final tName = template.name.toLowerCase();
      final tGeneric = template.genericName.toLowerCase();
      if (clean.contains(tName) ||
          tName.contains(clean) ||
          clean.contains(tGeneric) ||
          tGeneric.contains(clean) ||
          template.activeIngredients.any((ing) => ing.toLowerCase().contains(clean))) {
        return template;
      }
    }
    return null;
  }
}

