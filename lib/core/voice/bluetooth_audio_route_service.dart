import 'package:flutter/services.dart';

/// Detects whether the operating system currently exposes a Bluetooth audio
/// input/output device. It does not pair devices: pairing and audio routing
/// remain the user's operating-system choice, as required for headsets.
class BluetoothAudioRouteService {
  static const _channel = MethodChannel('dyooni/voice_bluetooth');

  Future<bool> isHeadsetConnected() async {
    try {
      return await _channel.invokeMethod<bool>('isHeadsetConnected') ?? false;
    } on PlatformException {
      return false;
    }
  }
}
