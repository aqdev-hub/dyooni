/// `daily`: one automatic snapshot per calendar day, updated in place while that day is still
/// "today", then frozen forever once a new day starts (see DriveBackupRepositoryImpl).
/// `manual`: created only by the person tapping "حفظ نسخة احتياطية الآن" — always a brand-new
/// file, never counted in the daily 7-backup retention window and never overwritten.
enum DriveBackupType { daily, manual }

/// What the app actually needs to know about one backup file living on Drive — deliberately NOT
/// the full googleapis `drive.File` type (see data/remote/drive/drive_backup_datasource.dart for
/// why that stays confined to the data source).
class DriveBackupMetadata {
  const DriveBackupMetadata({
    required this.fileId,
    required this.backupId,
    required this.userId,
    required this.type,
    required this.backupDate,
    required this.createdAt,
    required this.updatedAt,
    required this.appVersion,
    required this.schemaVersion,
    required this.dataChecksum,
    this.sizeBytes,
  });

  final String fileId;
  final String backupId;
  final String userId;
  final DriveBackupType type;

  /// The calendar day (device-local, `yyyy-MM-dd`) this backup represents — for `daily` backups
  /// this is the "which day's snapshot is this" identity; for `manual` ones it's just the day it
  /// happened to be created on.
  final String backupDate;

  final DateTime createdAt;
  final DateTime updatedAt;
  final String appVersion;
  final int schemaVersion;
  final String dataChecksum;
  final int? sizeBytes;
}
