import '../../models/backup_snapshot.dart';

/// How [BackupRepository.restoreSnapshot] should reconcile the backup with what's already
/// stored. See the method's own doc comment for the exact semantics of each.
enum RestoreMode { merge, replace }

/// `logic/` imports this interface only — never the underlying accounts/transactions/personal-
/// data repositories or any file/crypto API directly (see repository-di.md).
abstract class BackupRepository {
  /// Reads every account/transaction/personal-data record currently stored and returns a single
  /// portable snapshot. Deliberately does NOT touch the filesystem or encryption itself — writing
  /// that snapshot to a file, encrypting it, and handing it to the OS/Downloads folder is a
  /// device/UI concern, not a data concern (see logic/settings/local_backup_provider.dart).
  Future<BackupSnapshot> buildSnapshot();

  /// [RestoreMode.merge]: upserts every account/transaction from [snapshot] and overwrites
  /// personal data. NEVER deletes anything not present in [snapshot] — the safe, non-destructive
  /// default.
  ///
  /// [RestoreMode.replace]: first deletes EVERY account currently stored (cascading to their
  /// transactions, same as deleting an account from Account Details), THEN inserts everything
  /// from [snapshot] fresh — a full clean restore. Genuinely destructive to current data not
  /// present in the backup; callers must get an explicit, unambiguous confirmation from the
  /// person before calling this mode (see LocalBackupScreen's restore-options dialog).
  ///
  /// Throws a `ValidationException('backupIncompatible')` if [snapshot] was made by a newer,
  /// incompatible app version (see BackupSnapshot.currentSchemaVersion).
  Future<void> restoreSnapshot(BackupSnapshot snapshot, {required RestoreMode mode});
}
