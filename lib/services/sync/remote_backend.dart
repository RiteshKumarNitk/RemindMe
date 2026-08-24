import '../../data/models/medicine.dart';
import '../../data/models/medicine_dose.dart';

/// A medicine snapshot exchanged with the cloud. [deleted] is a tombstone.
class RemoteMedicine {
  final Medicine medicine;
  final bool deleted;
  final DateTime updatedAt;
  const RemoteMedicine(this.medicine, this.deleted, this.updatedAt);
}

/// A dose snapshot exchanged with the cloud. [medicineName] is denormalized
/// so a watcher phone can show alerts without resolving the medicine.
class RemoteDose {
  final MedicineDose dose;
  final String medicineName;
  final bool deleted;
  final DateTime updatedAt;
  const RemoteDose(this.dose, this.medicineName, this.deleted, this.updatedAt);
}

/// Abstraction over the cloud backend so the sync logic can be unit-tested
/// with a fake and swapped (Firebase today, anything else later).
abstract class RemoteBackend {
  /// Connects to the backend. Throws when it is not configured (e.g. missing
  /// google-services.json) so callers can degrade gracefully.
  Future<void> initialize();

  /// Ensures an authenticated identity exists (Firebase anonymous auth).
  Future<void> signIn();

  /// Creates a new household and returns its share code.
  Future<String> createHousehold();

  /// Joins the household identified by [code]; returns the normalized code.
  Future<String> joinHousehold(String code);

  Future<String?> currentHousehold();

  /// Registers this device's push token with the household (best effort).
  Future<void> attachPushToken();

  Future<void> pushMedicines(List<RemoteMedicine> items);

  Future<void> pushDoses(List<RemoteDose> items);

  /// Everything changed after [since] (inclusive of tombstones).
  Future<List<RemoteMedicine>> pullMedicines(DateTime since);

  Future<List<RemoteDose>> pullDoses(DateTime since);

  /// Live stream of dose changes (used by watchers for missed-dose alerts).
  Stream<List<RemoteDose>> watchDoses();

  Future<void> dispose();
}
