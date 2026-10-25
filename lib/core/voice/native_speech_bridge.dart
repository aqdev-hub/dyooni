import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// One event from the native recognizer: `partial`, `final` or `error` (Android error [code]).
class NativeSpeechEvent {
  const NativeSpeechEvent(this.type, this.texts, this.code);
  final String type;
  final List<String> texts;
  final int code;
}

/// Dart side of android `NativeSpeechBridge.kt`: runs the system recognizer on audio the app
/// feeds it (Android 13+), so the app's own recorder can be the only microphone owner.
/// Every call is best-effort; nothing here throws.
class NativeSpeechBridge {
  NativeSpeechBridge() {
    if (Platform.isAndroid) _channel.setMethodCallHandler(_onCall);
  }

  static const _channel = MethodChannel('dyooni/native_speech');
  final _events = StreamController<NativeSpeechEvent>.broadcast();

  Stream<NativeSpeechEvent> get events => _events.stream;

  Future<dynamic> _onCall(MethodCall call) async {
    if (call.method != 'event') return null;
    final map = Map<Object?, Object?>.from(call.arguments as Map);
    _events.add(NativeSpeechEvent(
      map['type'] as String? ?? '',
      [for (final t in (map['texts'] as List?) ?? const []) t.toString()],
      (map['code'] as num?)?.toInt() ?? 0,
    ));
    return null;
  }

  Future<bool> isSupported() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> start(String locale) async {
    try {
      return await _channel.invokeMethod<bool>('start', {'locale': locale}) ?? false;
    } catch (_) {
      return false;
    }
  }

  void feed(Uint8List bytes) {
    try {
      unawaited(_channel.invokeMethod<void>('feed', {'bytes': bytes}).catchError((_) {}));
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }

  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } catch (_) {}
  }

  void dispose() {
    _events.close();
  }
}
