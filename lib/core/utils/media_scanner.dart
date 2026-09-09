import 'dart:io';

import 'package:flutter/services.dart';

/// Tells Android's MediaStore about a file this app just wrote directly via `dart:io`
/// (bypassing MediaStore entirely) — without this, SAF-based pickers (like the `file_picker`
/// package used by the local-backup restore flow) and other apps' file browsers can fail to see
/// a freshly-written file even though it's genuinely on disk, because Android's own file index
/// was never told it exists. A plain file manager that reads the raw filesystem directly (not
/// through SAF/MediaStore) shows the file immediately regardless — which is exactly the
/// "the file IS there outside the app, but the in-app picker can't find it" symptom this fixes.
///
/// No-op on iOS/other platforms, which have no equivalent concept (iOS makes the app's own
/// documents folder visible via `UIFileSharingEnabled` instead — see Info.plist).
class MediaScanner {
  static const _channel = MethodChannel('dyooni/media_scanner');

  static Future<void> scanFile(String path) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('scanFile', {'path': path});
    } on PlatformException {
      // Best-effort only — if the scan call itself fails, the backup file is still safely on
      // disk; the person can always find/restore it via a regular file manager as a fallback.
    }
  }
}
