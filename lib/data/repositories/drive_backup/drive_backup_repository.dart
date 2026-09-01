import '../../models/drive_backup_metadata.dart';
import '../backup/backup_repository.dart' show RestoreMode;

/// `logic/` imports this interface only — never DriveBackupDataSource or googleapis directly
/// (see repository-di.md).
abstract class DriveBackupRepository {
  /// Whether a Google account with Drive access is currently usable — `false` means the screen
  /// must offer [connectGoogleAccount] before anything else here will work.
  Future<bool> hasGoogleAccess();

  /// The ONLY method in this whole feature allowed to trigger an interactive Google
  /// account-picker prompt — call this only from an explicit person-initiated button tap, never
  /// from a silent/opportunistic check.
  Future<void> connectGoogleAccount();

  /// The heart of the "smart daily backup" system — see the class doc comment on
  /// DriveBackupRepositoryImpl for the exact decision table this follows. Safe to call as often
  /// as convenient (app start, screen open, after a mutation): a call where nothing changed since
  /// the last successful backup uploads nothing and is cheap. Returns `null` when today's backup
  /// already existed and was already up to date (no upload happened); returns the fresh/updated
  /// metadata otherwise.
  Future<DriveBackupMetadata?> ensureTodayBackup();

  /// Always creates a brand-new file, tagged `manual` — completely independent of the daily
  /// bookkeeping and the 7-backup retention prune (see BackupType's doc comment).
  Future<DriveBackupMetadata> createManualBackup();

  /// Every backup (daily + manual) belonging to the current person, newest first.
  Future<List<DriveBackupMetadata>> listBackups();

  /// Downloads and restores the backup identified by [fileId] — reuses the exact same
  /// merge/replace semantics as the local backup feature (see BackupRepository.restoreSnapshot's
  /// doc comment), since both ultimately restore the same BackupSnapshot shape.
  Future<void> restoreBackup(String fileId, {required RestoreMode mode});
}
