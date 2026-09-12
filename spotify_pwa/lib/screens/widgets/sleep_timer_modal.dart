import 'package:flutter/material.dart';
import '../../models/sleep_timer_config.dart';
import '../../services/sleep_timer_service.dart';

class SleepTimerModal extends StatelessWidget {
  final SleepTimerService sleepTimerService;

  const SleepTimerModal({
    super.key,
    required this.sleepTimerService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sleepTimerService,
      builder: (context, _) {
        final state = sleepTimerService.state;

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF181818),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bedtime_outlined, color: Color(0xFF1DB954), size: 26),
                      SizedBox(width: 10),
                      Text(
                        'Sleep Timer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (state.isActive)
                    TextButton(
                      onPressed: () {
                        sleepTimerService.cancelTimer();
                      },
                      child: const Text(
                        'Turn Off',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (state.isActive) ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF242424),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: state.isFading ? Colors.orangeAccent : const Color(0xFF1DB954),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        state.formattedRemaining,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state.isFading
                            ? 'Fading volume out...'
                            : (state.mode == SleepTimerMode.endOfTrack
                                ? 'Audio will stop when track ends'
                                : 'Music will pause when timer expires'),
                        style: TextStyle(
                          color: state.isFading ? Colors.orangeAccent : const Color(0xFFB3B3B3),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Stop audio in',
                  style: TextStyle(
                    color: Color(0xFFB3B3B3),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SleepTimerPreset.presets.map((preset) {
                  final isSelected = state.isActive &&
                      ((preset.mode == SleepTimerMode.endOfTrack &&
                              state.mode == SleepTimerMode.endOfTrack) ||
                          (preset.duration != null &&
                              state.totalDuration == preset.duration));

                  return ChoiceChip(
                    label: Text(preset.label),
                    selected: isSelected,
                    selectedColor: const Color(0xFF1DB954),
                    backgroundColor: const Color(0xFF282828),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF121212) : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF1DB954) : Colors.transparent,
                      ),
                    ),
                    onSelected: (selected) {
                      if (preset.mode == SleepTimerMode.endOfTrack) {
                        sleepTimerService.startEndOfTrackTimer();
                      } else if (preset.duration != null) {
                        sleepTimerService.startDurationTimer(preset.duration!);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
