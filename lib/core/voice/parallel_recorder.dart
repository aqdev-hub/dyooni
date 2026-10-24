import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'wav_file_writer.dart';

/// Keeps a copy of the person's voice as a .wav WHILE the system/cloud recognizer is listening,
/// so a command that was recognised online can still be replayed from its entry later (the local
/// Whisper engine always had this; the cloud engine returned `null` for the path).
///
/// BEST EFFORT, never in the recognizer's way:
///  * every failure here is swallowed — the recognition itself must never depend on this class;
///  * it is started only AFTER the recognizer's own `listen()` has begun, so the recognizer has
///    already claimed the microphone;
///  * Android decides who gets audio when two clients capture at once, and some devices give the
///    second client silence. So [stop] checks the loudness of what was captured: a silent file is
///    deleted and `null` is returned — the person is never handed an empty recording.
class ParallelRecorder {
  ParallelRecorder({this.sampleRate = 16000});

  final int sampleRate;

  /// Same floor and minimum length the Whisper engine uses to call a recording "dead" / too short.
  static const _silentPeak = 0.003;
  static const _minAudioMs = 400;

  AudioRecorder? _recorder;
  WavFileWriter? _wav;
  StreamSubscription<Uint8List>? _sub;
  Future<void> _queue = Future<void>.value();
  double _peak = 0;
  int _bytes = 0;
  bool _paused = false;

  bool get isActive => _recorder != null;

  /// Starts (or resumes, after [pause]) capturing. Never throws.
  Future<void> start() async {
    try {
      final existing = _recorder;
      if (existing != null) {
        if (_paused) {
          await existing.resume();
          _paused = false;
        }
        return;
      }
      final probe = AudioRecorder();
      final allowed = await probe.hasPermission();
      if (!allowed) {
        await probe.dispose();
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/voice_recordings');
      if (!await folder.exists()) await folder.create(recursive: true);
      final wav = WavFileWriter(
        path: '${folder.path}/voice_${DateTime.now().microsecondsSinceEpoch}.wav',
        sampleRate: sampleRate,
      );
      await wav.open();
      _wav = wav;
      _peak = 0;
      _bytes = 0;
      _paused = false;
      _recorder = probe;
      final stream = await probe.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
          echoCancel: false,
          noiseSuppress: false,
        ),
      );
      _sub = stream.listen(_onChunk, onError: (_) {});
    } catch (e) {
      debugPrint('[voice] cloud parallel recording could not start: $e');
      await _discard();
    }
  }

  void _onChunk(Uint8List chunk) {
    var peak = _peak;
    final data = ByteData.sublistView(chunk);
    for (var i = 0; i + 1 < chunk.length; i += 2) {
      final v = data.getInt16(i, Endian.little).abs() / 32768.0;
      if (v > peak) peak = v;
    }
    _peak = peak;
    _bytes += chunk.length;
    _queue = _queue.then((_) => _wav?.write(chunk)).catchError((_) {});
  }

  /// Holds the file open but stops capturing (the app is speaking a question).
  Future<void> pause() async {
    try {
      if (_recorder != null && !_paused) {
        await _recorder!.pause();
        _paused = true;
      }
    } catch (_) {}
  }

  /// Ends the capture. Returns the file path, or `null` when nothing usable was captured
  /// (never started, too short, or silent because the OS gave this client no audio).
  Future<String?> stop() async {
    if (_recorder == null) return null;
    final path = _wav?.path;
    final bytes = _bytes;
    final peak = _peak;
    await _finish();
    final ms = bytes * 1000 ~/ (sampleRate * 2);
    debugPrint('[voice] cloud parallel recording: ms=$ms peak=${peak.toStringAsFixed(3)}');
    if (path == null) return null;
    if (ms < _minAudioMs || peak < _silentPeak) {
      await _delete(path);
      return null;
    }
    return path;
  }

  /// Ends the capture and deletes the file.
  Future<void> cancel() async {
    if (_recorder == null) return;
    final path = _wav?.path;
    await _finish();
    await _delete(path);
  }

  Future<void> _finish() async {
    try {
      await _sub?.cancel();
    } catch (_) {}
    _sub = null;
    try {
      await _queue;
    } catch (_) {}
    final recorder = _recorder;
    _recorder = null;
    try {
      await recorder?.stop();
    } catch (_) {}
    try {
      await recorder?.dispose();
    } catch (_) {}
    try {
      await _wav?.close();
    } catch (_) {}
    _wav = null;
    _paused = false;
  }

  Future<void> _discard() async {
    final path = _wav?.path;
    await _finish();
    await _delete(path);
  }

  Future<void> _delete(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
