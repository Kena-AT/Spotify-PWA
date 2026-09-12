class EqualizerBand {
  final int index;
  final String label; // e.g. "60 Hz", "230 Hz", "910 Hz", "3.6 kHz", "14 kHz"
  final double gain; // in dB, range typically -10.0 to +10.0

  const EqualizerBand({
    required this.index,
    required this.label,
    required this.gain,
  });

  EqualizerBand copyWith({double? gain}) {
    return EqualizerBand(
      index: index,
      label: label,
      gain: gain ?? this.gain,
    );
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'label': label,
        'gain': gain,
      };

  factory EqualizerBand.fromJson(Map<String, dynamic> json) => EqualizerBand(
        index: json['index'] as int,
        label: json['label'] as String,
        gain: (json['gain'] as num).toDouble(),
      );
}

class EqualizerPreset {
  final String id;
  final String name;
  final List<double> gains; // 5 values for 60Hz, 230Hz, 910Hz, 3.6kHz, 14kHz
  final double bassBoost; // 0.0 to 1.0 (or 0 - 1000 mB)

  const EqualizerPreset({
    required this.id,
    required this.name,
    required this.gains,
    this.bassBoost = 0.0,
  });

  static const List<EqualizerPreset> defaultPresets = [
    EqualizerPreset(
      id: 'flat',
      name: 'Flat',
      gains: [0.0, 0.0, 0.0, 0.0, 0.0],
      bassBoost: 0.0,
    ),
    EqualizerPreset(
      id: 'bass_boost',
      name: 'Bass Boost',
      gains: [5.0, 3.5, 0.0, 0.0, 0.0],
      bassBoost: 0.7,
    ),
    EqualizerPreset(
      id: 'electronic',
      name: 'Electronic / EDM',
      gains: [4.5, 2.0, -1.0, 2.5, 4.0],
      bassBoost: 0.5,
    ),
    EqualizerPreset(
      id: 'rock',
      name: 'Rock',
      gains: [4.0, 2.0, -1.5, 2.0, 4.5],
      bassBoost: 0.3,
    ),
    EqualizerPreset(
      id: 'pop',
      name: 'Pop',
      gains: [-1.0, 2.0, 3.5, 2.0, -1.0],
      bassBoost: 0.2,
    ),
    EqualizerPreset(
      id: 'vocal',
      name: 'Vocal Booster',
      gains: [-2.0, 0.0, 4.0, 3.5, 0.5],
      bassBoost: 0.0,
    ),
    EqualizerPreset(
      id: 'classical',
      name: 'Classical',
      gains: [3.5, 2.5, -1.0, 2.5, 3.0],
      bassBoost: 0.1,
    ),
    EqualizerPreset(
      id: 'custom',
      name: 'Custom',
      gains: [0.0, 0.0, 0.0, 0.0, 0.0],
      bassBoost: 0.0,
    ),
  ];
}
