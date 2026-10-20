import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Sample rate Whisper expects and the recorder captures at. Whisper is trained on 16 kHz mono.
const whisperSampleRate = 16000;

/// The two Whisper models offered for local recognition. Both are `ggml` files published by the
/// whisper.cpp project on Hugging Face and are downloaded ONCE, then run fully offline.
///
/// Both are quantised (q5): roughly a third of the original size with a small accuracy cost, which
/// is what makes them practical on a phone.
///  * [balanced] — `small`, q5_1 (~190 MB): the faster one and the default.
///  * [accurate] — `medium`, q5_0 (~540 MB): clearly better on Arabic, but each recognition takes
///    noticeably longer. Whether that is acceptable depends on the phone, so it is the person's
///    choice, not ours.
enum WhisperModelOption {
  balanced('balanced', 'ggml-small-q5_1.bin', 190),
  accurate('accurate', 'ggml-medium-q5_0.bin', 540);

  const WhisperModelOption(this.id, this.fileName, this.approxMegabytes);

  final String id;
  final String fileName;
  final int approxMegabytes;

  Uri get url => Uri.parse('https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$fileName');

  static WhisperModelOption? fromId(String? id) {
    for (final option in values) {
      if (option.id == id) return option;
    }
    return null;
  }
}

/// whisper.cpp's own voice-activity model (~0.9 MB). Optional: it trims silence before decoding,
/// which is the standard defence against Whisper inventing text on quiet audio. If it cannot be
/// downloaded the engine simply runs without it.
const _vadFileName = 'ggml-silero-v5.1.2.bin';
final _vadUrl = Uri.parse('https://huggingface.co/ggml-org/whisper-vad/resolve/main/$_vadFileName');
const _vadMinBytes = 100 * 1024;

/// The model files ready for the engine.
class WhisperModelFiles {
  const WhisperModelFiles({required this.option, required this.modelPath, this.vadPath});
  final WhisperModelOption option;
  final String modelPath;
  final String? vadPath;
}

/// One state per stage of getting a model ready (sealed, so an invalid combination such as
/// "downloading and ready at once" cannot be represented — same principle as the old Vosk gate).
sealed class WhisperModelState {
  const WhisperModelState();
}

/// Looking at what is already on disk.
class WhisperModelChecking extends WhisperModelState {
  const WhisperModelChecking();
}

/// Nothing is installed: the person must pick a model before anything is downloaded (the files are
/// large, so we never start a 190–540 MB download without asking).
class WhisperModelNeedsChoice extends WhisperModelState {
  const WhisperModelNeedsChoice();
}

class WhisperModelDownloading extends WhisperModelState {
  const WhisperModelDownloading({required this.option, required this.downloadedBytes, required this.totalBytes});
  final WhisperModelOption option;
  final int downloadedBytes;
  final int? totalBytes;
}

class WhisperModelReady extends WhisperModelState {
  const WhisperModelReady(this.files);
  final WhisperModelFiles files;
}

class WhisperModelFailed extends WhisperModelState {
  const WhisperModelFailed(this.message, {this.option});
  final String message;
  final WhisperModelOption? option;
}

final whisperModelControllerProvider = NotifierProvider<WhisperModelController, WhisperModelState>(
  WhisperModelController.new,
);

/// Owns the model lifecycle: look on disk → (ask) → download with resume → verify → ready.
///
/// Every step first checks whether its own output already exists and skips past it, so retrying
/// after a failure RESUMES instead of restarting. Network hiccups are absorbed with automatic
/// retries; the person only sees a failure after sustained trouble.
class WhisperModelController extends Notifier<WhisperModelState> {
  static const _maxAutoRetries = 6;
  static const _connectTimeout = Duration(seconds: 20);
  static const _stallTimeout = Duration(seconds: 30);

  /// First four bytes of every ggml model: the magic number 0x67676d6c ("ggml") little-endian.
  static const _ggmlMagic = <int>[0x6c, 0x6d, 0x67, 0x67];
  static const _minModelBytes = 20 * 1024 * 1024;

