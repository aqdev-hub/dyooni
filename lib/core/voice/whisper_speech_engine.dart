import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_ggml/whisper_ggml.dart' show TranscribeRequest, Whisper, WhisperModel;

import 'energy_vad.dart';
import 'fast_conformer_decoder.dart';
import 'speech_engine.dart';
import 'wav_file_writer.dart';
import 'whisper_model_provider.dart';

/// Biases Whisper toward the vocabulary of this app: spelled-out Arabic amounts, currency, the
/// debt direction words and the confirmation words. Whisper imitates the STYLE of its prompt, so
/// numbers are written as words here — that is the form the number parser was built and tested
/// for. Deliberately generic ("فلان", no real names) so it cannot pull an unrelated name toward a
/// name that only appears in the prompt.
const whisperInitialPrompt = 'دين لفلان عليه خمسة آلاف ريال. سدد ثلاثة آلاف وخمسمائة ريال. نعم، حفظ، تعديل، إلغاء.';

/// Local speech recognition with Whisper (whisper.cpp through the `whisper_ggml` package).
///
/// HOW IT DIFFERS FROM THE VOSK ENGINE — read this before changing it:
///  * Vosk streams: it returns text WHILE the person talks. Whisper cannot; it needs the whole
///    recording and decodes it afterwards. So this engine records first and transcribes inside
///    [stop] (the controller shows its "processing" state meanwhile).
///  * Because there is no live text, the controller cannot use the arrival of words to learn that
///    the person is still talking. [speechActivity] replaces that signal (see [EnergyVad]).
///  * The microphone ownership is unchanged and is the whole point of the earlier fix: ONE
///    `record` stream owns the mic; the bytes go to the WAV file and to the activity detector.
///    Nothing else ever touches the microphone, so no second consumer can starve.
///  * The WAV that Whisper reads is the very same file attached to the saved entry, so what the
///    person can replay later is exactly what was recognised.
class WhisperSpeechEngine implements SpeechEngine {
  WhisperSpeechEngine({
    required this.modelFiles,
    required this.cleanTranscript,
    this.sampleRate = whisperSampleRate,
  });

  /// Looked up at the moment recording starts/ends, NOT at construction: constructing this engine
  /// must never depend on the model being downloaded (the old Vosk provider cast the model state
  /// at construction and crashed when the person switched to local mode before it was ready).
  final WhisperModelFiles? Function() modelFiles;

  /// Post-processing of Whisper's raw text (punctuation, hallucinations, prompt echo). Injected so
  /// this file does not depend on the logic layer.
  final String Function(String raw) cleanTranscript;

  final int sampleRate;

  /// Threads for decoding. whisper.cpp's own default is min(4, cores); 6 (this package's default)
  /// tends to be SLOWER on phones whose slow cores then hold back the fast ones.
  static const _threads = 4;

  /// A decode that has not finished by then is abandoned and reported as a failure rather than
  /// leaving the screen on "processing" indefinitely.
  static const _decodeTimeout = Duration(seconds: 90);

  /// Recordings shorter than this, or whose loudest 20 ms never exceeds [_silentPeakRms], are not
  /// sent to Whisper at all. The loudness floor is intentionally far below real speech: it only
  /// catches a truly dead microphone, where Whisper would otherwise invent a sentence.
  static const _minAudioMs = 400;
  static const _silentPeakRms = 0.003;

  AudioRecorder? _recorder;
  WavFileWriter? _wavWriter;
  StreamSubscription<Uint8List>? _micSubscription;
  Future<void> _audioQueue = Future<void>.value();
  Future<void>? _stopping;
  final EnergyVad _vad = EnergyVad();
  final FastConformerDecoder _fast = FastConformerDecoder();

  final _partialController = StreamController<String>.broadcast();
  final _finalController = StreamController<String>.broadcast();
  final _errorController = StreamController<SpeechEngineError>.broadcast();
  final _activityController = StreamController<void>.broadcast();

  @override
  Stream<String> get partialResults => _partialController.stream;

  @override
  Stream<String> get finalResults => _finalController.stream;

  @override
  Stream<SpeechEngineError> get errors => _errorController.stream;

  @override
  Stream<void> get speechActivity => _activityController.stream;

  @override
  bool get providesLiveText => false;

  /// Whisper greedy decoding yields one hypothesis; there is nothing to rank.
  @override
  List<String> get lastAlternatives => const [];

  /// `false`: the recording continues until the controller (end-of-speech timer or the person's
  /// tap) calls [stop].
  @override
  bool get endsSessionOnFinal => false;

  bool get isListening => _micSubscription != null || _stopping != null;

