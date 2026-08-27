import 'dart:io';

import 'package:image/image.dart' as img;

/// Rotates the image file at [path] 90° clockwise IN PLACE (same path, overwritten). Silently
/// does nothing if the file can't be decoded (e.g. an unsupported/corrupt format) — a failed
/// rotate must never destroy the original attachment.
Future<void> rotateImageFile90(String path) async {
  final file = File(path);
  final bytes = await file.readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return;
  final rotated = img.copyRotate(decoded, angle: 90);
  final encoded = path.toLowerCase().endsWith('.png') ? img.encodePng(rotated) : img.encodeJpg(rotated);
  await file.writeAsBytes(encoded);
}
