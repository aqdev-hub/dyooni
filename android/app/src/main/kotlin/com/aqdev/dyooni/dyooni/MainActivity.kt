package com.aqdev.dyooni.dyooni

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dyooni/voice_bluetooth")
      .setMethodCallHandler { call, result ->
        if (call.method == "isHeadsetConnected") {
          result.success(hasBluetoothAudioDevice())
        } else {
          result.notImplemented()
        }
      }
  }

  private fun hasBluetoothAudioDevice(): Boolean {
    val manager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
    return manager.getDevices(AudioManager.GET_DEVICES_ALL).any { device ->
      device.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
        device.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
        device.type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
        device.type == AudioDeviceInfo.TYPE_BLE_SPEAKER
    }
  }
}
