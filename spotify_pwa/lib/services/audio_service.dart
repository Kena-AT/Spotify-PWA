import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class AudioService {
  static const platform = MethodChannel('com.spotify.pwa/audio');
  
  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  /**
   * Initialize the background audio service
   */
  static Future<bool> startBackgroundAudio() async {
    try {
      final bool result = await platform.invokeMethod('startAudioService');
      _isInitialized = true;
      print('[AudioService] Background audio started');
      return result;
    } on PlatformException catch (e) {
      print('[AudioService] Failed to start: ${e.message}');
      return false;
    }
  }

  /**
   * Stop the background audio service
   */
  static Future<bool> stopBackgroundAudio() async {
    try {
      final bool result = await platform.invokeMethod('stopAudioService');
      _isInitialized = false;
      print('[AudioService] Background audio stopped');
      return result;
    } on PlatformException catch (e) {
      print('[AudioService] Failed to stop: ${e.message}');
      return false;
    }
  }

  /**
   * Update playback state in notification
   */
  static Future<bool> updatePlaybackState({
    required String title,
    required String artist,
    required bool isPlaying,
    String? albumArtUrl,
  }) async {
    try {
      final bool result = await platform.invokeMethod(
        'updatePlaybackState',
        {
          'title': title,
          'artist': artist,
          'isPlaying': isPlaying,
          if (albumArtUrl != null) 'albumArtUrl': albumArtUrl,
        },
      );
      print('[AudioService] Updated playback state: $title by $artist (${isPlaying ? 'playing' : 'paused'})');
      return result;
    } on PlatformException catch (e) {
      print('[AudioService] Failed to update state: ${e.message}');
      return false;
    }
  }

  /**
   * Handle playback control from native
   */
  static Future<void> handlePlaybackControl(
    Function(String) callback,
    dynamic webviewController,
  ) async {
    platform.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'handlePlaybackControl') {
        final String action = call.arguments['action'];
        callback(action);
      }
      return null;
    });
  }
}
