import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Presets EQ ────────────────────────────────────────────────────────────────
class EqPreset {
  final String name;
  final List<double> gains; // dB par bande, longueur variable selon l\'appareil
  const EqPreset(this.name, this.gains);

  // Normalise les gains à N bandes par interpolation linéaire
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

const _kPresets = [
  EqPreset("Flat",       [0, 0, 0, 0, 0]),
  EqPreset("Bass Boost", [6, 4, 0, 0, 0]),
  EqPreset("Rock",       [4, 1, -1, 2, 4]),
  EqPreset("Pop",        [-1, 2, 4, 2, -1]),
  EqPreset("Jazz",       [3, 0, 2, 3, 4]),
  EqPreset("Classique",  [4, 3, -2, 3, 4]),
  EqPreset("Vocal",      [-2, 0, 4, 3, 1]),
  EqPreset("Electro",    [4, 3, 0, 3, 4]),
];

List<EqPreset> get kEqPresets => _kPresets;

// ── EqService ─────────────────────────────────────────────────────────────────
class EqService extends ChangeNotifier {
  static EqService? _instance;
  static EqService get instance => _instance ??= EqService._();
  EqService._();

  AndroidEqualizer? _eq;
  AndroidLoudnessEnhancer? _loudness;
  AudioEffect? _effect;

  bool _enabled    = false;
  int  _presetIdx  = 0;       // 0 = Flat
  List<double> _gains = [];   // valeurs courantes en dB

  bool             get enabled   => _enabled;
  int              get presetIdx => _presetIdx;
  List<double>     get gains     => List.unmodifiable(_gains);
  List<EqPreset>   get presets   => kEqPresets;
  String           get presetName => kEqPresets[_presetIdx].name;
  AndroidEqualizer? get equalizer => _eq;

  // Appeler depuis PlayerProvider après création de l\'AudioPlayer
  Future<void> init(AudioPlayer player) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      _eq      = AndroidEqualizer();
      _loudness= AndroidLoudnessEnhancer();
      _effect  = AudioEffect(audioEffects: [_eq!, _loudness!]);
      // Injecter l\'EQ dans le player
      await player.setAudioSource(
        player.audioSource ?? ConcatenatingAudioSource(children: []),
        audioEffects: _effect,
        preload: false,
      );
      final params = await _eq!.parameters;
      final bands  = params.bands;
      _gains = List<double>.filled(bands.length, 0.0);
      await _loadPrefs(bands.length);
    } catch (e) {
      debugPrint("EQ init error: \$e");
    }
  }

  Future<void> _loadPrefs(int bandCount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled   = prefs.getBool("eq_enabled") ?? false;
      _presetIdx = prefs.getInt("eq_preset")   ?? 0;
      final raw  = prefs.getString("eq_gains");
      if (raw != null) {
        final list = (jsonDecode(raw) as List).map((v) => (v as num).toDouble()).toList();
        if (list.length == bandCount) {
          _gains = list;
        } else {
          _gains = kEqPresets[_presetIdx].forBands(bandCount);
        }
      } else {
        _gains = kEqPresets[_presetIdx].forBands(bandCount);
      }
      await _applyGains();
    } catch (e) {
      debugPrint("EQ loadPrefs: \$e");
    }
  }

  Future<void> setEnabled(bool v) async {
    _enabled = v;
    await _applyGains();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("eq_enabled", v);
    notifyListeners();
  }

  Future<void> setPreset(int idx) async {
    _presetIdx = idx.clamp(0, kEqPresets.length - 1);
    _gains = kEqPresets[_presetIdx].forBands(_gains.length);
    await _applyGains();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("eq_preset", _presetIdx);
    await prefs.setString("eq_gains", jsonEncode(_gains));
    notifyListeners();
  }

  Future<void> setBandGain(int band, double db) async {
    if (band < 0 || band >= _gains.length) return;
    _gains[band] = db.clamp(-15.0, 15.0);
    _presetIdx = 0; // passe à "Custom" (Flat comme base)
    await _applyGains();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("eq_gains", jsonEncode(_gains));
    notifyListeners();
  }

  Future<void> _applyGains() async {
    if (_eq == null) return;
    try {
      final params = await _eq!.parameters;
      final bands  = params.bands;
      for (int i = 0; i < bands.length && i < _gains.length; i++) {
        await bands[i].setGain(_enabled ? _gains[i] : 0.0);
      }
    } catch (e) {
      debugPrint("EQ applyGains: \$e");
    }
  }

  // Noms des fréquences (pour l\'affichage — valeurs courantes depuis Android)
  Future<List<String>> getBandLabels() async {
    if (_eq == null) return [];
    try {
      final params = await _eq!.parameters;
      return params.bands.map((b) {
        final hz = b.centerFrequency.round();
        return hz >= 1000 ? "${(hz / 1000).toStringAsFixed(hz % 1000 == 0 ? 0 : 1)}k" : "$hz";
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
