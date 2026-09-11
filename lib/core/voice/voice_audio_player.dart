import 'dart:io';

import 'package:just_audio/just_audio.dart';

class VoiceAudioPlayer {
  VoiceAudioPlayer({AudioPlayer? player}) : _player = player ?? AudioPlayer();
  final AudioPlayer _player;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  Future<void> toggle(String path) async {
    if (!await File(path).exists()) throw StateError('Voice recording file is unavailable');
    if (_player.playing) {
      await _player.pause();
      return;
    }
    await _player.setFilePath(path);
    await _player.play();
  }

  Future<void> dispose() => _player.dispose();
}
