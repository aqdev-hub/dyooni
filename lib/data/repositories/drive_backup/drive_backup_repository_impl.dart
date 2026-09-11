import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/app_exception.dart';
import '../../../core/utils/app_version.dart';
import '../../models/backup_snapshot.dart';
import '../../models/drive_backup_metadata.dart';
import '../../remote/drive/drive_backup_datasource.dart';
import '../backup/backup_repository.dart';
import 'drive_backup_repository.dart';

/// Google Drive is a HISTORY of independent daily snapshots — never a live mirror of Firestore,
/// never a second sync channel between devices. The rules [ensureTodayBackup] follows, in order,
/// every single time it runs:
///
/// 1. Build today's snapshot (via the SAME local [BackupRepository] the device backup feature
///    uses — no duplicated Firestore-reading logic) and its checksum (see [_checksum]).
/// 2. Look for an existing `daily` backup dated today, for this person.
/// 3. None exists → upload a brand-new one, then prune anything older than the last 7 daily
///    backups (ONLY after the new upload is confirmed — see [_pruneOldDailyBackups]).
/// 4. One exists but its stored checksum differs from the fresh one → overwrite that SAME file
///    (never a second file for the same date) with the new content/checksum. This is what makes
///    "today's backup" a single, continuously-refreshed snapshot rather than a growing pile of
///    same-day duplicates.
/// 5. One exists and its checksum matches → do nothing. No network upload for unchanged data —
///    this is the entire mechanism behind "don't re-upload on every reconnect", no separate
///    dirty-flag bookkeeping needed.
///
/// [createManualBackup] always uploads a brand-new file, tagged `manual`, and is completely
/// invisible to steps 2–5 above and to the 7-backup retention prune — a manual save can never
/// push a daily backup out of retention or collide with one.
///
/// DELIBERATELY UNENCRYPTED, unlike the local device backup feature: a Drive backup's
/// confidentiality already comes from Google's own account-level access control (only the
/// person's own Google account can ever see files created under the `drive.file` scope), whereas
/// a local `.dyoonibackup` file can be copied/shared through any app and needs its own password.
/// Adding a second password specifically for Drive backups was judged to add friction (a
/// password prompt would also be impossible during a SILENT background check) without a
/// corresponding real security gain here — stated explicitly rather than silently decided.
class DriveBackupRepositoryImpl implements DriveBackupRepository {
  DriveBackupRepositoryImpl(this._dataSource, this._backupRepository, this._userId);

  final DriveBackupDataSource _dataSource;
  final BackupRepository _backupRepository;

  /// Firebase Auth uid — NOT the Google account's own id — kept consistent with how every other
  /// piece of user data in this app is scoped (`users/{uid}/...` in Firestore). Every backup this
  /// class writes is stamped with this id, and every list/restore call filters by it, so a stray
  /// backup belonging to a different account can never surface here (requirement: no cross-user
  /// access).
  final String? _userId;

  static const _uuid = Uuid();
  static const _retainedDailyBackups = 7;

  @override
  Future<bool> hasGoogleAccess() => _dataSource.hasGoogleAccess();

  @override
  Future<void> connectGoogleAccount() => _dataSource.connectGoogleAccount();

