enum SleepTimerMode {
  duration,
  endOfTrack,
}

class SleepTimerPreset {
  final String label;
  final Duration? duration;
  final SleepTimerMode mode;

  const SleepTimerPreset({
    required this.label,
    this.duration,
    this.mode = SleepTimerMode.duration,
  });

  static const List<SleepTimerPreset> presets = [
    SleepTimerPreset(label: '5 min', duration: Duration(minutes: 5)),
    SleepTimerPreset(label: '15 min', duration: Duration(minutes: 15)),
    SleepTimerPreset(label: '30 min', duration: Duration(minutes: 30)),
    SleepTimerPreset(label: '45 min', duration: Duration(minutes: 45)),
    SleepTimerPreset(label: '1 hour', duration: Duration(hours: 1)),
    SleepTimerPreset(label: 'End of Track', mode: SleepTimerMode.endOfTrack),
  ];
}

class SleepTimerState {
  final bool isActive;
  final SleepTimerMode mode;
  final Duration totalDuration;
  final Duration remaining;
  final bool isFading;

  const SleepTimerState({
    this.isActive = false,
    this.mode = SleepTimerMode.duration,
    this.totalDuration = Duration.zero,
    this.remaining = Duration.zero,
    this.isFading = false,
  });

  SleepTimerState copyWith({
    bool? isActive,
    SleepTimerMode? mode,
    Duration? totalDuration,
    Duration? remaining,
    bool? isFading,
  }) {
    return SleepTimerState(
      isActive: isActive ?? this.isActive,
      mode: mode ?? this.mode,
      totalDuration: totalDuration ?? this.totalDuration,
      remaining: remaining ?? this.remaining,
      isFading: isFading ?? this.isFading,
    );
  }

  String get formattedRemaining {
    if (!isActive) return '';
    if (mode == SleepTimerMode.endOfTrack) return 'At end of track';
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
