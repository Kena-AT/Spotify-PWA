import 'package:flutter/foundation.dart';

class CrashlyticsService {
  static final List<String> _errorLogBuffer = [];

  static Future<void> initialize() async {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      recordFlutterError(details);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      recordError(error, stack, fatal: true);
      return true;
    };

    debugPrint('[CrashlyticsService] Initialized crash reporting system.');
  }

  static void recordFlutterError(FlutterErrorDetails details) {
    final entry = '[FlutterError] ${details.exceptionAsString()}\n${details.stack}';
    _log(entry);
  }

  static void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    final prefix = fatal ? '[FATAL]' : '[NON-FATAL]';
    final entry = '$prefix Error: $error\nStack trace: $stack';
    _log(entry);
  }

  static void log(String message) {
    _log('[LOG] $message');
  }

  static void _log(String entry) {
    debugPrint(entry);
    _errorLogBuffer.add('${DateTime.now().toIso8601String()} $entry');
    if (_errorLogBuffer.length > 200) {
      _errorLogBuffer.removeAt(0);
    }
  }

  static List<String> getLogs() => List.unmodifiable(_errorLogBuffer);
}
