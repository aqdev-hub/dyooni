import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Rotates the image file at [path] 90° clockwise IN PLACE (same path, overwritten). Silently
/// does nothing if the file can't be decoded (e.g. an unsupported/corrupt format) — a failed
/// rotate must never destroy the original attachment.
///
/// The actual decode/rotate/encode work is CPU-heavy for a full-resolution photo (can easily take
/// several seconds) and runs via [compute] on a background isolate — running it directly on the
/// main isolate was blocking the UI thread for that whole time, which is what made the rotate
/// button feel "stuck"/unresponsive rather than actually broken.
Future<void> rotateImageFile90(String path) async {
  final file = File(path);
  final bytes = await file.readAsBytes();
  final rotatedBytes = await compute(_rotateBytes90, _RotateJob(bytes, path.toLowerCase().endsWith('.png')));
  if (rotatedBytes == null) return;
  await file.writeAsBytes(rotatedBytes);
}

class _RotateJob {
  const _RotateJob(this.bytes, this.isPng);
  final Uint8List bytes;
  final bool isPng;
}

/// Must be a top-level (or static) function — [compute] spawns it on a fresh isolate that has no
/// access to this file's other state, only whatever is passed in [job].
Uint8List? _rotateBytes90(_RotateJob job) {
  final decoded = img.decodeImage(job.bytes);
  if (decoded == null) return null;
  final rotated = img.copyRotate(decoded, angle: 90);
  return job.isPng ? Uint8List.fromList(img.encodePng(rotated)) : Uint8List.fromList(img.encodeJpg(rotated));
}
