import 'package:flutter/material.dart';
import 'screens/webview_page.dart';

void main() {
  runApp(const SpotifyPWAApp());
}

class SpotifyPWAApp extends StatelessWidget {
  const SpotifyPWAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spotify',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF1DB954), // Spotify Green
        scaffoldBackgroundColor: const Color(0xFF191414), // Dark Gray
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF191414),
          foregroundColor: Color(0xFFFFFFFF),
          elevation: 0,
        ),
      ),
      home: const SpotifyWebViewPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
