import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/sleep_timer_config.dart';

typedef VolumeFadeCallback = void Function(double volumeFraction);
typedef TimerFinishCallback = void Function();

class SleepTimerService extends ChangeNotifier {
  SleepTimerState _state = const SleepTimerState();
  SleepTimerState get state => _state;

  Timer? _timer;
  VolumeFadeCallback? onFadeVolume;
  TimerFinishCallback? onTimerFinished;

  String? _currentTrackTitle;

  void startDurationTimer(Duration duration) {
    cancelTimer();
    _state = SleepTimerState(
      isActive: true,
      mode: SleepTimerMode.duration,
      totalDuration: duration,
      remaining: duration,
      isFading: false,
    );
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void startEndOfTrackTimer() {
    cancelTimer();
    _state = const SleepTimerState(
      isActive: true,
      mode: SleepTimerMode.endOfTrack,
      totalDuration: Duration.zero,
      remaining: Duration.zero,
      isFading: false,
    );
    notifyListeners();
  }

  void cancelTimer() {
    _timer?.cancel();
    _timer = null;
    if (_state.isActive) {
      _state = const SleepTimerState(isActive: false);
      notifyListeners();
      // Restore full volume if timer cancelled during fade
      onFadeVolume?.call(1.0);
    }
  }

  void _onTick(Timer timer) {
    if (!_state.isActive || _state.mode != SleepTimerMode.duration) {
      timer.cancel();
      return;
    }

    final newRemainingSeconds = _state.remaining.inSeconds - 1;
    if (newRemainingSeconds <= 0) {
      _triggerCompletion();
      return;
    }

    final remaining = Duration(seconds: newRemainingSeconds);
    bool isFading = false;

    // Gentle fade out during the last 15 seconds
    if (newRemainingSeconds <= 15) {
      isFading = true;
      final fraction = (newRemainingSeconds / 15.0).clamp(0.0, 1.0);
      onFadeVolume?.call(fraction);
    }

    _state = _state.copyWith(
      remaining: remaining,
      isFading: isFading,
    );
    notifyListeners();
  }

  /// Hook into now-playing state updates from WebView / Native bridge
  void onPlaybackMetadataUpdated({
    required String title,
    required bool isPlaying,
    int? position,
    int? duration,
  }) {
    if (!_state.isActive || _state.mode != SleepTimerMode.endOfTrack) {
      _currentTrackTitle = title;
      return;
    }

    // 1. If track title changed after we set the timer, track has completed!
    if (_currentTrackTitle != null &&
        _currentTrackTitle != title &&
        title != 'Spotify' &&
        title.isNotEmpty) {
      _triggerCompletion();
      return;
    }

    _currentTrackTitle = title;

    // 2. Check position within duration threshold (e.g. within last 2 seconds)
    if (duration != null && position != null && duration > 0) {
      if (position >= duration - 2000) {
        _triggerCompletion();
      }
    }
  }

  void _triggerCompletion() {
    _timer?.cancel();
    _timer = null;
    _state = const SleepTimerState(isActive: false);
    notifyListeners();
    onFadeVolume?.call(0.0);
    onTimerFinished?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
