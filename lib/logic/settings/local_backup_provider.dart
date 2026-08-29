import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/utils/app_exception.dart';
import '../../data/models/backup_snapshot.dart';
import '../backup/backup_provider.dart';
import '../onboarding/onboarding_provider.dart' show sharedPreferencesProvider;

/// Drives the "حفظ واسترجاع البيانات من الجهاز" drawer item. [state] is the last-backup
/// timestamp (persisted, survives app restart) — `null` means no backup was ever made yet.
/// LocalBackupScreen watches this for its "آخر نسخة احتياطية: ..." label and calls
/// [createBackup]/[restoreFromFile] directly; both throw an [AppException] on failure rather than
/// encoding error state here, matching every other screen's `_errorMessage` mapping pattern.
final localBackupProvider = AsyncNotifierProvider<LocalBackupController, DateTime?>(
  LocalBackupController.new,
);

class LocalBackupController extends AsyncNotifier<DateTime?> {
  static const _lastBackupKey = 'last_local_backup_at';

  @override
  Future<DateTime?> build() async {
    final raw = ref.read(sharedPreferencesProvider).getString(_lastBackupKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Writes a timestamped JSON snapshot into the app's own documents directory and returns its
  /// path. The CALLER (LocalBackupScreen) hands that path to the OS share sheet — "where the
  /// file ends up" (Drive, WhatsApp, Files app...) is a device/UI concern, never assumed here.
  Future<String> createBackup() async {
    try {
      final snapshot = await ref.read(backupRepositoryProvider).buildSnapshot();
      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final file = File('${dir.path}/dyooni_backup_$stamp.json');
      await file.writeAsString(jsonEncode(snapshot.toJson()));

      await ref.read(sharedPreferencesProvider).setString(_lastBackupKey, now.toIso8601String());
      state = AsyncData(now);
      return file.path;
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnexpectedException(internalDetail: e.toString());
    }
  }

  /// Parses the picked file at [path] and restores it — see BackupRepository.restoreSnapshot's
  /// doc comment for the exact (non-destructive, upsert-only) restore semantics.
  Future<void> restoreFromFile(String path) async {
    try {
      final raw = await File(path).readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const ValidationException('backupFileInvalid');
      }
      final snapshot = BackupSnapshot.fromJson(decoded);
      await ref.read(backupRepositoryProvider).restoreSnapshot(snapshot);
    } on AppException {
      rethrow;
    } on FormatException {
      // jsonDecode throws this for a file that isn't valid JSON at all (e.g. the wrong file type
      // was picked) — mapped to the same user-facing message as a structurally-wrong JSON file.
      throw const ValidationException('backupFileInvalid');
    } catch (e) {
      throw UnexpectedException(internalDetail: e.toString());
    }
  }
}
