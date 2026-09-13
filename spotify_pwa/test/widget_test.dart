import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify_pwa/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ThemeService initializes with expected themes', () async {
    SharedPreferences.setMockInitialValues({});
    final themeService = ThemeService();

    expect(themeService.themeMode, ThemeMode.dark);
    expect(ThemeService.darkTheme.scaffoldBackgroundColor, const Color(0xFF191414));
    expect(ThemeService.darkTheme.colorScheme.primary, const Color(0xFF1DB954));
    expect(ThemeService.lightTheme.colorScheme.primary, const Color(0xFF1DB954));
  });
}