  Future<void>? _active;
  WhisperModelOption? _target;

  @override
  WhisperModelState build() {
    Future.microtask(_init);
    return const WhisperModelChecking();
  }

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/whisper');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _fileFor(WhisperModelOption option) async => File('${(await _dir()).path}/${option.fileName}');
  Future<File> _choiceFile() async => File('${(await _dir()).path}/choice.txt');

  Future<void> _init() async {
    if (_active != null) return;
    try {
      final installed = <WhisperModelOption>[
        for (final option in WhisperModelOption.values)
          if (await _isInstalled(option)) option,
      ];
      if (installed.isEmpty) {
        state = const WhisperModelNeedsChoice();
        return;
      }
      final chosen = await _readChoice();
      await _becomeReady(installed.contains(chosen) ? chosen! : installed.first);
    } catch (e) {
      state = WhisperModelFailed(e.toString());
    }
  }

  /// The person picked a model (first run) — download it, then become ready.
  Future<void> choose(WhisperModelOption option) {
    _target = option;
    return _active ??= _install(option).whenComplete(() => _active = null);
  }

  /// Switch to another model (installed already → instant; otherwise it is downloaded).
  Future<void> switchTo(WhisperModelOption option) => choose(option);

  /// Resumes whatever failed; if nothing specific failed, re-checks the disk.
  Future<void> retry() {
    final option = switch (state) {
      WhisperModelFailed(option: final failed) => failed ?? _target,
      _ => _target,
    };
    if (option != null) return choose(option);
    return _init();
  }

  Future<void> _install(WhisperModelOption option) async {
    try {
      if (!await _isInstalled(option)) {
        await _downloadWithRetries(
          url: option.url,
          dest: await _fileFor(option),
          minBytes: _minModelBytes,
          checkMagic: true,
          onProgress: (received, total) => _publishProgress(option, received, total),
        );
      }
      await _becomeReady(option);
    } catch (e) {
      state = WhisperModelFailed(e.toString(), option: option);
    }
  }

  Future<void> _becomeReady(WhisperModelOption option) async {
    final file = await _fileFor(option);
    final choice = await _choiceFile();
    await choice.writeAsString(option.id);
    final vadPath = await _ensureVad();
    state = WhisperModelReady(WhisperModelFiles(option: option, modelPath: file.path, vadPath: vadPath));
  }

  Future<WhisperModelOption?> _readChoice() async {
    final file = await _choiceFile();
    if (!await file.exists()) return null;
    return WhisperModelOption.fromId((await file.readAsString()).trim());
  }

  /// A file is "installed" only when it exists, is big enough AND starts with the ggml magic. A
  /// download is renamed into place only after the same checks, so this mostly guards against a
  /// file damaged afterwards (storage cleanup, interrupted copy). A damaged file is deleted so the
  /// normal download path replaces it.
  Future<bool> _isInstalled(WhisperModelOption option) async {
    final file = await _fileFor(option);
    if (!await file.exists()) return false;
    if (await file.length() >= _minModelBytes && await _hasGgmlMagic(file)) return true;
    await file.delete();
    return false;
  }

