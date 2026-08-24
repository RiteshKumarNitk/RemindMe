/// How often a medicine repeats.
///
/// [daily]      -> reminder(s) fire every day
/// [specificDays] -> reminder(s) fire only on [Medicine.selectedDays]
/// [once]       -> a single reminder on [Medicine.onceDate]
/// [multiple]   -> several reminder times every day
enum MedicineFrequency {
  daily,
  specificDays,
  once,
  multiple;

  static MedicineFrequency from(String value) =>
      MedicineFrequency.values.firstWhere(
        (f) => f.name == value,
        orElse: () => MedicineFrequency.daily,
      );
}
