import 'dart:math' as math;
import 'dart:typed_data';

/// A deliberately small, dependency-free speech/silence detector over raw PCM16 mono audio.
///
/// Why it exists: Whisper cannot stream text, so the app has to decide on its own when the person
/// finished talking. This class only answers "is someone speaking RIGHT NOW?" so the voice
/// controller can restart its end-of-speech timer while they are, and fire it two seconds after
/// they stop (see VoiceController._armSpeechEndTimer).
///
/// It is NOT used to decide whether a recording contains speech worth transcribing — a wrong "no"
/// there would silently throw away a real command. That decision uses only the very conservative
/// [peakRms] floor in the engine, and the real hallucination defence is Whisper's own Silero VAD
/// plus TranscriptCleaner. If this detector is wrong the worst case is a delay (the controller's
/// own 8 second timer still ends the recording), never a lost command.
///
/// Adaptive: the noise floor follows the background level, so a noisy room does not read as
/// continuous speech and a quiet room does not need a loud voice.
class EnergyVad {
  EnergyVad({this.sampleRate = 16000});

  final int sampleRate;

  static const _frameMs = 20;

  /// Speech must be this loud relative to the background (3.5x) and above an absolute minimum, so
  /// a near-silent room does not turn its own hiss into "speech".
  static const _floorRatio = 3.5;
  static const _minThreshold = 0.010;
  static const _maxThreshold = 0.030;

  /// 10 voiced frames in a row (200 ms) before speech is considered started: a cough or a tap on
  /// the phone is shorter than that.
  static const _startFrames = 10;

  /// After the last voiced frame the detector stays "active" for 300 ms, bridging the natural
  /// dips between syllables so a sentence is not reported as many separate bursts.
  static const _hangoverFrames = 15;

  int get _frameBytes => sampleRate * _frameMs ~/ 1000 * 2;

  double _floor = -1;
  int _run = 0;
  int _hangover = 0;
  bool _speechStarted = false;
  final BytesBuilder _carry = BytesBuilder(copy: false);

  /// Loudest 20 ms frame seen so far (RMS, 0..1). Used by the engine as the "was the microphone
  /// effectively silent the whole time" check.
  double peakRms = 0;

  /// Total frames analysed, for the duration of audio seen.
  int frames = 0;

  /// `true` once at least [_startFrames] consecutive voiced frames were heard.
  bool get speechStarted => _speechStarted;

  int get durationMs => frames * _frameMs;

  /// Feeds a chunk of PCM16 little-endian mono bytes. Returns `true` when speech is active at the
  /// end of this chunk (started, and a voiced frame was heard within the hangover window).
  bool addChunk(Uint8List bytes) {
    Uint8List data = bytes;
    if (_carry.length > 0) {
      _carry.add(bytes);
      data = _carry.takeBytes();
    }
    final frameBytes = _frameBytes;
    var offset = 0;
    while (offset + frameBytes <= data.length) {
      _processFrame(data, offset, frameBytes);
      offset += frameBytes;
    }
    if (offset < data.length) {
      // Copied: the recorder may reuse the buffer it handed us.
      _carry.add(Uint8List.fromList(Uint8List.sublistView(data, offset)));
    }
    return _speechStarted && _hangover > 0;
  }

  void _processFrame(Uint8List data, int offset, int length) {
    final view = ByteData.sublistView(data, offset, offset + length);
    final samples = length ~/ 2;
    var sumSquares = 0.0;
    for (var i = 0; i < samples; i++) {
      final s = view.getInt16(i * 2, Endian.little) / 32768.0;
      sumSquares += s * s;
    }
    final rms = math.sqrt(sumSquares / samples);
    frames++;
    if (rms > peakRms) peakRms = rms;

    if (_floor < 0) _floor = rms;
    final threshold = (_floor * _floorRatio).clamp(_minThreshold, _maxThreshold).toDouble();
    final voiced = rms > threshold;
    if (voiced) {
      _run++;
      _hangover = _hangoverFrames;
      if (_run >= _startFrames) _speechStarted = true;
    } else {
      _run = 0;
      if (_hangover > 0) _hangover--;
      // The floor only learns from non-speech frames, slowly, and is capped so one loud moment
      // cannot make the detector deaf for the rest of the session.
      _floor = (_floor * 0.97 + rms * 0.03).clamp(0.0003, 0.02).toDouble();
    }
  }

  void reset() {
    _floor = -1;
    _run = 0;
    _hangover = 0;
    _speechStarted = false;
    _carry.clear();
    peakRms = 0;
    frames = 0;
  }
}
