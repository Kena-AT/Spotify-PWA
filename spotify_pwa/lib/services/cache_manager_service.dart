import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheInfo {
  final int totalBytes;
  final int tempBytes;
  final int appSupportBytes;

  const CacheInfo({
    this.totalBytes = 0,
    this.tempBytes = 0,
    this.appSupportBytes = 0,
  });

  String get formattedTotal => formatBytes(totalBytes);
  String get formattedTemp => formatBytes(tempBytes);
  String get formattedSupport => formatBytes(appSupportBytes);

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(1)} ${suffixes[i]}';
  }
}

class CacheManagerService extends ChangeNotifier {
  static const String _prefsKeyOfflineMode = 'sp_offline_mode_enabled';

  CacheInfo _cacheInfo = const CacheInfo();
  CacheInfo get cacheInfo => _cacheInfo;

  bool _isCalculating = false;
  bool get isCalculating => _isCalculating;

  bool _isOfflineMode = false;
  bool get isOfflineMode => _isOfflineMode;

  CacheManagerService() {
    _loadOfflineModePreference();
    refreshCacheSize();
  }

  Future<void> _loadOfflineModePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isOfflineMode = prefs.getBool(_prefsKeyOfflineMode) ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('[CacheManager] Failed to load offline mode pref: $e');
    }
  }

  Future<void> setOfflineMode(bool enabled) async {
    _isOfflineMode = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyOfflineMode, enabled);
    } catch (e) {
      debugPrint('[CacheManager] Failed to save offline mode pref: $e');
    }
  }

  Future<void> refreshCacheSize() async {
    _isCalculating = true;
    notifyListeners();

    try {
      int tempSize = 0;
      int supportSize = 0;

      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        tempSize = await _calculateDirectorySize(tempDir);
      }

      final supportDir = await getApplicationSupportDirectory();
      if (supportDir.existsSync()) {
        supportSize = await _calculateDirectorySize(supportDir);
      }

      _cacheInfo = CacheInfo(
        totalBytes: tempSize + supportSize,
        tempBytes: tempSize,
        appSupportBytes: supportSize,
      );
    } catch (e) {
      debugPrint('[CacheManager] Error calculating cache size: $e');
    } finally {
      _isCalculating = false;
      notifyListeners();
    }
  }

  Future<int> _calculateDirectorySize(Directory dir) async {
    int total = 0;
    try {
      if (!dir.existsSync()) return 0;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[CacheManager] Calculating dir size error: $e');
    }
    return total;
  }

  /// Clears temporary cache while preserving cookies/auth sessions
  Future<bool> clearMediaCache({InAppWebViewController? webViewController}) async {
    try {
      // 1. Clear InAppWebView disk cache
      if (webViewController != null) {
        await InAppWebViewController.clearAllCache();
      }

      // 2. Clear temp directory files
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        await for (final entity in tempDir.list()) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }

      await refreshCacheSize();
      return true;
    } catch (e) {
      debugPrint('[CacheManager] Failed to clear media cache: $e');
      return false;
    }
  }
}
