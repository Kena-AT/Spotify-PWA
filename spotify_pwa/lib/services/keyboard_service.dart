import 'package:flutter/services.dart';

enum ShortcutAction {
  togglePlayPause,
  nextTrack,
  previousTrack,
  volumeUp,
  volumeDown,
  toggleMute,
  openSleepTimer,
  openEqualizer,
  openCacheManager,
  showShortcutsHelp,
}

class KeyboardShortcutService {
  final void Function(ShortcutAction action) onAction;

  // Track repeated key events for long-press simulation on hardware volume keys.
  int _volumeUpRepeatCount = 0;
  int _volumeDownRepeatCount = 0;
  static const int _kLongPressRepeatThreshold = 4;

  KeyboardShortcutService({required this.onAction});

  bool handleKeyEvent(KeyEvent event) {
    final key = event.logicalKey;

    // ── Long-press volume keys for track skip (phone hardware buttons) ──
    if (event is KeyRepeatEvent) {
      if (key == LogicalKeyboardKey.audioVolumeUp) {
        _volumeUpRepeatCount++;
        if (_volumeUpRepeatCount == _kLongPressRepeatThreshold) {
          onAction(ShortcutAction.nextTrack);
          return true;
        }
        return false;
      } else if (key == LogicalKeyboardKey.audioVolumeDown) {
        _volumeDownRepeatCount++;
        if (_volumeDownRepeatCount == _kLongPressRepeatThreshold) {
          onAction(ShortcutAction.previousTrack);
          return true;
        }
        return false;
      }
    }

    if (event is KeyUpEvent) {
      if (key == LogicalKeyboardKey.audioVolumeUp) _volumeUpRepeatCount = 0;
      if (key == LogicalKeyboardKey.audioVolumeDown) _volumeDownRepeatCount = 0;
    }

    if (event is! KeyDownEvent) return false;

    // ── PC / Desktop keyboard shortcuts ──
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      onAction(ShortcutAction.togglePlayPause);
      return true;
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.mediaTrackNext) {
      onAction(ShortcutAction.nextTrack);
      return true;
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.mediaTrackPrevious) {
      onAction(ShortcutAction.previousTrack);
      return true;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      onAction(ShortcutAction.volumeUp);
      return true;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      onAction(ShortcutAction.volumeDown);
      return true;
    } else if (key == LogicalKeyboardKey.keyM) {
      onAction(ShortcutAction.toggleMute);
      return true;
    } else if (key == LogicalKeyboardKey.keyS) {
      onAction(ShortcutAction.openSleepTimer);
      return true;
    } else if (key == LogicalKeyboardKey.keyE) {
      onAction(ShortcutAction.openEqualizer);
      return true;
    } else if (key == LogicalKeyboardKey.keyD) {
      onAction(ShortcutAction.openCacheManager);
      return true;
    } else if (key == LogicalKeyboardKey.slash) {
      onAction(ShortcutAction.showShortcutsHelp);
      return true;
    }

    return false;
  }
}
