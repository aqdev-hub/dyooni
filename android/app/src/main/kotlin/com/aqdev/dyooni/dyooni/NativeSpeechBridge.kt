package com.aqdev.dyooni.dyooni

import android.annotation.TargetApi
import android.content.Context
import android.content.Intent
import android.media.AudioFormat
import android.os.Build
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream
import java.util.concurrent.Executors

/**
 * Runs Android's SpeechRecognizer on audio WE supply (Android 13+, RecognizerIntent.EXTRA_AUDIO_SOURCE)
 * instead of letting it open the microphone itself. The Dart side owns the single microphone
 * (the `record` stream that also writes the replayable .wav) and forwards every PCM16 chunk through
 * "feed" into a pipe the recognizer reads. One microphone owner => no capture conflict, and the
 * original recording is kept. Whether a given recognizer service honours EXTRA_AUDIO_SOURCE is
 * decided by that service; the Dart side falls back to the plain plugin path when this fails.
 */
class NativeSpeechBridge(private val context: Context, messenger: BinaryMessenger) {
  private val channel = MethodChannel(messenger, "dyooni/native_speech")
  private val writer = Executors.newSingleThreadExecutor()
  private var recognizer: SpeechRecognizer? = null
  private var readEnd: ParcelFileDescriptor? = null
  private var out: OutputStream? = null
  private var session = 0

  init {
    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "isSupported" ->
          result.success(
            Build.VERSION.SDK_INT >= 33 && SpeechRecognizer.isRecognitionAvailable(context)
          )
        "start" -> result.success(start(call.argument<String>("locale")))
        "feed" -> {
          val bytes = call.argument<ByteArray>("bytes")
          val stream = out
          if (bytes != null && stream != null) {
            writer.execute {
              try {
                stream.write(bytes)
                stream.flush()
              } catch (_: Throwable) {
              }
            }
          }
          result.success(null)
        }
        "stop" -> {
          closeOut()
          try {
            recognizer?.stopListening()
          } catch (_: Throwable) {
          }
          result.success(null)
        }
        "cancel" -> {
          teardown()
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }
  }

  @TargetApi(33)
  private fun start(locale: String?): Boolean {
    if (Build.VERSION.SDK_INT < 33) return false
    teardown()
    return try {
      val pipe = ParcelFileDescriptor.createPipe()
      readEnd = pipe[0]
      out = ParcelFileDescriptor.AutoCloseOutputStream(pipe[1])
      val id = ++session
      val sr = SpeechRecognizer.createSpeechRecognizer(context)
      sr.setRecognitionListener(listener(id))
      val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
        if (!locale.isNullOrEmpty()) putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale.replace('_', '-'))
        putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, readEnd)
        putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, 16000)
        putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
        putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
      }
      recognizer = sr
      sr.startListening(intent)
      true
    } catch (_: Throwable) {
      teardown()
      false
    }
  }

  private fun closeOut() {
    val stream = out
    out = null
    if (stream != null) {
      // Queued after any pending writes, so the recognizer sees all audio and then EOF.
      writer.execute {
        try {
          stream.close()
        } catch (_: Throwable) {
        }
      }
    }
  }

  private fun teardown() {
    session++
    closeOut()
    try {
      recognizer?.cancel()
      recognizer?.destroy()
    } catch (_: Throwable) {
    }
    recognizer = null
    try {
      readEnd?.close()
    } catch (_: Throwable) {
    }
    readEnd = null
  }

  private fun emit(type: String, texts: List<String>, code: Int) {
    channel.invokeMethod("event", mapOf("type" to type, "texts" to texts, "code" to code))
  }

  private fun texts(bundle: Bundle?): List<String> =
    bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.toList() ?: emptyList()

  private fun listener(id: Int) = object : RecognitionListener {
    override fun onReadyForSpeech(params: Bundle?) {}
    override fun onBeginningOfSpeech() {}
    override fun onRmsChanged(rmsdB: Float) {}
    override fun onBufferReceived(buffer: ByteArray?) {}
    override fun onEndOfSpeech() {}
    override fun onEvent(eventType: Int, params: Bundle?) {}
    override fun onPartialResults(partialResults: Bundle?) {
      if (id == session) emit("partial", texts(partialResults), 0)
    }
    override fun onResults(results: Bundle?) {
      if (id == session) emit("final", texts(results), 0)
    }
    override fun onError(error: Int) {
      if (id == session) emit("error", emptyList(), error)
    }
  }
}
