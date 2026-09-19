import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Copies a picked/captured image — from wherever image_picker or the native camera returned it
/// (often a transient cache location the OS is free to clear at any time) — into this app's own
/// permanent documents directory, under `attachments/`, with a fresh UUID-based filename.
///
/// WHY THIS EXISTS (part 1 of the camera-crash hardening, see image_source_dialog.dart for part
/// 2 — the compression side): leaving a picked attachment at its ORIGINAL returned path risks it
/// disappearing later — the OS clears cache directories at will, more aggressively under exactly
/// the kind of memory pressure that can also kill this app's process while the native camera
/// Activity is in the foreground (see AndroidManifest.xml's "Camera-crash mitigation notes"). A
/// form that survives that process kill via its saved draft (see FormDraftStorage) but then
/// tries to restore an `attachmentPath` pointing at a now-cleared cache file is exactly what
/// produced the reported black screen/crash. Copying the file into a location this app owns and
/// controls, immediately once the pick completes, is what makes the attachment durable
/// regardless of what the OS does to its temp/cache folders afterwards.
///
/// Only ever COPIES, never moves — a failure partway through can never destroy the only copy of
/// the image the person just took.
abstract class AttachmentStorage {
  static const _uuid = Uuid();

  /// Pure helper — computes the destination path an attachment from [sourcePath] would be copied
  /// to, given an already-resolved [documentsPath]. Deliberately separated from [persist] (which
  /// does the real file IO and platform-channel work) so this naming/extension logic can be
  /// unit-tested without needing to fake path_provider or touch the real filesystem — see
  /// test/unit/core/attachment_storage_test.dart.
  static String buildDestinationPath(String documentsPath, String sourcePath, {String? idOverride}) {
    final id = idOverride ?? _uuid.v4();
    final extension = sourcePath.contains('.') ? sourcePath.substring(sourcePath.lastIndexOf('.')) : '.jpg';
    return '$documentsPath/attachments/$id$extension';
  }

  /// Copies the file at [sourcePath] into this app's permanent attachments folder and returns
  /// the new, durable path. Throws if the copy itself fails (e.g. the source no longer exists) —
  /// callers fall back to the original path on failure rather than silently losing the
  /// attachment (see add_account_screen.dart / add_transaction_screen.dart's `_chooseImage`).
  static Future<String> persist(String sourcePath) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final destinationPath = buildDestinationPath(documentsDir.path, sourcePath);
    final destinationFile = File(destinationPath);
    if (!await destinationFile.parent.exists()) {
      await destinationFile.parent.create(recursive: true);
    }
    await File(sourcePath).copy(destinationPath);
    return destinationPath;
  }
}
