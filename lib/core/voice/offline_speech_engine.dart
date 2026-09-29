import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:vosk_flutter_service/vosk_flutter_service.dart';

import 'vosk_model_provider.dart' show voskSampleRate;
import 'speech_engine.dart';
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
class OfflineSpeechEngine implements SpeechEngine {
  OfflineSpeechEngine({required this.model, this.sampleRate = voskSampleRate});

  final Model model;
  final int sampleRate;

  final _recorder = AudioRecorder();
  Recognizer? _recognizer;
  WavFileWriter? _wavWriter;
  StreamSubscription<Uint8List>? _micSubscription;
  Future<void> _audioQueue = Future<void>.value();
  Future<void>? _stopping;
  final List<String> _finalSegments = <String>[];

  final _partialController = StreamController<String>.broadcast();
  final _finalController = StreamController<String>.broadcast();

  /// Live, not-yet-final text — updates continuously while the person is still talking. Fills the
  /// same UI role `speech_to_text`'s `onResult` with `finalResult: false` used to play.
  @override
  Stream<String> get partialResults => _partialController.stream;

  /// Fires once per finished utterance, whenever Vosk itself decides enough silence/certainty was
  /// reached. Fills the same role as `finalResult: true` in the old flow.
  @override
  Stream<String> get finalResults => _finalController.stream;

  @override
  bool get endsSessionOnFinal => false;

  bool get isListening => _micSubscription != null || _stopping != null;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Starts the single microphone session: creates a fresh recognizer bound to [model], opens the
  /// destination .wav file, then opens ONE raw audio stream and subscribes to it.
  @override
  Future<void> start() async {
    // A start requested immediately after stop (Bluetooth wake word and voice confirmation are
    // common examples) must wait for the native recorder and WAV writer to be fully released.
    // Otherwise AudioRecorder may still own the mic and silently ignore the new start.
    await _stopping;
    if (isListening) return;
    if (!await hasPermission()) {
      throw StateError('Microphone permission was not granted.');
    }

    final vosk = VoskFlutterPlugin.instance();
    _recognizer = await vosk.createRecognizer(model: model, sampleRate: sampleRate);
    _finalSegments.clear();

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

    // CRITICAL FIX for the reported "only catches the last word or two, never understands the
    // amount" bug: `_onAudioChunk` is an async function, but `Stream.listen()`'s callback
    // signature is `void Function(T)` — it does NOT wait for a returned Future. Every new audio
    // chunk was therefore starting its OWN overlapping call into the native Vosk recognizer
    // (`acceptWaveformBytes`/`getPartialResult`) before the previous chunk's call had finished,
    // racing dozens of times per second. Most chunks were being processed out of order or
    // effectively dropped by that race — the recognizer only ever ended up with fragments of
    // what was actually said, which is exactly the "only the last word or two" symptom.
    //
    // The fix: pause the subscription the instant a chunk arrives, fully await its processing,
    // THEN resume — guaranteeing every chunk is handed to the recognizer strictly one at a time,
    // in the order it was recorded, with no possible overlap.
    _micSubscription = stream.listen(_enqueueAudioChunk);
  }

  void _enqueueAudioChunk(Uint8List chunk) {
    // Stream.listen does not await an async callback. Keep an explicit FIFO instead: it keeps
    // native recognizer calls AND file writes ordered, and lets stop() drain every accepted
    // chunk before finalising the WAV header.
    _audioQueue = _audioQueue.then((_) => _onAudioChunk(chunk)).catchError((_) {});
  }

  /// Every chunk goes to BOTH consumers — this is the fan-out that replaces the old two-mic-
  /// session design. Neither consumer here opens any audio hardware; they only process bytes that
  /// [start] already captured, so there is no possible contention between them.
  Future<void> _onAudioChunk(Uint8List chunk) async {
    await _wavWriter?.write(chunk); // consumer 1: save to disk, in the same FIFO

    final recognizer = _recognizer; // consumer 2: understand
    if (recognizer == null) return;
    final hasFinal = await recognizer.acceptWaveformBytes(chunk);
    if (hasFinal) {
      final text = _extractText(await recognizer.getResult(), key: 'text');
      if (text.isNotEmpty) {
        _finalSegments.add(text);
        _finalController.add(_joinedTranscript());
      }
    } else {
      final text = _extractText(await recognizer.getPartialResult(), key: 'partial');
      if (text.isNotEmpty) _partialController.add(_joinedTranscript(partial: text));
    }
  }

  String _joinedTranscript({String partial = ''}) => [..._finalSegments, if (partial.isNotEmpty) partial].join(' ').trim();

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

  @override
  Future<void> pause() => _recorder.pause();
  @override
  Future<void> resume() => _recorder.resume();

  /// Stops the mic session, flushes the .wav file to a valid playable state, and asks the
  /// recognizer for whatever text is left — even if Vosk never emitted its own "final" result
  /// (e.g. the person tapped stop before a natural pause). Returns both the transcript and the
  /// saved recording's path.
  @override
  Future<(String transcript, String? recordingPath)> stop() async {
    final activeStop = _stopping;
    if (activeStop != null) {
      await activeStop;
      return ('', null);
    }
    String transcript = '';
    String? path;
    _stopping = () async {
      await _micSubscription?.cancel();
      _micSubscription = null;
      await _audioQueue;
      await _recorder.stop();

      final recognizer = _recognizer;
      if (recognizer != null) {
        final lastText = _extractText(await recognizer.getFinalResult(), key: 'text');
        if (lastText.isNotEmpty) _finalSegments.add(lastText);
        transcript = _joinedTranscript();
        await recognizer.dispose();
        _recognizer = null;
      }

      path = _wavWriter?.path;
      await _wavWriter?.close();
      _wavWriter = null;
    }();
    try {
      await _stopping;
    } finally {
      _stopping = null;
    }

    return (transcript, path);
  }

  /// Aborts everything without keeping the file or the text — used when the person cancels
  /// mid-recording (matches the old VoiceController.cancel()'s `_recorder.cancel()` behavior).
  @override
  Future<void> cancel() async {
    final activeStop = _stopping;
    if (activeStop != null) {
      await activeStop;
      return;
    }
    await _micSubscription?.cancel();
    _micSubscription = null;
    await _audioQueue;
    await _recorder.stop();
    if (_recognizer != null) {
      await _recognizer!.dispose();
    }
    _recognizer = null;
    final path = _wavWriter?.path;
    await _wavWriter?.close();
    _wavWriter = null;
    _finalSegments.clear();
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  @override
  void dispose() {
    _micSubscription?.cancel();
    _recorder.dispose();
    _partialController.close();
    _finalController.close();
  }
}
