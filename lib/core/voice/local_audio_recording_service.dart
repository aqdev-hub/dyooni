import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Saves original voice-command audio beneath the app documents directory.
class LocalAudioRecordingService {
  LocalAudioRecordingService({AudioRecorder? recorder}) : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  Future<String?> start(String recordingId) async {
    if (!await _recorder.hasPermission()) return null;
    final directory = await getApplicationDocumentsDirectory();
    final recordings = Directory('${directory.path}${Platform.pathSeparator}voice_recordings');
    if (!await recordings.exists()) await recordings.create(recursive: true);
    final path = '${recordings.path}${Platform.pathSeparator}$recordingId.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    return path;
  }

  Future<String?> stop() => _recorder.stop();
  Future<void> cancel() => _recorder.cancel();
  Future<void> dispose() => _recorder.dispose();
}
