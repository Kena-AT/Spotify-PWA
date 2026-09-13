# Spotify PWA Wrapper

A lightweight, feature-rich Flutter wrapper for the Spotify web application. This project converts the Spotify web experience into a native-feeling mobile application using `InAppWebView`.

## Features

- **Seamless Web Integration:** Full access to the Spotify web player in a full-screen, native-like environment.
- **Advanced Ad-Blocking:** Multi-layer ad-blocking engine that removes visual ads, intercepts ad-tracking network requests, and auto-mutes/fast-forwards through audio ads.
- **Background Audio Support:** Continues playing music even when the app is in the background. Syncs playback state (Now Playing metadata) with native Android media controls.
- **Connectivity Handling:** Automatically detects network drops and reloads the player when you come back online.
- **Custom Equalizer:** Native Android audio equalizer integration injected dynamically.
- **Sleep Timer:** Built-in sleep timer with countdown and gentle volume fading.
- **Offline Caching (Downloads):** Cache inspector and offline-mode toggle for downloaded streams.
- **Shortcuts & Gestures:** Full support for desktop keyboard shortcuts, plus phone-specific swipe gestures (left/right for track skipping, down for Quick Tools) and hardware volume button long-press interception.
- **Deep Linking:** Properly intercepts and routes Spotify URLs.

## Download
You can download the latest compiled Android APK directly from this repository:
📥 [Download Spotify_PWA 1.2.0.apk](./Spotify_PWA\ 1.2.0.apk)

## Development
To build the app yourself:
1. Ensure you have the Flutter SDK installed.
2. Clone the repository.
3. Run `flutter pub get` to install dependencies.
4. Run `flutter build apk` to generate the release APK.
