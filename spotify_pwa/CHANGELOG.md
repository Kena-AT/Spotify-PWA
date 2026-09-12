# Release Notes

## v1.0.0 - Initial Release
- **Core Engine:** Integrated `flutter_inappwebview` to wrap the open.spotify.com PWA.
- **Ad-Blocker Engine:** 
  - CSS injection to hide visual ad placements and upgrade buttons.
  - Network interception for telemetry and ad-fetching API endpoints.
  - Media observer that detects audio ads, immediately mutes them, and accelerates playback (16x) to skip them.
- **Background Playback Integration:**
  - Implemented `audio_service` to allow music playback while the app is in the background or screen is off.
  - Built a custom JavaScript `PlaybackBridge` to extract media session metadata (title, artist, album art) and playback state from the DOM and sync it to the native Android notification controls.
- **Quality of Life:**
  - Deep link routing to seamlessly open Spotify links inside the app.
  - `ConnectivityService` to manage offline gracefully and auto-refresh upon reconnection.
  - Crashlytics and Analytics integrated for stability monitoring.
