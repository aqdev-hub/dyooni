import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

import 'vosk_model_provider.dart' show voskSampleRate;
import 'wav_file_writer.dart';

/// Owns the ONE and ONLY microphone session for a voice command, and fans out the SAME stream of
/// raw audio bytes to two independent consumers at once:
///  1. The Vosk [Recognizer] — turns the audio into text, live, as the person speaks.
///  2. A [WavFileWriter] — saves the exact same audio to a playable .wav file on disk.
///
/// This is the direct structural fix for the mic-contention bug identified in the voice-system
/// diagnosis: the previous design opened TWO separate mic sessions (`speech_to_text`'s own +
/// `record`'s file-based `start()`), which silently starved one of them of real audio on many
/// Android devices — the app never actually heard anything, hence "لم يتم رصد أي كلام" even while
/// the person was genuinely speaking. Here there is exactly one `AudioRecorder.startStream()`
/// call; everything downstream is pure Dart-side fan-out of bytes already captured — no second
/// consumer ever touches the microphone, so the conflict is structurally impossible, not just
/// "less likely."
class OfflineSpeechEngine {
  OfflineSpeechEngine({required this.model, this.sampleRate = voskSampleRate});

  final Model model;
  final int sampleRate;

  final _recorder = AudioRecorder();
  Recognizer? _recognizer;
  WavFileWriter? _wavWriter;
  StreamSubscription<Uint8List>? _micSubscription;

  final _partialController = StreamController<String>.broadcast();
  final _finalController = StreamController<String>.broadcast();

  /// Live, not-yet-final text — updates continuously while the person is still talking. Fills the
  /// same UI role `speech_to_text`'s `onResult` with `finalResult: false` used to play.
  Stream<String> get partialResults => _partialController.stream;

  /// Fires once per finished utterance, whenever Vosk itself decides enough silence/certainty was
  /// reached. Fills the same role as `finalResult: true` in the old flow.
  Stream<String> get finalResults => _finalController.stream;

  bool get isListening => _micSubscription != null;

  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Starts the single microphone session: creates a fresh recognizer bound to [model], opens the
  /// destination .wav file, then opens ONE raw audio stream and subscribes to it.
  Future<void> start() async {
    if (isListening) return;
    if (!await hasPermission()) {
      throw StateError('Microphone permission was not granted.');
    }

    final vosk = VoskFlutterPlugin.instance();
    _recognizer = await vosk.createRecognizer(model: model, sampleRate: sampleRate);

    final dir = await getApplicationDocumentsDirectory();
    final recordings = Directory('${dir.path}/voice_recordings');
    if (!await recordings.exists()) await recordings.create(recursive: true);
    final path = '${recordings.path}/voice_${DateTime.now().microsecondsSinceEpoch}.wav';
    _wavWriter = WavFileWriter(path: path, sampleRate: sampleRate);
    await _wavWriter!.open();

    // THE single microphone consumer for this entire session — replaces both the old
    // speech_to_text live-listen session AND the old separate `record.start()` file session.
    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );

    _micSubscription = stream.listen(_onAudioChunk);
  }

  /// Every chunk goes to BOTH consumers — this is the fan-out that replaces the old two-mic-
  /// session design. Neither consumer here opens any audio hardware; they only process bytes that
  /// [start] already captured, so there is no possible contention between them.
  Future<void> _onAudioChunk(Uint8List chunk) async {
    unawaited(_wavWriter?.write(chunk)); // consumer 1: save to disk

    final recognizer = _recognizer; // consumer 2: understand
    if (recognizer == null) return;
    final hasFinal = await recognizer.acceptWaveformBytes(chunk);
    if (hasFinal) {
      final text = _extractText(await recognizer.getResult(), key: 'text');
      if (text.isNotEmpty) _finalController.add(text);
    } else {
      final text = _extractText(await recognizer.getPartialResult(), key: 'partial');
      if (text.isNotEmpty) _partialController.add(text);
    }
  }

  /// Vosk returns JSON strings like `{"partial": "..."}` or `{"text": "..."}` — this pulls the
  /// plain string out, defensively (a malformed/empty JSON must never crash a live audio chunk
  /// handler; it just yields no text for that chunk).
  String _extractText(String json, {required String key}) {
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return (decoded[key] as String? ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  Future<void> pause() => _recorder.pause();
  Future<void> resume() => _recorder.resume();

  /// Stops the mic session, flushes the .wav file to a valid playable state, and asks the
  /// recognizer for whatever text is left — even if Vosk never emitted its own "final" result
  /// (e.g. the person tapped stop before a natural pause). Returns both the transcript and the
  /// saved recording's path.
  Future<(String transcript, String? recordingPath)> stop() async {
    await _micSubscription?.cancel();
    _micSubscription = null;
    await _recorder.stop();

    var lastText = '';
    final recognizer = _recognizer;
    if (recognizer != null) {
      lastText = _extractText(await recognizer.getFinalResult(), key: 'text');
      // NOTE: verify the exact disposal method name against the installed `vosk_flutter` version
      // after `flutter pub get` (docs confirm `SpeechService.dispose()`; `Recognizer` very likely
      // follows the same pattern to free its native handle, but double-check your resolved
      // version's API before relying on it in production).
      recognizer.dispose();
      _recognizer = null;
    }

    final path = _wavWriter?.path;
    await _wavWriter?.close();
    _wavWriter = null;

    return (lastText, path);
  }

  /// Aborts everything without keeping the file or the text — used when the person cancels
  /// mid-recording (matches the old VoiceController.cancel()'s `_recorder.cancel()` behavior).
  Future<void> cancel() async {
    await _micSubscription?.cancel();
    _micSubscription = null;
    await _recorder.stop();
    _recognizer?.dispose();
    _recognizer = null;
    final path = _wavWriter?.path;
    await _wavWriter?.close();
    _wavWriter = null;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  void dispose() {
    _micSubscription?.cancel();
    _recorder.dispose();
    _partialController.close();
    _finalController.close();
  }
}