  @override
  Future<bool> hasPermission() async {
    final probe = AudioRecorder();
    try {
      return await probe.hasPermission();
    } finally {
      await probe.dispose();
    }
  }

  @override
  Future<void> start() async {
    await _stopping;
    if (isListening) return;
    if (modelFiles() == null) {
      throw StateError('The Whisper model is not ready yet.');
    }
    if (!await hasPermission()) {
      _errorController.add(const SpeechEngineError(SpeechEngineErrorType.permission));
      throw StateError('Microphone permission was not granted.');
    }

    // The sherpa model takes seconds to load; start loading while the person is still speaking.
    final files = modelFiles();
    if (files != null && files.option.engine == VoiceModelEngine.sherpa && files.tokensPath != null) {
      unawaited(_fast.ensureLoaded(modelPath: files.modelPath, tokensPath: files.tokensPath!).catchError((Object e) {
        debugPrint('[voice] fastconformer preload failed: $e');
      }));
    }

    final dir = await getApplicationDocumentsDirectory();
    final recordings = Directory('${dir.path}/voice_recordings');
    if (!await recordings.exists()) await recordings.create(recursive: true);
    final path = '${recordings.path}/voice_${DateTime.now().microsecondsSinceEpoch}.wav';
    _wavWriter = WavFileWriter(path: path, sampleRate: sampleRate);
    await _wavWriter!.open();
    _vad.reset();

    final recorder = _recorder = AudioRecorder();
    final Stream<Uint8List> stream;
    try {
      stream = await recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
          // Raw audio, as in the Vosk engine: the platform's call-oriented echo cancellation and
          // noise suppression smear short quiet syllables — exactly the number words.
          echoCancel: false,
          noiseSuppress: false,
        ),
      );
    } catch (_) {
      await cancel();
      rethrow;
    }
    _micSubscription = stream.listen(_onChunk);
  }

  void _onChunk(Uint8List chunk) {
    // Detection is cheap and synchronous; the file write goes through the FIFO so bytes land on
    // disk strictly in recording order and stop() can drain them before closing the header.
    final speaking = _vad.addChunk(chunk);
    if (speaking && !_activityController.isClosed) _activityController.add(null);
    _audioQueue = _audioQueue.then((_) => _writeChunk(chunk)).catchError((_) {});
  }

  Future<void> _writeChunk(Uint8List chunk) async {
    await _wavWriter?.write(chunk);
  }

  Future<void> _releaseRecorder() async {
    final recorder = _recorder;
    _recorder = null;
    if (recorder == null) return;
    try {
      await recorder.stop();
    } catch (_) {
      // Already stopped — the dispose below is what matters.
    }
    try {
      await recorder.dispose();
    } catch (_) {
      // Best effort.
    }
  }

  @override
  Future<void> pause() async {
    await _recorder?.pause();
  }

  @override
  Future<void> resume() async {
    await _recorder?.resume();
  }

  /// Stops recording, closes the WAV and decodes it. Throws [SpeechEngineException] when decoding
  /// itself failed (model damaged, out of memory, timeout) — never returns an empty transcript for
  /// a failure, because the dialogue would then tell the person "I heard nothing", which is a
  /// wrong diagnosis. A truly silent or too-short recording returns an empty transcript.
  @override
  Future<(String transcript, String? recordingPath)> stop() async {
    final activeStop = _stopping;
    if (activeStop != null) {
      await activeStop;
      return ('', null);
    }
    var transcript = '';
    String? path;
    Object? failure;
    _stopping = () async {
      await _micSubscription?.cancel();
      _micSubscription = null;
      await _audioQueue;
      await _releaseRecorder();

      path = _wavWriter?.path;
      await _wavWriter?.close();
      _wavWriter = null;

      final audioMs = _vad.durationMs;
      final peak = _vad.peakRms;
      final recorded = path;
      if (recorded == null || audioMs < _minAudioMs || peak < _silentPeakRms) {
        debugPrint('[voice] whisper skipped: audio=${audioMs}ms peakRms=${peak.toStringAsFixed(4)}');
        return;
      }
      try {
        transcript = await _transcribe(recorded, audioMs);
      } catch (e) {
        debugPrint('[voice] whisper failed: $e');
        failure = e;
      }
    }();
    try {
      await _stopping;
    } finally {
      _stopping = null;
    }

    final error = failure;
    if (error != null) {
      await _deleteFile(path);
      throw SpeechEngineException('recognition', error.toString());
    }
    return (transcript, path);
  }

  Future<String> _transcribe(String audioPath, int audioMs) async {
    final files = modelFiles();
    if (files == null) throw StateError('The Whisper model is not ready.');

    final started = DateTime.now();
    String raw;
    if (files.option.engine == VoiceModelEngine.sherpa) {
      raw = await _decodeSherpa(audioPath, files).timeout(_decodeTimeout);
      final text = cleanTranscript(raw);
      debugPrint(
        '[voice] fastconformer: audio=${audioMs}ms decode=${DateTime.now().difference(started).inMilliseconds}ms '
        'raw=${raw.trim().length} chars kept=${text.length} chars peakRms=${_vad.peakRms.toStringAsFixed(3)} '
        'speechDetected=${_vad.speechStarted}',
      );
      return text;
    }
    try {
      raw = await _decode(audioPath, files, useVad: files.vadPath != null).timeout(_decodeTimeout);
    } on TimeoutException {
      rethrow;
    } catch (e) {
      if (files.vadPath == null) rethrow;
      // A damaged/missing VAD file must not cost the person their recognition: retry once without.
      debugPrint('[voice] whisper decode with VAD failed ($e) — retrying without VAD');
      raw = await _decode(audioPath, files, useVad: false).timeout(_decodeTimeout);
    }
    final text = cleanTranscript(raw);
    final decodeMs = DateTime.now().difference(started).inMilliseconds;
    // Timing and sizes only — never the words. This is how decode speed per model is judged.
    debugPrint(
      '[voice] whisper ${files.option.id}: audio=${audioMs}ms decode=${decodeMs}ms raw=${raw.trim().length} chars '
      'kept=${text.length} chars peakRms=${_vad.peakRms.toStringAsFixed(3)} speechDetected=${_vad.speechStarted}',
    );
    return text;
  }

  /// Reads the recording we wrote ourselves (44-byte header + 16-bit mono PCM) into float samples
  /// and decodes it with FastConformer. No conversion step and no temporary copy is needed.
  Future<String> _decodeSherpa(String audioPath, WhisperModelFiles files) async {
    final tokens = files.tokensPath;
    if (tokens == null) throw StateError('The FastConformer vocabulary file is missing.');
    await _fast.ensureLoaded(modelPath: files.modelPath, tokensPath: tokens);
    final bytes = await File(audioPath).readAsBytes();
    const headerBytes = 44;
    if (bytes.length <= headerBytes) return '';
    final data = ByteData.sublistView(bytes);
    final count = (bytes.length - headerBytes) ~/ 2;
    final samples = Float32List(count);
    for (var i = 0; i < count; i++) {
      samples[i] = data.getInt16(headerBytes + i * 2, Endian.little) / 32768.0;
    }
    return _fast.decode(samples, sampleRate: sampleRate);
  }

  Future<String> _decode(String audioPath, WhisperModelFiles files, {required bool useVad}) async {
    // `model` is required by the constructor but unused: the file path is passed explicitly, which
    // is what lets us run the quantised files the package's own enum does not list.
    const whisper = Whisper(model: WhisperModel.small);
    try {
      final response = await whisper.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: audioPath,
          language: 'ar',
          threads: _threads,
          isNoTimestamps: true,
          initialPrompt: whisperInitialPrompt,
          // Left OFF on purpose: forcing non-speech tokens away can make real noise decode as
          // ordinary words. Bracketed annotations are removed by the transcript cleaner instead.
          suppressNonSpeechTokens: false,
          // Keeps the model in memory between recognitions (a confirmation answer follows every
          // command); freed by [release]/[dispose].
          keepModelLoaded: true,
          vadModelPath: useVad ? files.vadPath : null,
          vadSpeechPadMs: useVad ? 150 : null,
        ),
        modelPath: files.modelPath,
      );
      return response.text;
    } finally {
      // The package converts the input into "<file>.wav" next to it before decoding; that copy is
      // a temporary and must never pile up in the recordings folder.
      await _deleteFile('$audioPath.wav');
    }
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best effort.
    }
  }

  /// Aborts everything without keeping the file or any text (the person cancelled mid-recording).
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
    await _releaseRecorder();
    final path = _wavWriter?.path;
    await _wavWriter?.close();
    _wavWriter = null;
    _vad.reset();
    await _deleteFile(path);
  }

  /// Frees the microphone AND the model parked in native memory, so the other engine can use the
  /// hardware and the app is not holding hundreds of megabytes it is not using.
  @override
  Future<void> release() async {
    await cancel();
    await _fast.dispose();
    try {
      await const Whisper(model: WhisperModel.small).releaseModel();
    } catch (_) {
      // Nothing parked, or the native library was never loaded — fine.
    }
  }

  @override
  void dispose() {
    unawaited(release());
    _partialController.close();
    _finalController.close();
    _errorController.close();
    _activityController.close();
  }
}
