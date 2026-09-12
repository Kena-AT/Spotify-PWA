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

  KeyboardShortcutService({required this.onAction});

  bool handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;

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
