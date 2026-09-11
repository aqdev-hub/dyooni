import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:vosk_flutter_service/vosk_flutter_service.dart';

/// Alpha Cephei's own hosted Arabic model (MGB-2, ~318MB) — the smallest general-purpose
/// (non-dialect-restricted) Arabic model Vosk currently publishes.
const voskArabicModelUrl = 'https://alphacephei.com/vosk/models/vosk-model-ar-mgb2-0.4.zip';

/// Must match the sample rate the recorder captures at (see OfflineSpeechEngine) — Vosk decodes
/// assuming a fixed rate; mismatching the two silently produces garbled/empty recognition with no
/// error, which would look identical to the original "no speech detected" bug from the outside.
const voskSampleRate = 16000;

/// One state per stage of getting the model ready. Deliberately a sealed hierarchy (not a single
/// class with nullable fields) — see core/utils/result.dart for the same "unrepresentable invalid
/// states" principle applied elsewhere in this project.
sealed class VoskModelState {
  const VoskModelState();
}

class VoskModelIdle extends VoskModelState {
  const VoskModelIdle();
}

/// Actively downloading. [totalBytes] is `null` only until the very first response header
/// arrives (or if the server genuinely never reports a size) — the UI falls back to a byte
/// counter without a percentage in that case.
class VoskModelDownloading extends VoskModelState {
  const VoskModelDownloading({required this.downloadedBytes, required this.totalBytes});
  final int downloadedBytes;
  final int? totalBytes;
}

/// The .zip finished downloading and is now being unpacked on a background isolate — a distinct
/// state from downloading so the UI can show "جاري التجهيز" instead of a stalled-looking 100%.
class VoskModelExtracting extends VoskModelState {
  const VoskModelExtracting();
}

class VoskModelReady extends VoskModelState {
  const VoskModelReady(this.model);
  final Model model;
}

class VoskModelFailed extends VoskModelState {
  const VoskModelFailed(this.message);
  final String message;
}

final voskPluginProvider = Provider<VoskFlutterPlugin>((ref) => VoskFlutterPlugin.instance());

/// Owns the full lifecycle: check-for-existing-model → resume-or-start download → extract →
/// build [Model]. Every network hiccup is retried automatically and silently (see
/// [_downloadWithRetries]) — the person only ever sees a failure screen if the connection is
/// genuinely unavailable for an extended, sustained period, not for a single dropped packet.
final voskModelControllerProvider = NotifierProvider<VoskModelController, VoskModelState>(
  VoskModelController.new,
);

class VoskModelController extends Notifier<VoskModelState> {
  static const _readyMarkerFileName = '.ready';

  /// How many consecutive network failures to absorb silently (with the download resuming from
  /// wherever it got to each time) before finally surfacing a failure screen with a manual retry
  /// button. Six attempts with a growing back-off comfortably rides out normal Wi-Fi/cellular
  /// blips without ever bothering the person — this is what fixes the reported
  /// "starts, drops, starts, drops" pattern on an otherwise-healthy connection.
  static const _maxAutoRetries = 6;

  @override
  VoskModelState build() {
    // Kicks off automatically the first time anything watches this provider (see
    // VoskModelGate) — scheduled as a microtask because a Notifier's `build()` must return
    // synchronously and must not mutate `state` before returning its own initial value.
    Future.microtask(_start);
    return const VoskModelIdle();
  }

  Future<Directory> _supportDir() => getApplicationSupportDirectory();
  Future<File> _zipPartFile() async => File('${(await _supportDir()).path}/vosk-model-ar.zip.part');
  Future<File> _zipFile() async => File('${(await _supportDir()).path}/vosk-model-ar.zip');
  Future<File> _sizeMetaFile() async => File('${(await _supportDir()).path}/vosk-model-ar.size');
  Future<Directory> _modelDir() async => Directory('${(await _supportDir()).path}/vosk-model-ar');

  /// Full pipeline, safe to call repeatedly (used by both the initial automatic run and the
  /// user-triggered "retry" button) — every step first checks whether its own output already
  /// exists on disk and skips straight past it if so, which is exactly what makes retrying after
  /// a failure RESUME instead of restarting from zero.
  Future<void> _start() async {
    try {
      final modelDir = await _modelDir();
      final readyMarker = File('${modelDir.path}/$_readyMarkerFileName');

      if (await readyMarker.exists()) {
        await _loadExisting(modelDir);
        return;
      }

      final zipFile = await _zipFile();
      if (!await _isZipComplete(zipFile)) {
        await _downloadWithRetries();
      }
      await _extractAndBuild(await _zipFile(), modelDir, readyMarker);
    } catch (e) {
      state = VoskModelFailed(e.toString());
    }
  }

