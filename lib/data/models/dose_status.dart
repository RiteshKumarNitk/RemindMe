/// Outcome of a single scheduled dose.
enum DoseStatus {
  pending,
  taken,
  skipped,
  missed;

  static DoseStatus from(String value) => DoseStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => DoseStatus.pending,
  );
}
