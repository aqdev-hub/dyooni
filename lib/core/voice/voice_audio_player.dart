import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';

class VoiceAudioPlayer {
  VoiceAudioPlayer({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    // just_audio keeps `playing == true` after a track ends (only the processing state becomes
    // "completed"), so a play button driven by it stayed on "pause" forever. When playback
    // completes, stop for real and rewind: the button returns to "play" and the next press starts
    // from the beginning.
    _completionSubscription = _player.processingStateStream.listen((state) async {
      if (state != ProcessingState.completed) return;
      await _player.pause();
      await _player.seek(Duration.zero);
    });
  }

  final AudioPlayer _player;
  StreamSubscription<ProcessingState>? _completionSubscription;

  /// `true` only while sound is actually being played — `false` once the recording has ended.
  Stream<bool> get isPlayingStream =>
      _player.playerStateStream.map((s) => s.playing && s.processingState != ProcessingState.completed).distinct();

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  Future<void> toggle(String path) async {
    if (!await File(path).exists()) throw StateError('Voice recording file is unavailable');
    if (_player.playing) {
      await _player.pause();
      return;
    }
    // Load only when this is a different file or nothing is loaded yet: pressing play after a
    // pause then RESUMES instead of starting over.
    if (_loadedPath != path) {
      await _player.setFilePath(path);
      _loadedPath = path;
    }
    await _player.play();
  }

  String? _loadedPath;

  Future<void> dispose() async {
    await _completionSubscription?.cancel();
    await _player.dispose();
  }
}
