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
  // Saved so `dyooni/voice_audio_cues`'s "restore" call can put the person's own volume back
  // EXACTLY as it was, never a guessed/default value — see configureFlutterEngine below.
  private var savedNotificationVolume: Int? = null
  private var savedMusicVolume: Int? = null
  private var nativeSpeech: NativeSpeechBridge? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    nativeSpeech = NativeSpeechBridge(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
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

    // NEW — see core/voice/system_speech_engine.dart's `_SystemSoundMuter` doc comment for the
    // full story. `android.speech.SpeechRecognizer` plays its own "start listening"/"stop
    // listening" notification tones on EVERY session — there is no supported flag on the Dart
    // side (nor in the plugin) to turn these off. Dyooni's voice dialogue opens a fresh
    // recognizer session on almost every turn (each clarification question, every confirmation
    // re-listen), so those two tones were repeating constantly — exactly the reported symptom.
    // Muting the two streams that carry these system cues for the brief moment a session is
    // starting/stopping, then restoring the person's own volume immediately after, is the
    // standard, production-proven workaround for this well-known `speech_to_text` limitation.
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dyooni/voice_audio_cues")
      .setMethodCallHandler { call, result ->
        val manager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        when (call.method) {
          "muteRecognitionSounds" -> {
            // Only remember the volume once, the FIRST time we mute — if a second mute call
            // arrives before a restore (e.g. two overlapping listen attempts), overwriting the
            // saved value here with "0" (already-muted) would make the eventual restore leave
            // the person permanently muted. Guarding on `== null` makes this idempotent.
            if (savedNotificationVolume == null) {
              savedNotificationVolume = manager.getStreamVolume(AudioManager.STREAM_NOTIFICATION)
            }
            if (savedMusicVolume == null) {
              savedMusicVolume = manager.getStreamVolume(AudioManager.STREAM_MUSIC)
            }
            manager.setStreamVolume(AudioManager.STREAM_NOTIFICATION, 0, 0)
            manager.setStreamVolume(AudioManager.STREAM_MUSIC, 0, 0)
            result.success(null)
          }
          "restoreRecognitionSounds" -> {
            savedNotificationVolume?.let {
              manager.setStreamVolume(AudioManager.STREAM_NOTIFICATION, it, 0)
            }
            savedMusicVolume?.let {
              manager.setStreamVolume(AudioManager.STREAM_MUSIC, it, 0)
            }
            savedNotificationVolume = null
            savedMusicVolume = null
            result.success(null)
          }
          else -> result.notImplemented()
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
