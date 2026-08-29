import '../../models/backup_snapshot.dart';

/// `logic/` imports this interface only — never the underlying accounts/transactions/personal-
/// data repositories or any file API directly (see repository-di.md).
abstract class BackupRepository {
  /// Reads every account/transaction/personal-data record currently stored and returns a single
  /// portable snapshot. Deliberately does NOT touch the filesystem itself — writing that snapshot
  /// to a file and handing it to the OS share sheet is a device/UI concern, not a data concern
  /// (see logic/settings/local_backup_provider.dart, which owns that step).
  Future<BackupSnapshot> buildSnapshot();

  /// Upserts every account/transaction from [snapshot] and overwrites personal data. NEVER
  /// deletes anything not present in [snapshot] — restoring an older backup can only add or
  /// update records, never silently remove ones created since that backup was made. Throws a
  /// `ValidationException('backupIncompatible')` if [snapshot] was made by a newer, incompatible
  /// app version (see BackupSnapshot.currentSchemaVersion).
  Future<void> restoreSnapshot(BackupSnapshot snapshot);
}
