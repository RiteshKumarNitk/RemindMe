/// Checks for common drug interactions between medicines.
///
/// This uses a built-in database of well-known interactions. For production,
/// this could be connected to an FDA drug interaction API, but for an
/// offline-first elderly-focused app, a local database is more reliable.
class InteractionChecker {
  /// Known drug interaction groups. Medicines in the SAME group conflict
  /// with medicines in OTHER groups listed in [conflictsWith].
  static const List<InteractionGroup> _groups = [
    InteractionGroup(
      id: 'blood_thinners',
      name: 'Blood Thinners',
      keywords: ['warfarin', 'aspirin', 'clopidogrel', 'heparin', 'rivaroxaban', 'apixaban', 'dabigatran', 'edoxaban'],
      conflictsWith: ['nsaids', 'fish_oil_high_dose'],
      warning: 'Taking blood thinners together increases bleeding risk.',
    ),
    InteractionGroup(
      id: 'nsaids',
      name: 'NSAIDs (Pain Killers)',
      keywords: ['ibuprofen', 'naproxen', 'diclofenac', 'celecoxib', 'aspirin', 'mefenamic', 'ketorolac'],
      conflictsWith: ['blood_thinners', 'bp_medicines', 'lithium', 'methotrexate', 'ssri'],
      warning: 'NSAIDs can reduce the effectiveness of blood pressure medicines and increase bleeding risk with blood thinners.',
    ),
    InteractionGroup(
      id: 'bp_medicines',
      name: 'Blood Pressure Medicines',
      keywords: ['amlodipine', 'losartan', 'telmisartan', 'valsartan', 'metoprolol', 'atenolol', 'bisoprolol', 'enalapril', 'ramipril', 'lisinopril', 'hydrochlorothiazide', 'chlorthalidone', 'furosemide', 'torsemide'],
      conflictsWith: ['nsaids', 'potassium', 'lithium'],
      warning: 'NSAIDs can raise blood pressure and reduce the effectiveness of BP medicines.',
    ),
    InteractionGroup(
      id: 'diabetes_medicines',
      name: 'Diabetes Medicines',
      keywords: ['metformin', 'glipizide', 'glyburide', 'glimepiride', 'januvia', 'sitagliptin', 'empagliflozin', 'dapagliflozin', 'insulin', 'pioglitazone'],
      conflictsWith: ['alcohol'],
      warning: 'Alcohol can cause dangerous low blood sugar when taken with diabetes medicines.',
    ),
    InteractionGroup(
      id: 'ssri',
      name: 'Antidepressants (SSRI)',
      keywords: ['sertraline', 'fluoxetine', 'escitalopram', 'citalopram', 'paroxetine', 'fluvoxamine', 'venlafaxine', 'duloxetine'],
      conflictsWith: ['nsaids', 'blood_thinners', 'tramadol', 'st_johns'],
      warning: 'SSRIs combined with painkillers can increase bleeding risk.',
    ),
    InteractionGroup(
      id: 'st_johns',
      name: "St. John's Wort",
      keywords: ['st john', "st. john's", 'st johns'],
      conflictsWith: ['ssri', 'blood_thinners', 'bp_medicines', 'diabetes_medicines', 'birth_control'],
      warning: "St. John's Wort reduces the effectiveness of many medicines including blood pressure, diabetes, and birth control.",
    ),
    InteractionGroup(
      id: 'potassium',
      name: 'Potassium Supplements',
      keywords: ['potassium', 'k-dur', 'klor-con', 'slow-k'],
      conflictsWith: ['bp_medicines'],
      warning: 'Some blood pressure medicines (ACE inhibitors, ARBs) increase potassium levels. Extra potassium can be dangerous.',
    ),
    InteractionGroup(
      id: 'thyroid',
      name: 'Thyroid Medicines',
      keywords: ['levothyroxine', 'thyroxine', 'liothyronine', 'methimazole', 'ptu'],
      conflictsWith: ['calcium', 'iron', 'antacids'],
      warning: 'Calcium, iron, and antacids reduce absorption of thyroid medicines. Take thyroid medicine 4 hours apart.',
    ),
    InteractionGroup(
      id: 'calcium',
      name: 'Calcium Supplements',
      keywords: ['calcium', 'caltrate', 'os-cal', 'tums'],
      conflictsWith: ['thyroid', 'bp_medicines'],
      warning: 'Calcium can reduce absorption of thyroid medicines and interact with BP medicines.',
    ),
    InteractionGroup(
      id: 'iron',
      name: 'Iron Supplements',
      keywords: ['iron', 'ferrous', 'feosol', 'feglutim'],
      conflictsWith: ['thyroid'],
      warning: 'Iron reduces absorption of thyroid medicines. Take at least 4 hours apart.',
    ),
    InteractionGroup(
      id: 'antacids',
      name: 'Antacids / Acid Reducers',
      keywords: ['omeprazole', 'pantoprazole', 'esomeprazole', 'ranitidine', 'famotidine', 'tums', 'gelusil', 'maalox', 'mylanta'],
      conflictsWith: ['thyroid'],
      warning: 'Antacids reduce absorption of thyroid medicines. Take thyroid medicine 4 hours apart.',
    ),
    InteractionGroup(
      id: 'lithium',
      name: 'Lithium',
      keywords: ['lithium'],
      conflictsWith: ['nsaids', 'bp_medicines', 'diuretics'],
      warning: 'NSAIDs and some BP medicines can increase lithium levels to dangerous ranges.',
    ),
    InteractionGroup(
      id: 'tramadol',
      name: 'Tramadol / Opioid Painkillers',
      keywords: ['tramadol', 'codeine', 'hydrocodone', 'oxycodone', 'morphine'],
      conflictsWith: ['ssri', 'alcohol'],
      warning: 'Tramadol with SSRIs or alcohol can cause serotonin syndrome or dangerous sedation.',
    ),
    InteractionGroup(
      id: 'statins',
      name: 'Cholesterol Medicines (Statins)',
      keywords: ['atorvastatin', 'simvastatin', 'rosuvastatin', 'lovastatin', 'pravastatin', 'fluvastatin', 'pitavastatin'],
      conflictsWith: ['fibrate'],
      warning: 'Statins with fibrates increase risk of muscle damage (rhabdomyolysis).',
    ),
    InteractionGroup(
      id: 'fibrate',
      name: 'Fibrates (Cholesterol)',
      keywords: ['gemfibrozil', 'fenofibrate', 'bezafibrate'],
      conflictsWith: ['statins'],
      warning: 'Fibrates with statins increase risk of muscle damage.',
    ),
    InteractionGroup(
      id: 'alcohol',
      name: 'Alcohol',
      keywords: ['alcohol', 'wine', 'beer', 'spirits'],
      conflictsWith: ['diabetes_medicines', 'ssri', 'tramadol', 'bp_medicines'],
      warning: 'Alcohol can dangerously interact with diabetes medicines, antidepressants, and painkillers.',
    ),
    InteractionGroup(
      id: 'birth_control',
      name: 'Birth Control',
      keywords: ['birth control', 'contraceptive', 'ethinyl', 'levonorgestrel'],
      conflictsWith: ['st_johns'],
      warning: "St. John's Wort reduces the effectiveness of birth control.",
    ),
    InteractionGroup(
      id: 'methotrexate',
      name: 'Methotrexate',
      keywords: ['methotrexate', 'trexall', 'otrexup'],
      conflictsWith: ['nsaids', 'bp_medicines'],
      warning: 'NSAIDs can increase methotrexate toxicity.',
    ),
  ];

