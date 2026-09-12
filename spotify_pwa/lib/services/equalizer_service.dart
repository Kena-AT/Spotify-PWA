import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/equalizer_preset.dart';

class EqualizerService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('com.spotify.pwa/equalizer');
  static const String _prefsKeyPreset = 'sp_eq_selected_preset';
  static const String _prefsKeyBands = 'sp_eq_bands';
  static const String _prefsKeyBass = 'sp_eq_bass_boost';
  static const String _prefsKeyEnabled = 'sp_eq_enabled';

  bool _isEnabled = true;
  bool get isEnabled => _isEnabled;

  String _selectedPresetId = 'flat';
  String get selectedPresetId => _selectedPresetId;

  double _bassBoost = 0.0;
  double get bassBoost => _bassBoost;

  late List<EqualizerBand> _bands;
  List<EqualizerBand> get bands => List.unmodifiable(_bands);

  EqualizerService() {
    _initBands();
    _loadFromPreferences();
  }

  void _initBands() {
    const defaultLabels = ['60 Hz', '230 Hz', '910 Hz', '3.6 kHz', '14 kHz'];
    _bands = List.generate(
      5,
      (i) => EqualizerBand(
        index: i,
        label: defaultLabels[i],
        gain: 0.0,
      ),
    );
  }

  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_prefsKeyEnabled) ?? true;
      _selectedPresetId = prefs.getString(_prefsKeyPreset) ?? 'flat';
      _bassBoost = prefs.getDouble(_prefsKeyBass) ?? 0.0;

      final savedBandsJson = prefs.getString(_prefsKeyBands);
      if (savedBandsJson != null) {
        final List<dynamic> list = jsonDecode(savedBandsJson);
        _bands = list.map((item) => EqualizerBand.fromJson(item)).toList();
      } else {
        _applyPresetDirect(_selectedPresetId);
      }
      notifyListeners();
      _syncToNative();
    } catch (e) {
      debugPrint('[EqualizerService] Error loading preferences: $e');
    }
  }

  Future<void> _saveToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyEnabled, _isEnabled);
      await prefs.setString(_prefsKeyPreset, _selectedPresetId);
      await prefs.setDouble(_prefsKeyBass, _bassBoost);
      await prefs.setString(
        _prefsKeyBands,
        jsonEncode(_bands.map((b) => b.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('[EqualizerService] Error saving preferences: $e');
    }
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    notifyListeners();
    _saveToPreferences();
    _channel.invokeMethod('setEnabled', {'enabled': enabled}).catchError((_) {});
  }

  void selectPreset(String presetId) {
    _selectedPresetId = presetId;
    _applyPresetDirect(presetId);
    notifyListeners();
    _saveToPreferences();
    _syncToNative();
  }

  void _applyPresetDirect(String presetId) {
    final preset = EqualizerPreset.defaultPresets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => EqualizerPreset.defaultPresets.first,
    );

    for (int i = 0; i < _bands.length && i < preset.gains.length; i++) {
      _bands[i] = _bands[i].copyWith(gain: preset.gains[i]);
    }
    _bassBoost = preset.bassBoost;
  }

  void setBandGain(int index, double gain) {
    if (index < 0 || index >= _bands.length) return;
    _bands[index] = _bands[index].copyWith(gain: gain);
    _selectedPresetId = 'custom';
    notifyListeners();
    _saveToPreferences();
    _syncBandToNative(index, gain);
  }

  void setBassBoost(double strength) {
    _bassBoost = strength.clamp(0.0, 1.0);
    _selectedPresetId = 'custom';
    notifyListeners();
    _saveToPreferences();
    _channel.invokeMethod('setBassBoost', {'strength': _bassBoost}).catchError((_) {});
  }

  Future<bool> openSystemEqualizer() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('openSystemEqualizer');
      return result ?? false;
    } catch (e) {
      debugPrint('[EqualizerService] Failed to open system equalizer: $e');
      return false;
    }
  }

  void _syncBandToNative(int band, double gain) {
    _channel.invokeMethod('setBandGain', {
      'band': band,
      'gain': gain,
    }).catchError((_) {});
  }

  void _syncToNative() {
    _channel.invokeMethod('setEnabled', {'enabled': _isEnabled}).catchError((_) {});
    for (int i = 0; i < _bands.length; i++) {
      _syncBandToNative(i, _bands[i].gain);
    }
    _channel.invokeMethod('setBassBoost', {'strength': _bassBoost}).catchError((_) {});
  }

  /// JavaScript snippet to apply multi-band BiquadFilterNodes to HTML5 audio in WebView
  String get webAudioFilterScript {
    final gains = _bands.map((b) => b.gain).toList();
    final boost = _bassBoost;
    final enabled = _isEnabled;

    return '''
      (function() {
        if (!window.AudioContext && !window.webkitAudioContext) return;
        window.__spotifyEQState = {
          enabled: $enabled,
          gains: ${jsonEncode(gains)},
          bassBoost: $boost
        };
        // Signal existing hooked audio elements
        if (window.__updateSpotifyEQ) {
          window.__updateSpotifyEQ();
        }
      })();
    ''';
  }
}
