package com.kaye.spotify_pwa

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Build

class MainActivity : FlutterActivity() {
  companion object {
    const val AUDIO_CHANNEL = "com.spotify.pwa/audio"
    var audioMethodChannel: MethodChannel? = null
  }

  private var equalizerBridge: EqualizerBridge? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    // Setup equalizer bridge
    equalizerBridge = EqualizerBridge(this).apply {
      registerWith(flutterEngine.dartExecutor.binaryMessenger)
    }

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
            val position = (call.argument<Number>("position") ?: 0).toLong()
            val duration = (call.argument<Number>("duration") ?: 0).toLong()
            updatePlaybackState(title, artist, isPlaying, albumArtUrl, position, duration)
            result.success(true)
          }
          else -> result.notImplemented()
        }
      }
    }

    // Setup general platform method channel
    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      "com.kaye.spotify_pwa/platform"
    ).setMethodCallHandler { call, result ->
      when (call.method) {
        "getPlatformVersion" -> result.success("Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})")
        "getBatteryLevel" -> {
          val batteryManager = getSystemService(BATTERY_SERVICE) as? android.os.BatteryManager
          val level = batteryManager?.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: -1
          result.success(level)
        }
        "isBatteryOptimizationDisabled" -> {
          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(POWER_SERVICE) as? android.os.PowerManager
            val isIgnoring = pm?.isIgnoringBatteryOptimizations(packageName) ?: false
            result.success(isIgnoring)
          } else {
            result.success(true)
          }
        }
        else -> result.notImplemented()
      }
    }
  }

  private fun startAudioService() {
    try {
      val intent = Intent(this, AudioService::class.java)
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        startForegroundService(intent)
      } else {
        startService(intent)
      }
    } catch (e: Exception) {
      e.printStackTrace()
    }
  }

  private fun stopAudioService() {
    try {
      val intent = Intent(this, AudioService::class.java).apply {
        action = AudioService.ACTION_STOP
      }
      startService(intent)
    } catch (e: Exception) {
      val intent = Intent(this, AudioService::class.java)
      stopService(intent)
    }
  }

  private fun updatePlaybackState(
    title: String,
    artist: String,
    isPlaying: Boolean,
    albumArtUrl: String?,
    position: Long,
    duration: Long
  ) {
    try {
      val intent = Intent(this, AudioService::class.java).apply {
        putExtra("title", title)
        putExtra("artist", artist)
        putExtra("isPlaying", isPlaying)
        if (albumArtUrl != null) {
          putExtra("albumArtUrl", albumArtUrl)
        }
        putExtra("position", position)
        putExtra("duration", duration)
      }
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        startForegroundService(intent)
      } else {
        startService(intent)
      }
    } catch (e: Exception) {
      e.printStackTrace()
    }
  }

  override fun onDestroy() {
    equalizerBridge?.release()
    equalizerBridge = null
    audioMethodChannel = null
    stopAudioService()
    super.onDestroy()
  }
}
