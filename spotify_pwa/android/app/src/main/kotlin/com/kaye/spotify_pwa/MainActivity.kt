package com.kaye.spotify_pwa

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent

class MainActivity : FlutterActivity() {
  companion object {
    const val AUDIO_CHANNEL = "com.spotify.pwa/audio"
    var audioMethodChannel: MethodChannel? = null
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    // Setup audio method channel
    audioMethodChannel = MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      AUDIO_CHANNEL
    ).apply {
      setMethodCallHandler { call, result ->
        when (call.method) {
          "startAudioService" -> {
            startAudioService()
            result.success(true)
          }
          "stopAudioService" -> {
            stopAudioService()
            result.success(true)
          }
          "updatePlaybackState" -> {
            val title = call.argument<String>("title") ?: "Spotify"
            val artist = call.argument<String>("artist") ?: ""
            val isPlaying = call.argument<Boolean>("isPlaying") ?: false
            val albumArtUrl = call.argument<String>("albumArtUrl")
            updatePlaybackState(title, artist, isPlaying, albumArtUrl)
            result.success(true)
          }
          else -> result.notImplemented()
        }
      }
    }
  }

  private fun startAudioService() {
    val intent = Intent(this, AudioService::class.java)
    startForegroundService(intent)
  }

  private fun stopAudioService() {
    val intent = Intent(this, AudioService::class.java)
    stopService(intent)
  }

  private fun updatePlaybackState(title: String, artist: String, isPlaying: Boolean, albumArtUrl: String?) {
    val intent = Intent(this, AudioService::class.java)
    intent.putExtra("title", title)
    intent.putExtra("artist", artist)
    intent.putExtra("isPlaying", isPlaying)
    if (albumArtUrl != null) {
      intent.putExtra("albumArtUrl", albumArtUrl)
    }
    startForegroundService(intent)
  }
}
