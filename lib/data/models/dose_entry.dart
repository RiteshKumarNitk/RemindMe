import 'dose_status.dart';
import 'medicine.dart';
import 'medicine_dose.dart';

/// A [MedicineDose] joined with its [Medicine], used across the UI.
class DoseEntry {
  final MedicineDose dose;
  final Medicine medicine;

  const DoseEntry(this.dose, this.medicine);

  /// Status taking the grace period into account: a pending dose whose
  /// (snoozed or original) time plus the grace period has passed is shown
  /// as missed even if it was never explicitly acted on.
  DoseStatus effectiveStatus(Duration grace, DateTime now) {
    if (dose.status != DoseStatus.pending) return dose.status;
    final effective = dose.snoozedUntil ?? dose.scheduledAt;
    if (effective.add(grace).isBefore(now)) return DoseStatus.missed;
    return DoseStatus.pending;
  }
}
