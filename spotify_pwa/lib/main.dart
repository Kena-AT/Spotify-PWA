import 'package:flutter/material.dart';
import 'services/theme_service.dart';
import 'services/crashlytics_service.dart';
import 'services/analytics_service.dart';
import 'screens/webview_page.dart';

final ThemeService themeService = ThemeService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize crash tracking
  await CrashlyticsService.initialize();

  // Log app launch event
  AnalyticsService.logAppOpen();

  runApp(const SpotifyPWAApp());
}

class SpotifyPWAApp extends StatelessWidget {
  const SpotifyPWAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        return MaterialApp(
          title: 'Spotify',
          theme: ThemeService.lightTheme,
          darkTheme: ThemeService.darkTheme,
          themeMode: themeService.themeMode,
          home: const SpotifyWebViewPage(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
