import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Saves original voice-command audio beneath the app documents directory.
class LocalAudioRecordingService {
  LocalAudioRecordingService({AudioRecorder? recorder}) : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  /// Checks microphone permission WITHOUT starting a recording — used purely for diagnostics
  /// (see VoiceController's noSpeech clarification) so we can tell the user definitively whether
  /// the OS has granted RECORD_AUDIO at all, independent of whether recording is currently
  /// enabled (see [start]'s temporary-disable note).
  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<String?> start(String recordingId) async {
    if (!await _recorder.hasPermission()) return null;
    final directory = await getApplicationDocumentsDirectory();
    final recordings = Directory('${directory.path}${Platform.pathSeparator}voice_recordings');
    if (!await recordings.exists()) await recordings.create(recursive: true);
    final path = '${recordings.path}${Platform.pathSeparator}$recordingId.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    return path;
  }

  /// Pauses the underlying recorder in place — the SAME file keeps being written to on
  /// [resume], so a paused-then-resumed recording stays ONE continuous audio file rather than
  /// producing two separate clips that would need stitching together.
  Future<void> pause() => _recorder.pause();

  Future<void> resume() => _recorder.resume();

  Future<String?> stop() => _recorder.stop();
  Future<void> cancel() => _recorder.cancel();
  Future<void> dispose() => _recorder.dispose();
}
