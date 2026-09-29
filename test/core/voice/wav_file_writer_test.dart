import 'dart:io';
import 'dart:typed_data';

import 'package:dyooni/core/voice/wav_file_writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finalises a playable PCM WAV header after sequential chunks', () async {
    final directory = await Directory.systemTemp.createTemp('dyooni_wav_test_');
    final path = '${directory.path}${Platform.pathSeparator}recording.wav';
    try {
      final writer = WavFileWriter(path: path);
      await writer.open();
      await writer.write(Uint8List.fromList(<int>[1, 2, 3, 4]));
      await writer.write(Uint8List.fromList(<int>[5, 6, 7, 8, 9, 10]));
      await writer.close();

      final bytes = await File(path).readAsBytes();
      expect(bytes.length, 54);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
      expect(ByteData.sublistView(bytes).getUint32(40, Endian.little), 10);
      expect(bytes.sublist(44), <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
