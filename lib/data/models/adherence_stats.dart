import 'dose_status.dart';

/// Counts of dose outcomes over a period.
class AdherenceStats {
  final int taken;
  final int missed;
  final int skipped;
  final int pending;

  const AdherenceStats({
    this.taken = 0,
    this.missed = 0,
    this.skipped = 0,
    this.pending = 0,
  });

  int get total => taken + missed + skipped + pending;

  int get resolved => taken + missed + skipped;

  /// Percent of resolved doses that were taken (0 when nothing resolved).
  int get adherencePercent {
    if (resolved == 0) return 0;
    return (taken * 100 / resolved).round();
  }

  AdherenceStats add(DoseStatus status) {
    switch (status) {
      case DoseStatus.taken:
        return AdherenceStats(
          taken: taken + 1,
          missed: missed,
          skipped: skipped,
          pending: pending,
        );
      case DoseStatus.missed:
        return AdherenceStats(
          taken: taken,
          missed: missed + 1,
          skipped: skipped,
          pending: pending,
        );
      case DoseStatus.skipped:
        return AdherenceStats(
          taken: taken,
          missed: missed,
          skipped: skipped + 1,
          pending: pending,
        );
      case DoseStatus.pending:
        return AdherenceStats(
          taken: taken,
          missed: missed,
          skipped: skipped,
          pending: pending + 1,
        );
    }
  }
}