  Future<void> _loadExisting(Directory modelDir) async {
    final vosk = ref.read(voskPluginProvider);
    final model = await vosk.createModel(modelDir.path);
    state = VoskModelReady(model);
  }

  /// A `.zip` merely EXISTING on disk is not proof it's the whole file — a process kill mid
  /// rename, or a truncated write, can leave a file that exists but is short. This checks its
  /// actual byte length against the size we recorded from the server's own Content-Length header
  /// (see [_readExpectedSize]) the first time we successfully connected. If no size was ever
  /// recorded (a server that never reports Content-Length — rare), the file's mere existence is
  /// trusted, same as before.
  Future<bool> _isZipComplete(File zipFile) async {
    if (!await zipFile.exists()) return false;
    final expected = await _readExpectedSize();
    if (expected == null) return true;
    return await zipFile.length() == expected;
  }

  Future<int?> _readExpectedSize() async {
    final file = await _sizeMetaFile();
    if (!await file.exists()) return null;
    return int.tryParse((await file.readAsString()).trim());
  }

  Future<void> _writeExpectedSize(int size) async {
    final file = await _sizeMetaFile();
    await file.writeAsString(size.toString());
  }

  /// Wraps [_downloadOnce] in an automatic retry loop. Any exception from a single attempt
  /// (dropped connection, DNS blip, a stalled stream with no bytes for 30s, a server-side
  /// hiccup...) is swallowed and retried with a short, growing delay — NOT surfaced to the
  /// person. Each retry calls [_downloadOnce] again, which itself always resumes from whatever
  /// is already on disk (see there), so nothing already downloaded is ever thrown away by a
  /// retry. Only after [_maxAutoRetries] consecutive failures does the exception finally
  /// propagate up to [_start]'s catch block, which is what shows the manual retry screen — at
  /// that point the connection is genuinely unavailable, not just momentarily unstable.
  Future<void> _downloadWithRetries() async {
    for (var attempt = 1; attempt <= _maxAutoRetries; attempt++) {
      try {
        await _downloadOnce();
        return;
      } catch (_) {
        if (attempt == _maxAutoRetries) rethrow;
        await Future<void>.delayed(Duration(seconds: (attempt * 2).clamp(2, 15)));
      }
    }
  }

  /// Streams the .zip with real byte-level progress, resuming an interrupted download via an
  /// HTTP `Range` request instead of starting over. Both the initial connection and the transfer
  /// itself are time-bounded (20s to connect, 30s of silence mid-transfer) so a network stall
  /// surfaces as a retryable exception within seconds — never an indefinite spinner with no
  /// feedback, which was the original reported symptom.
  Future<void> _downloadOnce() async {
    final partFile = await _zipPartFile();
    final alreadyOnDisk = await partFile.exists() ? await partFile.length() : 0;
    state = VoskModelDownloading(downloadedBytes: alreadyOnDisk, totalBytes: await _readExpectedSize());

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(voskArabicModelUrl));
      if (alreadyOnDisk > 0) {
        request.headers[HttpHeaders.rangeHeader] = 'bytes=$alreadyOnDisk-';
      }
      final response = await client.send(request).timeout(const Duration(seconds: 20));

