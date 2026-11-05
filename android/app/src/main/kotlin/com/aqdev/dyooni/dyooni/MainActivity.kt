package com.aqdev.dyooni.dyooni

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.MediaScannerConnection
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (was FlutterActivity) — required by local_auth for the biometric
// prompt used in general_settings_screen.dart / app_lock_screen.dart. FlutterActivity alone
// cannot host the native BiometricPrompt dialog local_auth relies on.
class MainActivity : FlutterFragmentActivity() {
  private var nativeSpeech: NativeSpeechBridge? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    nativeSpeech = NativeSpeechBridge(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dyooni/voice_bluetooth")
      .setMethodCallHandler { call, result ->
        if (call.method == "isHeadsetConnected") {
          result.success(hasBluetoothAudioDevice())
        } else if (call.method == "isBluetoothEnabled") {
          val bt = getSystemService(Context.BLUETOOTH_SERVICE) as? android.bluetooth.BluetoothManager
          result.success(try { bt?.adapter?.isEnabled ?: false } catch (_: Throwable) { false })
        } else if (call.method == "openBluetoothSettings") {
          try {
            startActivity(
              android.content.Intent(android.provider.Settings.ACTION_BLUETOOTH_SETTINGS)
                .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            result.success(true)
          } catch (_: Throwable) {
            result.success(false)
          }
        } else if (call.method == "headsetInfo") {
          result.success(headsetInfo())
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

    // NEW — see core/voice/system_speech_engine.dart's `_SystemSoundMuter` doc comment for the
    // full story. `android.speech.SpeechRecognizer` plays its own "start listening"/"stop
    // listening" notification tones on EVERY session — there is no supported flag on the Dart
    // side (nor in the plugin) to turn these off. Dyooni's voice dialogue opens a fresh
    // recognizer session on almost every turn (each clarification question, every confirmation
    // re-listen), so those two tones were repeating constantly — exactly the reported symptom.
    // Muting the two streams that carry these system cues for the brief moment a session is
    // starting/stopping, then restoring the person's own volume immediately after, is the
    // standard, production-proven workaround for this well-known `speech_to_text` limitation.
    // The recognizer's own "start/stop listening" tones are silenced by lowering ONLY the
    // notification stream for the moment a session runs. The MUSIC (media) stream is never touched
    // any more: lowering it was the reported "the speaker volume drops to zero every time a voice
    // operation starts" — and it also silenced the app's own spoken questions. The previous value
    // is stored on disk, so even if the app is killed mid-session the person's volume comes back
    // on the next launch (restoreStuckVolume below).
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dyooni/voice_audio_cues")
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "muteRecognitionSounds" -> {
            muteNotificationStream()
            result.success(null)
          }
          "restoreRecognitionSounds" -> {
            restoreStuckVolume()
            result.success(null)
          }
          else -> result.notImplemented()
        }
      }
    // A previous run may have been killed while muted.
    restoreStuckVolume()
  }

  private val audioPrefs by lazy { getSharedPreferences("dyooni_audio_cues", Context.MODE_PRIVATE) }

  private fun muteNotificationStream() {
    try {
      val manager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
      // Remember the person's volume only the FIRST time: a second mute before a restore must not
      // overwrite it with the already-lowered value.
      if (!audioPrefs.contains(SAVED_NOTIFICATION_KEY)) {
        audioPrefs.edit().putInt(SAVED_NOTIFICATION_KEY, manager.getStreamVolume(AudioManager.STREAM_NOTIFICATION)).commit()
      }
      manager.setStreamVolume(AudioManager.STREAM_NOTIFICATION, 0, 0)
    } catch (_: Throwable) {
      // Some devices refuse to change this stream (Do Not Disturb policy); the tones then simply play.
    }
  }

  private fun restoreStuckVolume() {
    try {
      if (!audioPrefs.contains(SAVED_NOTIFICATION_KEY)) return
      val saved = audioPrefs.getInt(SAVED_NOTIFICATION_KEY, -1)
      if (saved >= 0) {
        val manager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        manager.setStreamVolume(AudioManager.STREAM_NOTIFICATION, saved, 0)
      }
      audioPrefs.edit().remove(SAVED_NOTIFICATION_KEY).commit()
    } catch (_: Throwable) {
    }
  }

  override fun onDestroy() {
    restoreStuckVolume()
    super.onDestroy()
  }

  companion object {
    private const val SAVED_NOTIFICATION_KEY = "saved_notification_volume"
  }

  /// Name (and, when the OS exposes it, battery %) of the connected Bluetooth headset. Battery
  /// uses the hidden BluetoothDevice.getBatteryLevel() through reflection, which many Android
  /// versions block or which needs the BLUETOOTH_CONNECT runtime permission — every failure just
  /// leaves it out (-1), and the screen then simply hides the battery.
  private fun headsetInfo(): Map<String, Any?> {
    val manager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
    val device = manager.getDevices(AudioManager.GET_DEVICES_ALL).firstOrNull { d ->
      d.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
        d.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
        d.type == AudioDeviceInfo.TYPE_BLE_HEADSET
    } ?: return mapOf("name" to null, "battery" to -1)
    var battery = -1
    try {
      val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as android.bluetooth.BluetoothManager
      val bonded = btManager.adapter?.bondedDevices ?: emptySet()
      val match = bonded.firstOrNull { it.address == device.address }
      if (match != null) {
        battery = match.javaClass.getMethod("getBatteryLevel").invoke(match) as? Int ?: -1
      }
    } catch (_: Throwable) {
      battery = -1
    }
    return mapOf("name" to device.productName?.toString(), "battery" to battery)
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
