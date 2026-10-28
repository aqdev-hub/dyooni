import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Runs NVIDIA's Arabic FastConformer (CTC, int8 ONNX) through sherpa-onnx on a background isolate.
///
/// WHY AN ISOLATE: the recognizer is a native object that must be created once (loading the 131 MB
/// model takes seconds) and then reused; decoding a clip takes a noticeable fraction of a second and
/// must not freeze the voice screen's animations. A long-lived worker isolate owns the recognizer;
/// the UI isolate only sends samples and awaits text.
///
/// ALL sherpa-onnx API usage is confined to [_worker] below, so if a different sherpa_onnx version
/// renames something, that is the only place to adjust.
class FastConformerDecoder {
  Isolate? _isolate;
  SendPort? _toWorker;
  String? _loadedModel;
  Future<void>? _loading;

  /// Loads the model into the worker (no-op when already loaded). Safe to call early, e.g. when the
  /// recording starts, so the first decode does not pay the load time.
  Future<void> ensureLoaded({required String modelPath, required String tokensPath, int threads = 4}) {
    if (_toWorker != null && _loadedModel == modelPath) return Future<void>.value();
    return _loading ??= _load(modelPath, tokensPath, threads).whenComplete(() => _loading = null);
  }

  Future<void> _load(String modelPath, String tokensPath, int threads) async {
    await dispose();
    final ready = ReceivePort();
    final isolate = await Isolate.spawn(_worker, _Init(ready.sendPort, modelPath, tokensPath, threads));
    final first = await ready.first.timeout(const Duration(seconds: 60));
    ready.close();
    if (first is _Failure) {
      isolate.kill(priority: Isolate.immediate);
      throw StateError('FastConformer failed to load: ${first.message}');
    }
    _isolate = isolate;
    _toWorker = first as SendPort;
    _loadedModel = modelPath;
  }

  /// Returns the recognised text of 16 kHz mono [samples] (floats in -1..1).
  Future<String> decode(Float32List samples, {int sampleRate = 16000}) async {
    final worker = _toWorker;
    if (worker == null) throw StateError('FastConformer is not loaded.');
    final reply = ReceivePort();
    worker.send(_Job(samples, sampleRate, reply.sendPort));
    final result = await reply.first;
    reply.close();
    if (result is _Failure) throw StateError(result.message);
    return result as String;
  }

  /// Frees the native recognizer and stops the worker.
  Future<void> dispose() async {
    _toWorker?.send('close');
    _toWorker = null;
    _isolate?.kill(priority: Isolate.beforeNextEvent);
    _isolate = null;
    _loadedModel = null;
  }
}

class _Init {
  const _Init(this.reply, this.model, this.tokens, this.threads);
  final SendPort reply;
  final String model;
  final String tokens;
  final int threads;
}

class _Job {
  const _Job(this.samples, this.sampleRate, this.reply);
  final Float32List samples;
  final int sampleRate;
  final SendPort reply;
}

class _Failure {
  const _Failure(this.message);
  final String message;
}

/// Isolate entry point. Builds the recognizer, announces readiness, then answers jobs.
void _worker(_Init init) {
  final port = ReceivePort();
  late final sherpa.OfflineRecognizer loaded;
  try {
    sherpa.initBindings();
    final config = sherpa.OfflineRecognizerConfig(
      model: sherpa.OfflineModelConfig(
        nemoCtc: sherpa.OfflineNemoEncDecCtcModelConfig(model: init.model),
        tokens: init.tokens,
        numThreads: init.threads,
        debug: false,
      ),
    );
    loaded = sherpa.OfflineRecognizer(config);
    init.reply.send(port.sendPort);
  } catch (e) {
    init.reply.send(_Failure(e.toString()));
    return;
  }
  port.listen((message) {
    if (message is _Job) {
      try {
        final stream = loaded.createStream();
        stream.acceptWaveform(samples: message.samples, sampleRate: message.sampleRate);
        loaded.decode(stream);
        final text = loaded.getResult(stream).text;
        stream.free();
        message.reply.send(text);
      } catch (e) {
        message.reply.send(_Failure(e.toString()));
      }
    } else if (message == 'close') {
      loaded.free();
      port.close();
    }
  });
}
