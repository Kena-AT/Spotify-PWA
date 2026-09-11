import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final List<Map<String, dynamic>> _eventBuffer = [];

  static void logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    final eventData = {
      'event': eventName,
      'timestamp': DateTime.now().toIso8601String(),
      if (parameters != null) ...parameters,
    };

    debugPrint('[AnalyticsService] Event logged: $eventData');
    _eventBuffer.add(eventData);

    if (_eventBuffer.length > 500) {
      _eventBuffer.removeAt(0);
    }
  }

  static void logAppOpen() {
    logEvent('app_open');
  }

  static void logPlaybackStateChanged({required String title, required bool isPlaying}) {
    logEvent('playback_state_changed', parameters: {
      'title': title,
      'is_playing': isPlaying,
    });
  }

  static void logThemeChanged(String themeName) {
    logEvent('theme_changed', parameters: {
      'theme_mode': themeName,
    });
  }

  static void logConnectivityChanged(bool isOnline) {
    logEvent('connectivity_changed', parameters: {
      'is_online': isOnline,
    });
  }

  static List<Map<String, dynamic>> getEvents() => List.unmodifiable(_eventBuffer);
}
