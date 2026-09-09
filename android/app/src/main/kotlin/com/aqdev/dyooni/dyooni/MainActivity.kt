package com.aqdev.dyooni.dyooni

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.MediaScannerConnection
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

    // Registers a directly-written file (e.g. a local backup saved via plain `dart:io` File
    // writes to the public Downloads/ديوني folder — see local_backup_provider.dart) with
    // Android's own MediaStore index. Without this, files written this way are genuinely on
    // disk (a regular file manager sees them immediately) but invisible to SAF-based document
    // pickers like the `file_picker` package used by the restore flow, because that picker
    // browses Android's indexed "Downloads" collection, not the raw filesystem.
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dyooni/media_scanner")
      .setMethodCallHandler { call, result ->
        if (call.method == "scanFile") {
          val path = call.argument<String>("path")
          if (path == null) {
            result.error("invalid_argument", "path is required", null)
          } else {
            MediaScannerConnection.scanFile(applicationContext, arrayOf(path), null, null)
            result.success(null)
          }
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
