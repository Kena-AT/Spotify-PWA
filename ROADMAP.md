# Project Roadmap - Spotify PWA Wrapper

## Overview

This document highlights planned feature milestones and future enhancements for Spotify PWA Wrapper.

---

## 🟢 v1.0.0 — MVP Core Player (Completed)
- [x] Embedded WebView player loading `open.spotify.com`.
- [x] Responsive CSS viewport injection.
- [x] Custom offline fallback screen & connectivity detector.
- [x] Signed release APK & AAB builds.

---

## 🟢 v1.1.0 — Background Audio & System Enhancements (Completed)
- [x] Native Android `AudioService` foreground notification with `MediaSessionCompat`.
- [x] Web JavaScript bridge observing Spotify DOM playback states.
- [x] Cosmetic and network API ad filtering.
- [x] Deep link handling for `spotify://` URIs and `open.spotify.com` links.
- [x] Theme system with persistence (Dark / Light / System).
- [x] `CrashlyticsService` and `AnalyticsService` diagnostics wrappers.

---

## 🟡 v1.2.0 — Planned Near-Term Features
- [ ] **Custom Equalizer Controls**: Native Android audio equalizer integration.
- [ ] **Download Management**: Cache audio streams for offline listening where permitted.
- [ ] **Sleep Timer**: Built-in sleep timer directly accessible from app settings.
- [ ] **Custom Keyboard Shortcuts**: Desktop / tablet physical keyboard media key support.

---

## 🔵 v2.0.0 — Future Enhancements
- [ ] **Multi-account Switching**: Fast account profile switcher.
- [ ] **Widget Integration**: Android home screen playback widget.
- [ ] **CarPlay / Android Auto**: Basic media session compatibility for automotive displays.
