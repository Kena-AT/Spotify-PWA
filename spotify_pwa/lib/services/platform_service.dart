import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class PlatformService {
  static const MethodChannel _channel = MethodChannel('com.kaye.spotify_pwa/platform');

  static Future<String> getPlatformVersion() async {
    try {
      final String version = await _channel.invokeMethod('getPlatformVersion');
      return version;
    } on PlatformException catch (e) {
      debugPrint('PlatformService getPlatformVersion error: ${e.message}');
      return 'Unknown';
    } catch (_) {
      return defaultTargetPlatform.name;
    }
  }

  static Future<int> getBatteryLevel() async {
    try {
      final int level = await _channel.invokeMethod('getBatteryLevel');
      return level;
    } on PlatformException catch (e) {
      debugPrint('PlatformService getBatteryLevel error: ${e.message}');
      return -1;
    } catch (_) {
      return -1;
    }
  }

  static Future<bool> isBatteryOptimizationDisabled() async {
    try {
      final bool disabled = await _channel.invokeMethod('isBatteryOptimizationDisabled');
      return disabled;
    } on PlatformException catch (e) {
      debugPrint('PlatformService isBatteryOptimizationDisabled error: ${e.message}');
      return false;
    } catch (_) {
      return false;
    }
  }
}
