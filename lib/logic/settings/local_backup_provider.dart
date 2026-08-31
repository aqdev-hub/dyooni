import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/utils/app_exception.dart';
import '../../core/utils/backup_crypto.dart';
import '../../data/models/backup_snapshot.dart';
import '../../data/repositories/backup/backup_repository.dart';
import '../backup/backup_provider.dart';
import '../onboarding/onboarding_provider.dart' show sharedPreferencesProvider;

/// What LocalBackupScreen shows and needs after a successful (or previous) backup: when it
/// happened, where the file actually landed, and — because the person may want to move/share it
/// manually too (see the screen's small share icon) — its exact path.
class LocalBackupInfo {
  const LocalBackupInfo({this.lastBackupAt, this.lastBackupPath});
  final DateTime? lastBackupAt;
  final String? lastBackupPath;
}

/// The outcome of one [LocalBackupController.createBackup] call — [savedToDownloads] tells the
/// screen which success message to show (see the class doc comment on
/// LocalBackupController._resolveBackupDirectory for exactly when this is `false`).
class LocalBackupResult {
  const LocalBackupResult({required this.path, required this.savedToDownloads});
  final String path;
  final bool savedToDownloads;
}

/// Drives the "حفظ واسترجاع البيانات من الجهاز" drawer item. [state] is the last-backup info
/// (persisted, survives app restart) — `null` fields mean no backup was ever made yet.
/// LocalBackupScreen calls [createBackup]/[restoreFromFile] directly; both throw an
/// [AppException] on failure rather than encoding error state here, matching every other
/// screen's `_errorMessage` mapping pattern.
final localBackupProvider = AsyncNotifierProvider<LocalBackupController, LocalBackupInfo>(
  LocalBackupController.new,
);

class LocalBackupController extends AsyncNotifier<LocalBackupInfo> {
  static const _lastBackupAtKey = 'last_local_backup_at';
  static const _lastBackupPathKey = 'last_local_backup_path';

  @override
  Future<LocalBackupInfo> build() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(_lastBackupAtKey);
    return LocalBackupInfo(
      lastBackupAt: raw == null ? null : DateTime.tryParse(raw),
      lastBackupPath: prefs.getString(_lastBackupPathKey),
    );
  }

  /// Encrypts a fresh snapshot with [password] and writes it as a `.dyoonibackup` file — tries
  /// the device's PUBLIC Downloads/ديوني folder first (so the person can find it without hunting
  /// through the app's own private storage), and only falls back to the app's own documents
  /// folder if that fails.
  ///
  /// KNOWN, STATED LIMITATION: writing directly to the shared Downloads folder from app code
  /// (no picker, no share sheet) is NOT guaranteed on every Android version — Android 10 (API 29)
  /// needs `requestLegacyExternalStorage` (set in AndroidManifest.xml) to allow it at all, and
  /// Android 11+ ignores that flag entirely per Google's scoped-storage policy, so on some
  /// devices this write will fail even with everything configured correctly here. That failure
  /// is caught, NOT hidden: [LocalBackupResult.savedToDownloads] tells the screen exactly which
  /// case happened, so the person is told the truth about where their file actually is rather
  /// than being shown a generic "success" that could be misleading.
  Future<LocalBackupResult> createBackup(String password) async {
    try {
      final snapshot = await ref.read(backupRepositoryProvider).buildSnapshot();
      final plainJson = jsonEncode(snapshot.toJson());
      final envelope = await BackupCrypto.encryptAsync(plainJson, password);

      final (dir, savedToDownloads) = await _resolveBackupDirectory();
      final now = DateTime.now();
      final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final file = File('${dir.path}/dyooni_backup_$stamp.dyoonibackup');
      await file.writeAsString(envelope);

      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(_lastBackupAtKey, now.toIso8601String());
      await prefs.setString(_lastBackupPathKey, file.path);
      state = AsyncData(LocalBackupInfo(lastBackupAt: now, lastBackupPath: file.path));

      return LocalBackupResult(path: file.path, savedToDownloads: savedToDownloads);
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnexpectedException(internalDetail: e.toString());
    }
  }

  /// Returns `(directory, true)` for the public Downloads/ديوني folder if writing to it actually
  /// succeeds (verified with a real write-then-delete probe file, not just `create()` — a
  /// `create(recursive: true)` call can silently succeed on some Android 11+ devices while
  /// writing individual files into it still fails), or `(directory, false)` for the app's own
  /// sandboxed documents folder otherwise. iOS has no equivalent shared "Downloads" concept for
  /// third-party apps, so it always uses the app documents folder there — made visible in the
  /// Files app under "On My iPhone/ديوني" via the `UIFileSharingEnabled` +
  /// `LSSupportsOpeningDocumentsInPlace` keys added to Info.plist for this feature.
  Future<(Directory, bool)> _resolveBackupDirectory() async {
    if (Platform.isAndroid) {
      try {
        final downloads = Directory('/storage/emulated/0/Download/ديوني');
        if (!await downloads.exists()) await downloads.create(recursive: true);
        final probe = File('${downloads.path}/.dyooni_write_test');
        await probe.writeAsString('ok');
        await probe.delete();
        return (downloads, true);
      } catch (_) {
        // Falls through to the sandboxed fallback below — see this method's doc comment for
        // exactly which Android versions this affects and why.
      }
    }
    final documents = await getApplicationDocumentsDirectory();
    final folder = Directory('${documents.path}/ديوني');
    if (!await folder.exists()) await folder.create(recursive: true);
    return (folder, false);
  }

  /// Decrypts the picked file at [path] with [password] and restores it in [mode] — see
  /// BackupRepository.restoreSnapshot's doc comment for the exact merge-vs-replace semantics.
  Future<void> restoreFromFile(String path, String password, RestoreMode mode) async {
    try {
      final envelope = await File(path).readAsString();
      String plainJson;
      try {
        plainJson = await BackupCrypto.decryptAsync(envelope, password);
      } on FormatException catch (e) {
        throw ValidationException(e.message == 'password' ? 'backupWrongPassword' : 'backupFileInvalid');
      }

      final decoded = jsonDecode(plainJson);
      if (decoded is! Map<String, dynamic> || decoded['schemaVersion'] == null) {
        throw const ValidationException('backupFileInvalid');
      }
      final snapshot = BackupSnapshot.fromJson(decoded);
      await ref.read(backupRepositoryProvider).restoreSnapshot(snapshot, mode: mode);
    } on AppException {
      rethrow;
    } on FormatException {
      // jsonDecode throws this for content that isn't valid JSON at all after decryption —
      // treated the same as a structurally-wrong backup file.
      throw const ValidationException('backupFileInvalid');
    } catch (e) {
      throw UnexpectedException(internalDetail: e.toString());
    }
  }
}
