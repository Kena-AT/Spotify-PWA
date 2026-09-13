package com.kaye.spotify_pwa

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.media.audiofx.AudioEffect
import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class EqualizerBridge(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        private const val TAG = "EqualizerBridge"
        const val CHANNEL_NAME = "com.spotify.pwa/equalizer"
    }

    private var methodChannel: MethodChannel? = null
    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private val audioSessionId = 0 // Global audio mix session where allowed

    fun registerWith(messenger: BinaryMessenger) {
        methodChannel = MethodChannel(messenger, CHANNEL_NAME)
        methodChannel?.setMethodCallHandler(this)
        initEffects()
    }

    private fun initEffects() {
        try {
            // Attempt to initialize on global audio session 0
            equalizer = Equalizer(0, audioSessionId).apply {
                enabled = true
            }
            bassBoost = BassBoost(0, audioSessionId).apply {
                enabled = true
            }
            Log.d(TAG, "Initialized Equalizer and BassBoost on session $audioSessionId")
        } catch (e: Exception) {
            Log.w(TAG, "Direct session 0 equalizer unavailable on this device/ROM: ${e.message}")
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openSystemEqualizer" -> {
                val opened = openSystemEqualizerPanel()
                result.success(opened)
            }
            "isSupported" -> {
                result.success(equalizer != null)
            }
            "setBandGain" -> {
                val band = call.argument<Int>("band") ?: 0
                val gainDb = (call.argument<Double>("gain") ?: 0.0).toFloat()
                val success = setBandGainInternal(band, gainDb)
                result.success(success)
            }
            "setBassBoost" -> {
                val strength = (call.argument<Double>("strength") ?: 0.0).toFloat()
                val success = setBassBoostInternal(strength)
                result.success(success)
            }
            "setEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                equalizer?.enabled = enabled
                bassBoost?.enabled = enabled
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun openSystemEqualizerPanel(): Boolean {
        return try {
            val intent = Intent(AudioEffect.ACTION_DISPLAY_AUDIO_EFFECT_CONTROL_PANEL).apply {
                putExtra(AudioEffect.EXTRA_AUDIO_SESSION, audioSessionId)
                putExtra(AudioEffect.EXTRA_PACKAGE_NAME, activity.packageName)
                putExtra(AudioEffect.EXTRA_CONTENT_TYPE, AudioEffect.CONTENT_TYPE_MUSIC)
            }
            activity.startActivityForResult(intent, 1001)
            true
        } catch (e: ActivityNotFoundException) {
            Log.w(TAG, "No system equalizer control panel app found: ${e.message}")
            false
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch system equalizer: ${e.message}")
            false
        }
    }

    private fun setBandGainInternal(band: Int, gainDb: Float): Boolean {
        return try {
            equalizer?.let { eq ->
                if (band in 0 until eq.numberOfBands) {
                    val minLevel = eq.bandLevelRange[0]
                    val maxLevel = eq.bandLevelRange[1]
                    // Convert -10..+10 dB into mB (-1000..+1000) mapped to band level range
                    val targetLevel = (gainDb * 100).toInt().coerceIn(minLevel.toInt(), maxLevel.toInt())
                    eq.setBandLevel(band.toShort(), targetLevel.toShort())
                    true
                } else false
            } ?: false
        } catch (e: Exception) {
            Log.e(TAG, "Error setting band gain: ${e.message}")
            false
        }
    }

    private fun setBassBoostInternal(strength: Float): Boolean {
        return try {
            bassBoost?.let { bb ->
                if (bb.strengthSupported) {
                    val targetStrength = (strength * 1000).toInt().coerceIn(0, 1000)
                    bb.setStrength(targetStrength.toShort())
                    true
                } else false
            } ?: false
        } catch (e: Exception) {
            Log.e(TAG, "Error setting bass boost: ${e.message}")
            false
        }
    }

    fun release() {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        try {
            equalizer?.release()
            bassBoost?.release()
        } catch (e: Exception) {
            // Ignore release exceptions
        }
    }
}