  /// Checks all user medicines against each other for interactions.
  /// Returns a list of [InteractionWarning]s.
  static List<InteractionWarning> checkInteractions(List<String> medicineNames) {
    final warnings = <InteractionWarning>[];
    final matchedGroups = <String, _MatchedGroup>{};

    // Find which groups each medicine matches
    for (final name in medicineNames) {
      final lowerName = name.toLowerCase();
      for (final group in _groups) {
        for (final keyword in group.keywords) {
          if (lowerName.contains(keyword)) {
            matchedGroups.putIfAbsent(
              group.id,
              () => _MatchedGroup(group: group, medicines: []),
            );
            matchedGroups[group.id]!.medicines.add(name);
            break;
          }
        }
      }
    }

    // Check for conflicts between matched groups
    final checkedPairs = <String>{};
    for (final entry in matchedGroups.entries) {
      final group = entry.value.group;
      for (final conflictId in group.conflictsWith) {
        if (!matchedGroups.containsKey(conflictId)) continue;

        // Avoid duplicate warnings (A-B and B-A)
        final pairKey = [group.id, conflictId].join('-');
        if (checkedPairs.contains(pairKey)) continue;
        checkedPairs.add(pairKey);

        final conflictGroup = matchedGroups[conflictId]!;
        warnings.add(InteractionWarning(
          medicine1: entry.value.medicines.first,
          medicine2: conflictGroup.medicines.first,
          group1: group.name,
          group2: conflictGroup.group.name,
          warning: group.warning,
          severity: _severity(group, conflictGroup.group),
        ));
      }
    }

    return warnings;
  }

  /// Checks a single new medicine against existing ones.
  static List<InteractionWarning> checkNewMedicine(
    String newMedicine,
    List<String> existingMedicines,
  ) {
    final all = [newMedicine, ...existingMedicines];
    return checkInteractions(all).where(
      (w) => w.medicine1 == newMedicine || w.medicine2 == newMedicine,
    ).toList();
  }

  static InteractionSeverity _severity(InteractionGroup a, InteractionGroup b) {
    // High severity pairs
    if ((a.id == 'blood_thinners' && b.id == 'nsaids') ||
        (a.id == 'ssri' && b.id == 'tramadol') ||
        (a.id == 'lithium' && b.id == 'nsaids') ||
        (a.id == 'methotrexate' && b.id == 'nsaids')) {
      return InteractionSeverity.high;
    }
    return InteractionSeverity.moderate;
  }
}

class InteractionGroup {
  final String id;
  final String name;
  final List<String> keywords;
  final List<String> conflictsWith;
  final String warning;

  const InteractionGroup({
    required this.id,
    required this.name,
    required this.keywords,
    required this.conflictsWith,
    required this.warning,
  });
}

class _MatchedGroup {
  final InteractionGroup group;
  final List<String> medicines;
  _MatchedGroup({required this.group, required this.medicines});
}

enum InteractionSeverity { moderate, high }

class InteractionWarning {
  final String medicine1;
  final String medicine2;
  final String group1;
  final String group2;
  final String warning;
  final InteractionSeverity severity;

  const InteractionWarning({
    required this.medicine1,
    required this.medicine2,
    required this.group1,
    required this.group2,
    required this.warning,
    required this.severity,
  });
}
