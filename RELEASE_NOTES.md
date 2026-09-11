# Release Notes - Spotify PWA Wrapper

## v1.1.0 (Current Release) - *Background Audio & System Enhancements*

### 🌟 New Features
- **Native Android Background Audio Service**: Seamless audio playback continues when app is minimized, screen is locked, or other apps are opened.
- **Media Notification Controls**: Play, Pause, Next, Previous, and Album Art rendered in Android notification shade and lock screen via `MediaSessionCompat`.
- **Ad & Visual Banner Filtering**: Automated DOM observer silences audio ads, fast-forwards ad segments, and hides intrusive upgrade popups.
- **Deep Link Handling**: Support for `spotify://` link schemes and `open.spotify.com` web URLs.
- **Dynamic Theme System**: Support for Dark, Light, and System theme modes with `SharedPreferences` persistence.
- **Diagnostics & Analytics**: Built-in `CrashlyticsService` and `AnalyticsService` for monitoring app stability and user engagement.

### 🐛 Bug Fixes & Stability
- Improved back button navigation (`PopScope`) to traverse webview history before exiting app.
- Added 15-second loading timeout watchdog to dismiss spinner on poor connections.
- Handled network transitions (WiFi → Cellular) with automatic webview session recovery.

---

## v1.0.0 - *Initial Release*

### 🚀 Initial Features
- Flutter-powered PWA wrapper embedding Spotify Web Player.
- Material 3 Spotify dark mode design system.
- Offline fallback UI (`offline.html`) with internet reconnection handler.
- Adaptive viewport injection script for edge-to-edge mobile screens.
- Release APK and AAB build pipeline configured with keystore signing.
