import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static const platform = MethodChannel('com.spotify.pwa/audio');
  
  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  /// Initialize the background audio service
  static Future<bool> startBackgroundAudio() async {
    try {
      final bool result = await platform.invokeMethod('startAudioService');
      _isInitialized = true;
      debugPrint('[AudioService] Background audio started');
      return result;
    } on PlatformException catch (e) {
      debugPrint('[AudioService] Failed to start: ${e.message}');
      return false;
    }
  }

  /// Stop the background audio service
  static Future<bool> stopBackgroundAudio() async {
    try {
      final bool result = await platform.invokeMethod('stopAudioService');
      _isInitialized = false;
      debugPrint('[AudioService] Background audio stopped');
      return result;
    } on PlatformException catch (e) {
      debugPrint('[AudioService] Failed to stop: ${e.message}');
      return false;
    }
  }

  /// Update playback state in notification
  static Future<bool> updatePlaybackState({
    required String title,
    required String artist,
    required bool isPlaying,
    String? albumArtUrl,
    int? position,
    int? duration,
  }) async {
    try {
      final bool result = await platform.invokeMethod(
        'updatePlaybackState',
        {
          'title': title,
          'artist': artist,
          'isPlaying': isPlaying,
          ?albumArtUrl: albumArtUrl,
          ?position: position,
          ?duration: duration,
        },
      );
      _isInitialized = true;
      debugPrint('[AudioService] Updated playback state: $title by $artist (${isPlaying ? 'playing' : 'paused'})');
      return result;
    } on PlatformException catch (e) {
      debugPrint('[AudioService] Failed to update state: ${e.message}');
      return false;
    }
  }

  /// Handle playback control from native
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
