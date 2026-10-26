import 'package:flutter/services.dart';

/// Detects whether the operating system currently exposes a Bluetooth audio
/// input/output device. It does not pair devices: pairing and audio routing
/// remain the user's operating-system choice, as required for headsets.
/// The connected headset as the OS describes it. [batteryPercent] is null when the phone does not
/// expose it (common) — the screen hides the battery row then instead of guessing.
class BluetoothHeadsetInfo {
  const BluetoothHeadsetInfo({this.name, this.batteryPercent});
  final String? name;
  final int? batteryPercent;
}

class BluetoothAudioRouteService {
  static const _channel = MethodChannel('dyooni/voice_bluetooth');

  Future<bool> isHeadsetConnected() async {
    try {
      return await _channel.invokeMethod<bool>('isHeadsetConnected') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Whether the phone's Bluetooth radio is on. Never throws (false when unknown).
  Future<bool> isBluetoothEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isBluetoothEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system Bluetooth settings page (to switch it on / pair a headset).
  Future<void> openBluetoothSettings() async {
    try {
      await _channel.invokeMethod<bool>('openBluetoothSettings');
    } catch (_) {}
  }

  /// Never throws; returns an empty info object when nothing is known.
  Future<BluetoothHeadsetInfo> headsetInfo() async {
    try {
      final map = await _channel.invokeMapMethod<String, Object?>('headsetInfo');
      final name = (map?['name'] as String?)?.trim();
      final battery = (map?['battery'] as num?)?.toInt();
      return BluetoothHeadsetInfo(
        name: (name == null || name.isEmpty) ? null : name,
        batteryPercent: (battery == null || battery < 0 || battery > 100) ? null : battery,
      );
    } catch (_) {
      return const BluetoothHeadsetInfo();
    }
  }
}
