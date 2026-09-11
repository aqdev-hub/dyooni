import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
// Adds the `.authenticatedClient()` extension method used in `_api()` below — this package's
// entire purpose is exactly that one method, already a project dependency since an earlier batch
// (see pubspec.yaml's "Google Drive backup/restore" comment).
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

import '../../../core/utils/app_exception.dart';

/// A backup file as Drive actually reports it — just the handful of fields this feature reads
/// (id, custom appProperties, size). Kept deliberately separate from googleapis' own `drive.File`
/// type so nothing above this file (repository, logic, view) ever needs to import `googleapis`
/// directly — the same "data source owns the remote SDK, repository stays agnostic" split used
/// throughout this project (see data/remote/firestore/accounts_firestore_datasource.dart).
class DriveRemoteFile {
  const DriveRemoteFile({required this.id, required this.appProperties, this.sizeBytes});
  final String id;
  final Map<String, String> appProperties;
  final int? sizeBytes;
}

/// Talks to the Google Drive API only — every account/transaction/checksum DECISION (does today
/// already have a backup, is it stale, which old ones to prune) lives in
/// DriveBackupRepositoryImpl, never here. This class only knows how to find/create the app's own
/// Drive folder and list/upload/download/delete JSON files inside it.
///
/// Uses the `drive.file` scope ALREADY requested at Google sign-in (see
/// logic/auth/auth_provider.dart's `googleSignInProvider`) — the least-privilege scope that only
/// ever grants access to files this app itself created, never the person's whole Drive. Every
/// method here silently reuses whichever Google account is already signed in
/// (`currentUser`/`signInSilently()`) and NEVER calls the interactive `signIn()` itself — that
/// would pop up an unexpected sign-in prompt during a silent background check (see
/// DriveBackupController.build()). The only place an interactive prompt is allowed to appear is
/// [connectGoogleAccount], which the person triggers explicitly by tapping a button.
class DriveBackupDataSource {
  DriveBackupDataSource(this._googleSignIn);
  final GoogleSignIn _googleSignIn;

  static const _folderName = 'Dyooni Backups';
  static const _mimeType = 'application/json';
  static const _folderMimeType = 'application/vnd.google-apps.folder';

  String? _cachedFolderId;

  Future<bool> hasGoogleAccess() async {
    final account = _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
    return account != null;
  }

  /// The ONLY place in this class allowed to trigger an interactive Google account picker.
  Future<void> connectGoogleAccount() async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw const ValidationException('driveBackupNoGoogleAccount');
  }

  Future<drive.DriveApi> _api() async {
    final account = _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
    if (account == null) throw const ValidationException('driveBackupNoGoogleAccount');
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) throw const ValidationException('driveBackupNoGoogleAccount');
    return drive.DriveApi(client);
  }

  Future<String> _folderId(drive.DriveApi api) async {
    if (_cachedFolderId != null) return _cachedFolderId!;
    final existing = await api.files.list(
      q: "name = '$_folderName' and mimeType = '$_folderMimeType' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id, name)',
    );
    final files = existing.files;
    if (files != null && files.isNotEmpty) {
      _cachedFolderId = files.first.id;
      return _cachedFolderId!;
    }
    final folder = await api.files.create(drive.File()
      ..name = _folderName
      ..mimeType = _folderMimeType);
    _cachedFolderId = folder.id;
    return _cachedFolderId!;
  }

  DriveRemoteFile _mapFile(drive.File file) => DriveRemoteFile(
        id: file.id!,
        appProperties: Map<String, String>.from(file.appProperties ?? const {}),
        sizeBytes: file.size == null ? null : int.tryParse(file.size!),
      );

  /// The single `daily` backup dated [backupDate] for [userId], if one already exists —
  /// `null` otherwise. `manual` backups never collide with this lookup (different `backupType`
  /// property), so a daily backup can never accidentally overwrite a manual one or vice versa.
  Future<DriveRemoteFile?> findBackup({
    required String userId,
    required String type,
    required String backupDate,
  }) async {
    try {
      final api = await _api();
      final folderId = await _folderId(api);
      final query = "'$folderId' in parents and trashed = false"
          " and appProperties has { key='userId' and value='$userId' }"
          " and appProperties has { key='backupType' and value='$type' }"
          " and appProperties has { key='backupDate' and value='$backupDate' }";
      final result = await api.files.list(q: query, spaces: 'drive', $fields: 'files(id, name, size, appProperties)');
      final files = result.files;
      if (files == null || files.isEmpty) return null;
      return _mapFile(files.first);
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnexpectedException(internalDetail: e.toString());
    }
  }

  /// Every backup belonging to [userId], optionally narrowed to [type] (`null` = both `daily`
  /// and `manual`) — used for the browse/restore list and for pruning old daily backups. Never
  /// returns another account's backups: the `userId` filter (Firebase Auth uid, stamped into
  /// every file's appProperties at upload time — see DriveBackupRepositoryImpl) is applied on
  /// every query, on top of the `drive.file` scope already confining visibility to files this
  /// app itself created.
  Future<List<DriveRemoteFile>> listBackups({required String userId, String? type}) async {
    try {
      final api = await _api();
      final folderId = await _folderId(api);
      final buffer = StringBuffer(
        "'$folderId' in parents and trashed = false and appProperties has { key='userId' and value='$userId' }",
      );
      if (type != null) buffer.write(" and appProperties has { key='backupType' and value='$type' }");
      final result = await api.files.list(q: buffer.toString(), spaces: 'drive', $fields: 'files(id, name, size, appProperties)');
      return (result.files ?? const []).map(_mapFile).toList();
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnexpectedException(internalDetail: e.toString());
    }
  }

  /// [fileId] `null` → creates a brand-new file. [fileId] non-null → overwrites that SAME file's
  /// content and appProperties in place (used only for updating today's still-open daily
  /// backup — see DriveBackupRepositoryImpl.ensureTodayBackup).
  Future<DriveRemoteFile> uploadOrUpdate({
    required String? fileId,
    required String fileName,
    required String content,
    required Map<String, String> appProperties,
  }) async {
    try {
      final api = await _api();
      final bytes = utf8.encode(content);
      final media = drive.Media(Stream.value(bytes), bytes.length, contentType: _mimeType);

      if (fileId == null) {
        final folderId = await _folderId(api);
        final created = await api.files.create(
          drive.File()
            ..name = fileName
            ..parents = [folderId]
            ..appProperties = appProperties,
          uploadMedia: media,
          $fields: 'id, name, size, appProperties',
        );
        return _mapFile(created);
      }

      final updated = await api.files.update(
        drive.File()
          ..name = fileName
          ..appProperties = appProperties,
        fileId,
        uploadMedia: media,
        $fields: 'id, name, size, appProperties',
      );
      return _mapFile(updated);
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnexpectedException(internalDetail: e.toString());
    }
  }

  Future<String> downloadContent(String fileId) async {
    try {
      final api = await _api();
      final media = await api.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }
      return utf8.decode(bytes);
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnexpectedException(internalDetail: e.toString());
    }
  }

  /// A single failed delete is swallowed by the CALLER (see
  /// DriveBackupRepositoryImpl._pruneOldDailyBackups), not here — this method just reports
  /// whether the underlying API call itself threw.
  Future<void> delete(String fileId) async {
    try {
      final api = await _api();
      await api.files.delete(fileId);
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnexpectedException(internalDetail: e.toString());
    }
  }
}
