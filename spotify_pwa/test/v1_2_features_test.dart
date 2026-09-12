import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_pwa/models/equalizer_preset.dart';
import 'package:spotify_pwa/models/sleep_timer_config.dart';
import 'package:spotify_pwa/services/cache_manager_service.dart';
import 'package:spotify_pwa/services/keyboard_service.dart';
import 'package:spotify_pwa/services/sleep_timer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Equalizer Models & Presets', () {
    test('Default presets contain expected presets', () {
      final presets = EqualizerPreset.defaultPresets;
      expect(presets.length, greaterThanOrEqualTo(6));
      expect(presets.any((p) => p.id == 'flat'), isTrue);
      expect(presets.any((p) => p.id == 'bass_boost'), isTrue);
      expect(presets.any((p) => p.id == 'rock'), isTrue);
    });

    test('EqualizerBand JSON serialization', () {
      const band = EqualizerBand(index: 0, label: '60 Hz', gain: 3.5);
      final json = band.toJson();
      final deserialized = EqualizerBand.fromJson(json);

      expect(deserialized.index, 0);
      expect(deserialized.label, '60 Hz');
      expect(deserialized.gain, 3.5);
    });
  });

  group('SleepTimerService Tests', () {
    late SleepTimerService service;

    setUp(() {
      service = SleepTimerService();
    });

    tearDown(() {
      service.dispose();
    });

    test('Initial state is inactive', () {
      expect(service.state.isActive, isFalse);
    });

    test('Start duration timer activates countdown', () {
      service.startDurationTimer(const Duration(minutes: 15));
      expect(service.state.isActive, isTrue);
      expect(service.state.mode, SleepTimerMode.duration);
      expect(service.state.remaining.inMinutes, 15);
      expect(service.state.formattedRemaining, '15:00');
    });

    test('Start end-of-track timer activates mode', () {
      service.startEndOfTrackTimer();
      expect(service.state.isActive, isTrue);
      expect(service.state.mode, SleepTimerMode.endOfTrack);
      expect(service.state.formattedRemaining, 'At end of track');
    });

    test('End of track triggers when track title changes', () {
      bool paused = false;
      service.onTimerFinished = () {
        paused = true;
      };

      service.startEndOfTrackTimer();

      // First track playing
      service.onPlaybackMetadataUpdated(
        title: 'Track A',
        isPlaying: true,
        position: 10000,
        duration: 180000,
      );
      expect(paused, isFalse);

      // Track switches to next track
      service.onPlaybackMetadataUpdated(
        title: 'Track B',
        isPlaying: true,
        position: 1000,
        duration: 200000,
      );
      expect(paused, isTrue);
      expect(service.state.isActive, isFalse);
    });

    test('Cancel timer resets state and restores volume', () {
      double? restoredVolume;
      service.onFadeVolume = (vol) {
        restoredVolume = vol;
      };

      service.startDurationTimer(const Duration(minutes: 5));
      expect(service.state.isActive, isTrue);

      service.cancelTimer();
      expect(service.state.isActive, isFalse);
      expect(restoredVolume, 1.0);
    });
  });

  group('CacheManagerService Tests', () {
    test('CacheInfo formatting works correctly', () {
      expect(CacheInfo.formatBytes(0), '0 B');
      expect(CacheInfo.formatBytes(1024), '1.0 KB');
      expect(CacheInfo.formatBytes(1048576 * 15), '15.0 MB');
    });
  });

  group('KeyboardShortcutService Tests', () {
    test('Maps hardware keys to proper actions', () {
      final List<ShortcutAction> actions = [];
      final service = KeyboardShortcutService(onAction: (a) => actions.add(a));

      // Space -> togglePlayPause
      bool handled = service.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.space,
          logicalKey: LogicalKeyboardKey.space,
          timeStamp: Duration.zero,
        ),
      );
      expect(handled, isTrue);
      expect(actions.last, ShortcutAction.togglePlayPause);

      // ArrowRight -> nextTrack
      handled = service.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.arrowRight,
          logicalKey: LogicalKeyboardKey.arrowRight,
          timeStamp: Duration.zero,
        ),
      );
      expect(handled, isTrue);
      expect(actions.last, ShortcutAction.nextTrack);

      // KeyS -> openSleepTimer
      handled = service.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyS,
          logicalKey: LogicalKeyboardKey.keyS,
          timeStamp: Duration.zero,
        ),
      );
      expect(handled, isTrue);
      expect(actions.last, ShortcutAction.openSleepTimer);

      // KeyE -> openEqualizer
      handled = service.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyE,
          logicalKey: LogicalKeyboardKey.keyE,
          timeStamp: Duration.zero,
        ),
      );
      expect(handled, isTrue);
      expect(actions.last, ShortcutAction.openEqualizer);

      // KeyD -> openCacheManager
      handled = service.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyD,
          logicalKey: LogicalKeyboardKey.keyD,
          timeStamp: Duration.zero,
        ),
      );
      expect(handled, isTrue);
      expect(actions.last, ShortcutAction.openCacheManager);
    });
  });
}
