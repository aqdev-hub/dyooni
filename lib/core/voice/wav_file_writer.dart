import 'dart:io';
import 'dart:typed_data';

/// Writes raw PCM16-mono audio chunks to a valid, playable .wav file, incrementally, as they
/// arrive from the recording stream — so the writer never needs to know the total duration up
/// front. A standard RIFF/WAVE header must declare the total data length, which is only known
/// AFTER the last byte has been written; the fix is to write a placeholder header first, then
/// go back and patch it with the real sizes in [close].
///
/// This class is deliberately "dumb" — no business logic, no knowledge of voice commands or
/// transactions, just "append these bytes, then finalize a playable file" — matching this
/// project's existing pattern of keeping data-source-style classes free of business rules (see
/// OnboardingLocalDataSource's doc comment for the same principle applied elsewhere).
class WavFileWriter {
  WavFileWriter({
    required this.path,
    this.sampleRate = 16000,
    this.numChannels = 1,
    this.bitsPerSample = 16,
  });

  final String path;
  final int sampleRate;
  final int numChannels;
  final int bitsPerSample;

  RandomAccessFile? _file;
  int _dataLength = 0;

  /// Opens the file and writes a 44-byte placeholder header (real sizes filled in later).
  Future<void> open() async {
    final file = File(path);
    _file = await file.open(mode: FileMode.write);
    await _file!.writeFrom(_buildHeader(0));
  }

  /// Appends one chunk of raw PCM16 bytes. Safe to call rapidly and repeatedly — each call is a
  /// plain file append, no re-encoding or re-reading of what was already written.
  Future<void> write(Uint8List chunk) async {
    final file = _file;
    if (file == null) return;
    await file.writeFrom(chunk);
    _dataLength += chunk.length;
  }

  /// Rewrites the header with the real, now-known data length, then closes the file handle.
  /// Must be called exactly once, after the last [write] — the file is not a valid/playable .wav
  /// until this runs.
  Future<void> close() async {
    final file = _file;
    if (file == null) return;
    await file.setPosition(0);
    await file.writeFrom(_buildHeader(_dataLength));
    await file.flush();
    await file.close();
    _file = null;
  }

  Uint8List _buildHeader(int dataLength) {
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;
    final header = ByteData(44);

    void writeAscii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        header.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    header.setUint32(4, 36 + dataLength, Endian.little); // overall file size - 8
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // fmt chunk size (16 = PCM)
    header.setUint16(20, 1, Endian.little); // audio format: 1 = PCM (uncompressed)
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    writeAscii(36, 'data');
    header.setUint32(40, dataLength, Endian.little);
    return header.buffer.asUint8List();
  }
}
