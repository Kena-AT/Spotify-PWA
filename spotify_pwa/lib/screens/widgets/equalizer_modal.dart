import 'package:flutter/material.dart';
import '../../models/equalizer_preset.dart';
import '../../services/equalizer_service.dart';

class EqualizerModal extends StatelessWidget {
  final EqualizerService equalizerService;

  const EqualizerModal({
    super.key,
    required this.equalizerService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: equalizerService,
      builder: (context, _) {
        final isEnabled = equalizerService.isEnabled;
        final bands = equalizerService.bands;
        final selectedPreset = equalizerService.selectedPresetId;
        final bassBoost = equalizerService.bassBoost;

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF181818),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SingleChildScrollView(
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
                const SizedBox(height: 16),

                // Title row & switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.equalizer, color: Color(0xFF1DB954), size: 26),
                        SizedBox(width: 10),
                        Text(
                          'Equalizer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: isEnabled,
                      activeTrackColor: const Color(0xFF1DB954),
                      onChanged: (val) {
                        equalizerService.setEnabled(val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Presets horizontal scroll
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: EqualizerPreset.defaultPresets.map((preset) {
                      final isSelected = selectedPreset == preset.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(preset.name),
                          selected: isSelected,
                          selectedColor: const Color(0xFF1DB954),
                          backgroundColor: const Color(0xFF282828),
                          labelStyle: TextStyle(
                            color: isSelected ? const Color(0xFF121212) : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isSelected ? const Color(0xFF1DB954) : Colors.transparent,
                            ),
                          ),
                          onSelected: isEnabled
                              ? (_) => equalizerService.selectPreset(preset.id)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // 5-band vertical sliders
                Opacity(
                  opacity: isEnabled ? 1.0 : 0.4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF202020),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '+10 dB',
                              style: TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                            Text(
                              selectedPreset.toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF1DB954),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const Text(
                              '-10 dB',
                              style: TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 160,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: bands.map((band) {
                              return Column(
                                children: [
                                  Text(
                                    '${band.gain > 0 ? '+' : ''}${band.gain.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Expanded(
                                    child: RotatedBox(
                                      quarterTurns: 3,
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 3,
                                          thumbShape: const RoundSliderThumbShape(
                                            enabledThumbRadius: 6,
                                          ),
                                          overlayShape: const RoundSliderOverlayShape(
                                            overlayRadius: 12,
                                          ),
                                          activeTrackColor: const Color(0xFF1DB954),
                                          inactiveTrackColor: const Color(0xFF3E3E3E),
                                          thumbColor: const Color(0xFF1DB954),
                                        ),
                                        child: Slider(
                                          value: band.gain,
                                          min: -10.0,
                                          max: 10.0,
                                          onChanged: isEnabled
                                              ? (val) => equalizerService.setBandGain(
                                                    band.index,
                                                    val,
                                                  )
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    band.label,
                                    style: const TextStyle(
                                      color: Color(0xFFB3B3B3),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Bass Boost Slider
                Opacity(
                  opacity: isEnabled ? 1.0 : 0.4,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF202020),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.speaker_group_outlined,
                                    color: Color(0xFF1DB954), size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Bass Boost',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${(bassBoost * 100).round()}%',
                              style: const TextStyle(
                                color: Color(0xFF1DB954),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFF1DB954),
                            inactiveTrackColor: const Color(0xFF3E3E3E),
                            thumbColor: const Color(0xFF1DB954),
                            trackHeight: 3,
                          ),
                          child: Slider(
                            value: bassBoost,
                            min: 0.0,
                            max: 1.0,
                            onChanged: isEnabled
                                ? (val) => equalizerService.setBassBoost(val)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // System Equalizer Launcher button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final launched = await equalizerService.openSystemEqualizer();
                      if (!launched && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Device does not have a dedicated system equalizer app.',
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.tune, size: 18, color: Color(0xFF1DB954)),
                    label: const Text(
                      'Open Android System Equalizer / Dolby',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF3E3E3E)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
