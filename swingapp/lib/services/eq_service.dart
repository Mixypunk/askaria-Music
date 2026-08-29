import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EqPreset {
  final String name;
  final List<double> gains;
  const EqPreset(this.name, this.gains);

  List<double> forBands(int n) {
    if (gains.length == n) return gains;
    final result = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      final ratio = i / (n - 1);
      final idx   = ratio * (gains.length - 1);
      final lo    = gains[idx.floor()];
      final hi    = gains[idx.ceil().clamp(0, gains.length - 1)];
      result[i]   = lo + (hi - lo) * (idx - idx.floor());
    }
    return result;
  }
}

const List<EqPreset> kEqPresets = [
  EqPreset("Flat",       [0,  0,  0,  0,  0]),
  EqPreset("Bass Boost", [6,  4,  0,  0,  0]),
  EqPreset("Rock",       [4,  1, -1,  2,  4]),
  EqPreset("Pop",        [-1, 2,  4,  2, -1]),
  EqPreset("Jazz",       [3,  0,  2,  3,  4]),
  EqPreset("Classique",  [4,  3, -2,  3,  4]),
  EqPreset("Vocal",      [-2, 0,  4,  3,  1]),
  EqPreset("Electro",    [4,  3,  0,  3,  4]),
];

class EqService extends ChangeNotifier {
  static EqService? _instance;
  static EqService get instance => _instance ??= EqService._();
  EqService._();

  // L'equalizer doit être créé AVANT l'AudioPlayer
  // et passé dans AudioPipeline au constructeur
  final AndroidEqualizer _eq = AndroidEqualizer();

  bool _supported = defaultTargetPlatform == TargetPlatform.android;
  bool _enabled   = false;
  int  _presetIdx = 0;
  List<double> _gains = [];
  List<String> _labels = [];

  bool get enabled    => _enabled;
  bool get supported  => _supported;
  int  get presetIdx  => _presetIdx;
  List<double>   get gains   => List.unmodifiable(_gains);
  List<String>   get labels  => List.unmodifiable(_labels);
  List<EqPreset> get presets => kEqPresets;
  String get presetName      => kEqPresets[_presetIdx].name;

  // Retourne l'equalizer à passer dans AudioPipeline
  AndroidEqualizer get equalizer => _eq;

  // Appeler APRÈS qu'une source audio a été chargée
  Future<void> loadSettings() async {
    if (!_supported) return;
    try {
      final params = await _eq.parameters;
      final bands  = params.bands;
      _labels = bands.map((b) {
        final hz = b.centerFrequency.round();
        return hz >= 1000
            ? "\${(hz/1000).toStringAsFixed(hz % 1000 == 0 ? 0 : 1)}k"
            : "\$hz";
      }).toList();

      final prefs = await SharedPreferences.getInstance();
      _enabled    = prefs.getBool("eq_enabled")  ?? false;
      _presetIdx  = prefs.getInt("eq_preset")    ?? 0;
      final raw   = prefs.getString("eq_gains");

      if (raw != null) {
        final list = (jsonDecode(raw) as List).map((v) => (v as num).toDouble()).toList();
        _gains = list.length == bands.length
            ? list
            : kEqPresets[_presetIdx].forBands(bands.length);
      } else {
        _gains = kEqPresets[_presetIdx].forBands(bands.length);
      }
      await _applyGains();
      notifyListeners();
    } catch (e) {
      debugPrint("EQ loadSettings: \$e");
      _supported = false;
    }
  }

  Future<List<String>> getBandLabels() async => _labels;

  Future<void> setEnabled(bool v) async {
    _enabled = v;
    await _applyGains();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("eq_enabled", v);
    notifyListeners();
  }

  Future<void> setPreset(int idx) async {
    _presetIdx = idx.clamp(0, kEqPresets.length - 1);
    _gains     = kEqPresets[_presetIdx].forBands(_gains.isEmpty ? 5 : _gains.length);
    await _applyGains();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("eq_preset", _presetIdx);
    await prefs.setString("eq_gains", jsonEncode(_gains));
    notifyListeners();
  }

  Future<void> setBandGain(int band, double db) async {
    if (band < 0 || band >= _gains.length) return;
    _gains[band] = db.clamp(-15.0, 15.0);
    await _applyGains();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("eq_gains", jsonEncode(_gains));
    notifyListeners();
  }

  Future<void> _applyGains() async {
    if (!_supported) return;
    try {
      final params = await _eq.parameters;
      final bands  = params.bands;
      await _eq.setEnabled(_enabled);
      for (int i = 0; i < bands.length && i < _gains.length; i++) {
        await bands[i].setGain(_enabled ? _gains[i] : 0.0);
      }
    } catch (e) {
      debugPrint("EQ applyGains: \$e");
    }
  }
}