  Future<bool> _hasGgmlMagic(File file) async {
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final head = await raf.read(4);
      if (head.length < 4) return false;
      for (var i = 0; i < 4; i++) {
        if (head[i] != _ggmlMagic[i]) return false;
      }
      return true;
    } finally {
      await raf?.close();
    }
  }

  /// Best effort: never blocks or fails the model becoming ready.
  Future<String?> _ensureVad() async {
    final file = File('${(await _dir()).path}/$_vadFileName');
    try {
      if (await file.exists() && await file.length() >= _vadMinBytes) return file.path;
      await _downloadWithRetries(
        url: _vadUrl,
        dest: file,
        minBytes: _vadMinBytes,
        checkMagic: false,
        onProgress: (_, __) {},
        maxRetries: 3,
      );
      return file.path;
    } catch (_) {
      return null;
    }
  }

  DateTime _lastPublish = DateTime.fromMillisecondsSinceEpoch(0);

  /// Progress callbacks arrive for every network chunk; rebuilding the UI that often is wasteful, so
  /// they are throttled (the first and last updates always pass).
  void _publishProgress(WhisperModelOption option, int received, int? total) {
    final now = DateTime.now();
    final done = total != null && received >= total;
    if (!done && now.difference(_lastPublish) < const Duration(milliseconds: 200)) return;
    _lastPublish = now;
    state = WhisperModelDownloading(option: option, downloadedBytes: received, totalBytes: total);
  }

  Future<void> _downloadWithRetries({
    required Uri url,
    required File dest,
    required int minBytes,
    required bool checkMagic,
    required void Function(int received, int? total) onProgress,
    int maxRetries = _maxAutoRetries,
  }) async {
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await _downloadOnce(url: url, dest: dest, minBytes: minBytes, checkMagic: checkMagic, onProgress: onProgress);
        return;
      } catch (_) {
        if (attempt == maxRetries) rethrow;
        await Future<void>.delayed(Duration(seconds: (attempt * 2).clamp(2, 15)));
      }
    }
  }

  Future<int?> _readSize(File meta) async {
    if (!await meta.exists()) return null;
    return int.tryParse((await meta.readAsString()).trim());
  }

  /// One download attempt. Resumes from the `.part` file with an HTTP Range request. Connecting is
  /// bounded (20 s) and so is silence mid-transfer (30 s), so a stalled network becomes a retryable
  /// error within seconds instead of an endless spinner.
  Future<void> _downloadOnce({
    required Uri url,
    required File dest,
    required int minBytes,
    required bool checkMagic,
    required void Function(int received, int? total) onProgress,
  }) async {
    final part = File('${dest.path}.part');
    final meta = File('${dest.path}.size');
    final already = await part.exists() ? await part.length() : 0;
    onProgress(already, await _readSize(meta));

    final client = http.Client();
    try {
      final request = http.Request('GET', url);
      if (already > 0) request.headers[HttpHeaders.rangeHeader] = 'bytes=$already-';
      final response = await client.send(request).timeout(_connectTimeout);

      if (response.statusCode == 416) {
        // The partial file does not fit the server's file (changed or damaged) — start over.
        await part.delete();
        throw HttpException('Server rejected the resume range for ${dest.uri.pathSegments.last}');
      }
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException('Unexpected status ${response.statusCode} downloading ${dest.uri.pathSegments.last}');
      }
      final resumed = response.statusCode == 206;
      final startOffset = resumed ? already : 0;
      if (!resumed && already > 0) await part.delete();

      final reported = response.contentLength;
      final total = reported == null ? null : reported + startOffset;
      if (total != null) await meta.writeAsString(total.toString());

      final sink = part.openWrite(mode: startOffset > 0 ? FileMode.append : FileMode.write);
      var received = startOffset;
      try {
        final timed = response.stream.timeout(
          _stallTimeout,
          onTimeout: (s) => s.addError(TimeoutException('Download stalled — no data for 30s')),
        );
        await for (final chunk in timed) {
          sink.add(chunk);
          received += chunk.length;
          onProgress(received, total);
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
    } finally {
      client.close();
    }

    final expected = await _readSize(meta);
    final actual = await part.length();
    if (expected != null && actual < expected) {
      // Connection closed early — keep the bytes; the retry resumes from here.
      throw HttpException('Download ended early ($actual of $expected bytes)');
    }
    if ((expected != null && actual > expected) || actual < minBytes || (checkMagic && !await _hasGgmlMagic(part))) {
      await part.delete();
      if (await meta.exists()) await meta.delete();
      throw HttpException('Downloaded file is not a valid model ($actual bytes)');
    }
    await part.rename(dest.path);
    if (await meta.exists()) await meta.delete();
  }
}