      final serverResumed = response.statusCode == 206;
      final startOffset = serverResumed ? alreadyOnDisk : 0;
      if (!serverResumed && alreadyOnDisk > 0) {
        // Server ignored the Range request and is sending the file from scratch — the existing
        // partial bytes are now meaningless and must not be kept mixed in with the fresh stream.
        await partFile.delete();
      }
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException('Unexpected status ${response.statusCode} downloading the voice model');
      }

      final reportedLength = response.contentLength;
      final totalBytes = reportedLength == null ? null : reportedLength + startOffset;
      if (totalBytes != null) await _writeExpectedSize(totalBytes);

      final sink = partFile.openWrite(mode: startOffset > 0 ? FileMode.append : FileMode.write);
      var received = startOffset;
      try {
        final timedStream = response.stream.timeout(
          const Duration(seconds: 30),
          onTimeout: (sink) => sink.addError(TimeoutException('Download stalled — no data for 30s')),
        );
        await for (final chunk in timedStream) {
          sink.add(chunk);
          received += chunk.length;
          state = VoskModelDownloading(downloadedBytes: received, totalBytes: totalBytes);
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
    } finally {
      client.close();
    }

    final zipFile = await _zipFile();
    await partFile.rename(zipFile.path);
  }

  /// Unzips off the UI thread AND with low, constant memory — the earlier version read the whole
  /// 318MB file into RAM at once (`readAsBytes` + `decodeBytes`), which is a well-known cause of
  /// the OS silently killing an app under memory pressure on a mid-range phone. `extractFileToDisk`
  /// is `archive_io`'s own official, battle-tested convenience function for exactly this job.
  ///
  /// FIX for the reported "asks to download again even though it worked and was tested last
  /// session" bug: the MGB-2 archive wraps every real model file one level deep inside its own
  /// top-level folder. The previous version left that nesting in place and wrote the `.ready`
  /// marker INSIDE the nested folder, while the startup check for "is a model already ready?"
  /// looked for that marker in the OUTER folder — two different paths, so the marker was never
  /// found on the next launch, and since the original .zip had already been deleted after a
  /// successful build, the pipeline fell all the way back to a fresh download. [_flattenIfWrapped]
  /// removes the nesting immediately after extraction, so `modelDir` itself is ALWAYS the final,
  /// canonical model path — read and written in exactly the same single place, every time.
  Future<void> _extractAndBuild(File zipFile, Directory modelDir, File readyMarker) async {
    state = const VoskModelExtracting();
    if (await modelDir.exists()) await modelDir.delete(recursive: true);
    await compute(_extractZipIsolate, _ExtractJob(zipFile.path, modelDir.path));
    await _flattenIfWrapped(modelDir);

    final vosk = ref.read(voskPluginProvider);
    late final Model model;
    try {
      model = await vosk.createModel(modelDir.path);
    } catch (e) {
      // Surface exactly what actually ended up on disk in the error message — if this happens
      // again, that listing (shown on the failure screen) is the difference between guessing
      // again and knowing precisely which files are missing/misnamed.
      final listing = await _describeDirectory(modelDir);
      throw StateError('$e\n\nExtracted contents of ${modelDir.path}:\n$listing');
    }

    // Marker is written in `modelDir` itself now — the SAME path `_start()` checks at the top of
    // every launch, by construction (no separate "resolved" path to ever drift out of sync with).
    await File('${modelDir.path}/$_readyMarkerFileName').writeAsString('ok');
    await zipFile.delete();
    final sizeMeta = await _sizeMetaFile();
    if (await sizeMeta.exists()) await sizeMeta.delete();

    state = VoskModelReady(model);
  }

  /// If the archive extracted into exactly one wrapping subfolder (rather than laying `am/`,
  /// `conf/`, etc. directly inside [modelDir]), moves that subfolder's contents up one level and
  /// removes the now-empty wrapper — so [modelDir] is guaranteed to be the real model root
  /// afterwards, regardless of how the upstream .zip happens to be packaged.
  Future<void> _flattenIfWrapped(Directory modelDir) async {
    if (await Directory('${modelDir.path}/am').exists()) return; // already flat
    final children = await modelDir.list().where((e) => e is Directory).cast<Directory>().toList();
    if (children.length != 1) return; // ambiguous structure — leave as-is; createModel will fail loudly with a clear listing if this guess was wrong
    final inner = children.first;
    await for (final entity in inner.list()) {
      final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
      await entity.rename('${modelDir.path}/$name');
    }
    await inner.delete(recursive: true);
  }

  Future<String> _describeDirectory(Directory dir) async {
    if (!await dir.exists()) return '(directory does not exist: ${dir.path})';
    final entries = await dir.list(recursive: true).take(30).toList();
    if (entries.isEmpty) return '(empty)';
    return entries.map((e) => e.path.replaceFirst(dir.path, '.')).join('\n');
  }

  /// Called by the retry button. Deliberately identical to the automatic first run — the whole
  /// point of writing the pipeline as "skip whatever already exists" is that retrying IS resuming.
  Future<void> retry() => _start();
}

class _ExtractJob {
  const _ExtractJob(this.zipPath, this.outputDirPath);
  final String zipPath;
  final String outputDirPath;
}

/// Must be a top-level function — [compute] spawns it on a fresh isolate with no access to this
/// file's other state, only whatever is passed in [job].
///
/// Uses `extractFileToDisk` — `archive_io`'s own official convenience function — rather than
/// manually chaining `InputFileStream` + `ZipDecoder().decodeStream()` + `extractArchiveToDisk()`.
/// An earlier version of this file used that manual chain and reportedly produced files Vosk
/// itself rejected as invalid ("Failed to create a model") despite every byte having downloaded
/// correctly — i.e. the corruption happened during extraction, not the download. This single
/// call streams both the read and the decompression internally and is the pattern documented in
/// the package's own README/examples for exactly this "large zip, low memory" use case.
Future<void> _extractZipIsolate(_ExtractJob job) async {
  await extractFileToDisk(job.zipPath, job.outputDirPath);
}