  /// Order-independent (sorted by id first) so ties in Firestore's own query ordering for
  /// genuinely-unchanged data can never be mistaken for a real data change.
  String _checksum(BackupSnapshot snapshot) {
    final sortedAccounts = [...snapshot.accounts]..sort((a, b) => a.id.compareTo(b.id));
    final sortedTransactions = [...snapshot.transactions]..sort((a, b) => a.id.compareTo(b.id));
    final canonical = jsonEncode({
      'accounts': sortedAccounts.map((a) => a.toJson()).toList(),
      'transactions': sortedTransactions.map((t) => t.toJson()).toList(),
      'personalData': snapshot.personalData.toJson(),
    });
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _requireUserId() {
    final userId = _userId;
    if (userId == null) throw const ValidationException('driveBackupNoGoogleAccount');
    return userId;
  }

  @override
  Future<DriveBackupMetadata?> ensureTodayBackup() async {
    final userId = _requireUserId();
    try {
      final snapshot = await _backupRepository.buildSnapshot();
      final checksum = _checksum(snapshot);
      final today = _todayKey();

      final existing = await _dataSource.findBackup(userId: userId, type: 'daily', backupDate: today);
      if (existing != null && existing.appProperties['dataChecksum'] == checksum) {
        return null; // unchanged since the last successful backup — nothing to upload
      }

      final metadata = await _uploadSnapshot(
        snapshot: snapshot,
        checksum: checksum,
        type: DriveBackupType.daily,
        backupDate: today,
        existingFile: existing,
      );

      // Only a genuinely NEW daily file (existing == null) can push the retained count past 7 —
      // an in-place update of today's own file never changes how many daily files exist.
      if (existing == null) {
        await _pruneOldDailyBackups(userId);
      }
      return metadata;
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnexpectedException(internalDetail: e.toString());
    }
  }

  @override
  Future<DriveBackupMetadata> createManualBackup() async {
    _requireUserId();
    try {
      final snapshot = await _backupRepository.buildSnapshot();
      final checksum = _checksum(snapshot);
      return _uploadSnapshot(
        snapshot: snapshot,
        checksum: checksum,
        type: DriveBackupType.manual,
        backupDate: _todayKey(),
        existingFile: null, // manual backups are ALWAYS a new file — never overwritten in place
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnexpectedException(internalDetail: e.toString());
    }
  }

  Future<DriveBackupMetadata> _uploadSnapshot({
    required BackupSnapshot snapshot,
    required String checksum,
    required DriveBackupType type,
    required String backupDate,
    required DriveRemoteFile? existingFile,
  }) async {
    final userId = _requireUserId();
    final now = DateTime.now();
    final backupId = existingFile?.appProperties['backupId'] ?? _uuid.v4();
    final createdAt = existingFile == null ? now : (DateTime.tryParse(existingFile.appProperties['createdAt'] ?? '') ?? now);

    final envelope = {
      'backupVersion': 1,
      'backupId': backupId,
      'userId': userId,
      'backupType': type.name,
      'backupDate': backupDate,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'appVersion': kAppVersion,
      'schemaVersion': BackupSnapshot.currentSchemaVersion,
      'dataChecksum': checksum,
      'snapshot': snapshot.toJson(),
    };
    final content = jsonEncode(envelope);

    final appProperties = <String, String>{
      'userId': userId,
      'backupType': type.name,
      'backupDate': backupDate,
      'backupId': backupId,
      'dataChecksum': checksum,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'schemaVersion': BackupSnapshot.currentSchemaVersion.toString(),
    };

    final suffix = type == DriveBackupType.daily
        ? ''
        : '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}_manual';
    final fileName = 'Backup_$backupDate$suffix.json';

    final file = await _dataSource.uploadOrUpdate(
      fileId: existingFile?.id,
      fileName: fileName,
      content: content,
      appProperties: appProperties,
    );

    return DriveBackupMetadata(
      fileId: file.id,
      backupId: backupId,
      userId: userId,
      type: type,
      backupDate: backupDate,
      createdAt: createdAt,
      updatedAt: now,
      appVersion: kAppVersion,
      schemaVersion: BackupSnapshot.currentSchemaVersion,
      dataChecksum: checksum,
      sizeBytes: file.sizeBytes,
    );
  }

  /// Deletes the oldest `daily` backups beyond the last [_retainedDailyBackups] — called ONLY
  /// after a new daily backup has already been confirmed uploaded (see [ensureTodayBackup]), so
  /// a failed upload can never cost an old backup: this delete step simply never runs unless the
  /// upload above already succeeded.
  Future<void> _pruneOldDailyBackups(String userId) async {
    final dailies = await _dataSource.listBackups(userId: userId, type: 'daily');
    if (dailies.length <= _retainedDailyBackups) return;
    final sorted = [...dailies]..sort((a, b) => a.appProperties['backupDate']!.compareTo(b.appProperties['backupDate']!));
    final toDelete = sorted.take(sorted.length - _retainedDailyBackups);
    for (final file in toDelete) {
      try {
        await _dataSource.delete(file.id);
      } catch (_) {
        // A single failed delete must never abort the whole prune pass, and must never be
        // reported as a backup FAILURE — the new backup already succeeded before this ever runs.
        // A harmless leftover 8th/9th old file just gets pruned again on the next successful
        // ensureTodayBackup call.
      }
    }
  }

  @override
  Future<List<DriveBackupMetadata>> listBackups() async {
    final userId = _requireUserId();
    try {
      final files = await _dataSource.listBackups(userId: userId);
      return files.map(_fromRemoteFile).whereType<DriveBackupMetadata>().toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnexpectedException(internalDetail: e.toString());
    }
  }

  DriveBackupMetadata? _fromRemoteFile(DriveRemoteFile file) {
    final props = file.appProperties;
    final backupDate = props['backupDate'];
    if (backupDate == null) return null; // not a recognizable backup file — skip defensively
    return DriveBackupMetadata(
      fileId: file.id,
      backupId: props['backupId'] ?? file.id,
      userId: props['userId'] ?? '',
      type: props['backupType'] == 'manual' ? DriveBackupType.manual : DriveBackupType.daily,
      backupDate: backupDate,
      createdAt: DateTime.tryParse(props['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(props['updatedAt'] ?? '') ?? DateTime.now(),
      appVersion: '', // only embedded in the file's own content, not in appProperties
      schemaVersion: int.tryParse(props['schemaVersion'] ?? '') ?? BackupSnapshot.currentSchemaVersion,
      dataChecksum: props['dataChecksum'] ?? '',
      sizeBytes: file.sizeBytes,
    );
  }

  @override
  Future<void> restoreBackup(String fileId, {required RestoreMode mode}) async {
    try {
      final content = await _dataSource.downloadContent(fileId);
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic> || decoded['snapshot'] is! Map<String, dynamic>) {
        throw const ValidationException('backupFileInvalid');
      }
      final snapshot = BackupSnapshot.fromJson(decoded['snapshot'] as Map<String, dynamic>);
      await _backupRepository.restoreSnapshot(snapshot, mode: mode);
    } on AppException {
      rethrow;
    } on FormatException {
      throw const ValidationException('backupFileInvalid');
    } catch (e) {
      throw UnexpectedException(internalDetail: e.toString());
    }
  }
}
