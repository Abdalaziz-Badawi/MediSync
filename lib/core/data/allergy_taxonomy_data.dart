import 'package:flutter/material.dart';
import 'package:medisync/core/theme/app_theme.dart';

enum AllergyCategoryType {
  all('All Categories', Icons.grid_view_rounded),
  directDrug('Direct Drugs & Classes', Icons.medication_rounded),
  foodExcipient('Food & Excipients', Icons.restaurant_rounded),
  inactiveAdditive('Additives & Preservatives', Icons.science_rounded),
  environmentalMaterial('Environmental & Materials', Icons.eco_rounded);

  final String label;
  final IconData icon;
  const AllergyCategoryType(this.label, this.icon);
}

class TaxonomyAllergen {
  final String name;
  final AllergyCategoryType category;
  final String subcategory;
  final String clinicalNote;

  const TaxonomyAllergen({
    required this.name,
    required this.category,
    required this.subcategory,
    required this.clinicalNote,
  });
}

class AllergyTaxonomyData {
  static const List<TaxonomyAllergen> allAllergens = [
    // 1. Direct Drugs & Classes
    TaxonomyAllergen(
      name: 'Penicillin',
      category: AllergyCategoryType.directDrug,
      subcategory: 'Beta-Lactam Antibiotic',
      clinicalNote: 'High risk of cross-reactivity with Aminopenicillins & Cephalosporins',
    ),
    TaxonomyAllergen(
      name: 'Amoxicillin',
      category: AllergyCategoryType.directDrug,
      subcategory: 'Aminopenicillin',
      clinicalNote: 'Cross-reactive with Ampicillin and early cephalosporins',
    ),
    TaxonomyAllergen(
      name: 'Cephalosporins',
      category: AllergyCategoryType.directDrug,
      subcategory: 'Beta-Lactam Antibiotic',
      clinicalNote: 'Check R1 side-chain similarity with penicillin history',
    ),
    TaxonomyAllergen(
      name: 'Sulfa (Sulfonamides)',
      category: AllergyCategoryType.directDrug,
      subcategory: 'Antibacterial Sulfonamide',
      clinicalNote: 'Arylamine sulfonamides (e.g. Bactrim / Septra)',
    ),
    TaxonomyAllergen(
      name: 'Aspirin',
      category: AllergyCategoryType.directDrug,
      subcategory: 'Salicylate / NSAID',
      clinicalNote: 'COX-1 inhibition trigger for AERD and respiratory reactions',
    ),
    TaxonomyAllergen(
      name: 'Ibuprofen / NSAIDs',
      category: AllergyCategoryType.directDrug,
      subcategory: 'Nonsteroidal Anti-inflammatory',
      clinicalNote: 'Includes Naproxen, Diclofenac, Ketorolac, Meloxicam',
    ),
    TaxonomyAllergen(
      name: 'Paracetamol (Acetaminophen)',
      category: AllergyCategoryType.directDrug,
      subcategory: 'Analgesic / Antipyretic',
      clinicalNote: 'Rare hypersensitivity; safe alternative in mild NSAID intolerance',
    ),
    TaxonomyAllergen(
      name: 'Codeine / Opioids',
      category: AllergyCategoryType.directDrug,
      subcategory: 'Opioid Analgesic',
      clinicalNote: 'Distinguish pseudo-allergy (histamine release) from true IgE',
    ),
    TaxonomyAllergen(
      name: 'Macrolides (Azithromycin/Erythromycin)',
      category: AllergyCategoryType.directDrug,
      subcategory: 'Antibiotic',
      clinicalNote: 'GI motilin stimulation vs cutaneous drug eruption',
    ),
    TaxonomyAllergen(
      name: 'Fluoroquinolones (Ciprofloxacin)',
      category: AllergyCategoryType.directDrug,
      subcategory: 'Antibiotic',
      clinicalNote: 'MRGPRX2 receptor direct mast cell activation risk',
    ),
    TaxonomyAllergen(
      name: 'ACE Inhibitors (Lisinopril/Enalapril)',
      category: AllergyCategoryType.directDrug,
      subcategory: 'Cardiovascular',
      clinicalNote: 'Bradykinin-mediated angioedema risk',
    ),
    TaxonomyAllergen(
      name: 'Statins (Atorvastatin/Simvastatin)',
      category: AllergyCategoryType.directDrug,
      subcategory: 'Lipid-Lowering Agent',
      clinicalNote: 'Statin-associated myopathy and hypersensitivity',
    ),
    TaxonomyAllergen(
      name: 'Iodinated Contrast Media',
      category: AllergyCategoryType.directDrug,
      subcategory: 'Radiopaque Diagnostic',
      clinicalNote: 'Non-IgE anaphylactoid osmolar and chemotoxic reactions',
    ),

    // 2. Food Allergies & Pharmaceutical Excipients
    TaxonomyAllergen(
      name: 'Lactose Monohydrate (Dairy)',
      category: AllergyCategoryType.foodExcipient,
      subcategory: 'Tablet & Capsule Filler',
      clinicalNote: 'Excipient filler in over 60% of oral tablets; trace whey protein',
    ),
    TaxonomyAllergen(
      name: 'Casein / Whey (Cow Milk)',
      category: AllergyCategoryType.foodExcipient,
      subcategory: 'Milk Protein Excipient',
      clinicalNote: 'Severe anaphylaxis trigger in dry powder inhalers',
    ),
    TaxonomyAllergen(
      name: 'Peanut Oil (Arachis Oil)',
      category: AllergyCategoryType.foodExcipient,
      subcategory: 'Lipophilic Drug Vehicle',
      clinicalNote: 'Excipient in Prometrium progesterone capsules & topicals',
    ),
    TaxonomyAllergen(
      name: 'Sesame Oil',
      category: AllergyCategoryType.foodExcipient,
      subcategory: 'Injectable Vehicle',
      clinicalNote: 'Carrier for intramuscular depot steroid and hormone injections',
    ),
    TaxonomyAllergen(
      name: 'Soybean Oil',
      category: AllergyCategoryType.foodExcipient,
      subcategory: 'Lipid Emulsion Vehicle',
      clinicalNote: 'Used in Propofol and parenteral IV lipid nutrition formulas',
    ),
    TaxonomyAllergen(
      name: 'Egg / Egg Lecithin (Ovalbumin)',
      category: AllergyCategoryType.foodExcipient,
      subcategory: 'Emulsifier & Vaccine Substrate',
      clinicalNote: 'Found in Propofol emulsions and egg-derived vaccines',
    ),
    TaxonomyAllergen(
      name: 'Gluten / Wheat Starch',
      category: AllergyCategoryType.foodExcipient,
      subcategory: 'Binder & Disintegrant',
      clinicalNote: 'Critical check for Celiac disease and IgE wheat hypersensitivity',
    ),
    TaxonomyAllergen(
      name: 'Shellfish / Glucosamine',
      category: AllergyCategoryType.foodExcipient,
      subcategory: 'Nutraceutical / Active',
      clinicalNote: 'Derived from chitin exoskeletons of shrimp/crab',
    ),
    TaxonomyAllergen(
      name: 'Fish / Protamine Sulfate',
      category: AllergyCategoryType.foodExcipient,
      subcategory: 'Heparin Reversal / Insulin NPH',
      clinicalNote: 'Cross-reactive in severe salmon/fish allergic individuals',
    ),

    // 3. Inactive Additives, Preservatives, & Animal Products
    TaxonomyAllergen(
      name: 'Gelatin (Bovine / Porcine)',
      category: AllergyCategoryType.inactiveAdditive,
      subcategory: 'Capsule Shells & Plasma Expanders',
      clinicalNote: 'Alpha-gal IgE cross-reactivity and direct gelatin hypersensitivity',
    ),
    TaxonomyAllergen(
      name: 'Alpha-gal (Mammalian Byproducts)',
      category: AllergyCategoryType.inactiveAdditive,
      subcategory: 'Oligosaccharide Epitope',
      clinicalNote: 'Delayed reaction (3-6 hours) to mammal-derived drugs & gelatin',
    ),
    TaxonomyAllergen(
      name: 'Sulfites (Sodium Metabisulfite)',
      category: AllergyCategoryType.inactiveAdditive,
      subcategory: 'Antioxidant & Preservative',
      clinicalNote: 'Triggers severe bronchospasm in steroid-dependent asthmatics',
    ),
    TaxonomyAllergen(
      name: 'Tartrazine (FD&C Yellow #5)',
      category: AllergyCategoryType.inactiveAdditive,
      subcategory: 'Azo Dye / Colorant',
      clinicalNote: 'Cross-reactivity triad with Aspirin and asthma (Samter’s triad)',
    ),
    TaxonomyAllergen(
      name: 'Red Dye #40 (Allura Red)',
      category: AllergyCategoryType.inactiveAdditive,
      subcategory: 'Pharmaceutical Colorant',
      clinicalNote: 'Cutaneous urticaria and contact dermatitis',
    ),
    TaxonomyAllergen(
      name: 'Carmine / Cochineal Extract',
      category: AllergyCategoryType.inactiveAdditive,
      subcategory: 'Natural Red Colorant',
      clinicalNote: 'Insect-derived protein trigger for severe anaphylaxis',
    ),
    TaxonomyAllergen(
      name: 'Parabens (Methyl/Propylparaben)',
      category: AllergyCategoryType.inactiveAdditive,
      subcategory: 'Antimicrobial Preservative',
      clinicalNote: 'Common in multi-dose injectables and topical gels',
    ),
    TaxonomyAllergen(
      name: 'Benzyl Alcohol',
      category: AllergyCategoryType.inactiveAdditive,
      subcategory: 'Preservative & Solvent',
      clinicalNote: 'Gasping syndrome in neonates; contact hypersensitivity',
    ),
    TaxonomyAllergen(
      name: 'Propylene Glycol',
      category: AllergyCategoryType.inactiveAdditive,
      subcategory: 'Solvent & Co-Solvent',
      clinicalNote: 'Used in IV Lorazepam, Phenytoin; cutaneous contact allergy',
    ),
    TaxonomyAllergen(
      name: 'Aspartame (Phenylalanine)',
      category: AllergyCategoryType.inactiveAdditive,
      subcategory: 'Sweetener (Chewable Tablets)',
      clinicalNote: 'Contraindicated in Phenylketonuria (PKU); headache trigger',
    ),

    // 4. Environmental & Material Sensitivities
    TaxonomyAllergen(
      name: 'Natural Rubber Latex',
      category: AllergyCategoryType.environmentalMaterial,
      subcategory: 'Medical Device / Packaging Material',
      clinicalNote: 'Vial rubber stoppers, syringe plungers, and transdermal backing',
    ),
    TaxonomyAllergen(
      name: 'Topical Adhesives (Acrylates)',
      category: AllergyCategoryType.environmentalMaterial,
      subcategory: 'Transdermal Patch Adhesives',
      clinicalNote: 'Contact dermatitis and blistering under medicated patches',
    ),
    TaxonomyAllergen(
      name: 'Colophony (Rosin)',
      category: AllergyCategoryType.environmentalMaterial,
      subcategory: 'Adhesive Tackifier',
      clinicalNote: 'Resin used in bandage and patch manufacturing',
    ),
    TaxonomyAllergen(
      name: 'Tetracyclines (Doxycycline / Minocycline)',
      category: AllergyCategoryType.directDrug,
      subcategory: 'Broad-Spectrum Antibiotic',
      clinicalNote: 'Cross-sensitivity across tetracycline class; severe phototoxic and hypersensitivity reactions',
    ),
    TaxonomyAllergen(
      name: 'Aromatic Anticonvulsants (Carbamazepine / Phenytoin)',
      category: AllergyCategoryType.directDrug,
      subcategory: 'Antiepileptic / Mood Stabilizer',
      clinicalNote: 'High risk of DRESS syndrome and SJS/TEN; screening for HLA-B*1502 indicated',
    ),
    TaxonomyAllergen(
      name: 'Local Anesthetics (Lidocaine / Procaine)',
      category: AllergyCategoryType.directDrug,
      subcategory: 'Anesthetic',
      clinicalNote: 'Distinguish between amide-type (Lidocaine) and ester-type (Procaine) allergies',
    ),
    TaxonomyAllergen(
      name: 'Heparin / Low-Molecular-Weight Heparin (LMWH)',
      category: AllergyCategoryType.directDrug,
      subcategory: 'Anticoagulant',
      clinicalNote: 'Type II Heparin-Induced Thrombocytopenia (HIT) antibody immune-mediated risk',
    ),
    TaxonomyAllergen(
      name: 'Tree Nuts (Almond / Walnut / Cashew)',
      category: AllergyCategoryType.foodExcipient,
      subcategory: 'Nut Oils & Derivatives',
      clinicalNote: 'Nut-derived lipophilic carriers and topical dermatological formulations',
    ),
    TaxonomyAllergen(
      name: 'Corn Starch / Dextrose',
      category: AllergyCategoryType.foodExcipient,
      subcategory: 'Tablet Binder & Diluent',
      clinicalNote: 'Common pharmaceutical binder; verify source in severe maize allergy',
    ),
    TaxonomyAllergen(
      name: 'Aspartame (Artificial Sweetener)',
      category: AllergyCategoryType.inactiveAdditive,
      subcategory: 'Sweetener & Flavoring Excipient',
      clinicalNote: 'Contains phenylalanine; dangerous in Phenylketonuria (PKU) and oral chewables',
    ),
    TaxonomyAllergen(
      name: 'Tartrazine (FD&C Yellow No. 5)',
      category: AllergyCategoryType.inactiveAdditive,
      subcategory: 'Azo Dye Colorant',
      clinicalNote: 'Cross-reacts frequently in aspirin-sensitive asthmatic patients (AERD)',
    ),
    TaxonomyAllergen(
      name: 'Chlorhexidine Gluconate',
      category: AllergyCategoryType.environmentalMaterial,
      subcategory: 'Topical Antiseptic',
      clinicalNote: 'Sensitization from surgical preps, impregnated catheters, and oral mouthwashes',
    ),
    TaxonomyAllergen(
      name: 'Nickel / Surgical Metal Alloys',
      category: AllergyCategoryType.environmentalMaterial,
      subcategory: 'Contact Metal',
      clinicalNote: 'Dermatitis from medical device components, clips, and needle coatings',
    ),
    TaxonomyAllergen(
      name: 'Photosensitivity / Sunlight (Drug-Induced)',
      category: AllergyCategoryType.environmentalMaterial,
      subcategory: 'Environmental Interaction',
      clinicalNote: 'Severe phototoxic/photoallergic flares with Thiazides, Tetracyclines, and Fluoroquinolones',
    ),
  ];

  static Color getCategoryColor(AllergyCategoryType category, BuildContext context) {
    final isDark = AppTheme.isDark(context);
    switch (category) {
      case AllergyCategoryType.all:
        return isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal;
      case AllergyCategoryType.directDrug:
        return isDark ? AppTheme.secondaryCyanLight : AppTheme.secondaryCyan;
      case AllergyCategoryType.foodExcipient:
        return isDark ? AppTheme.warningAmberLight : AppTheme.warningAmber;
      case AllergyCategoryType.inactiveAdditive:
        return isDark ? AppTheme.accentVioletLight : AppTheme.accentViolet;
      case AllergyCategoryType.environmentalMaterial:
        return isDark ? AppTheme.successGreenLight : AppTheme.successGreen;
    }
  }
}
