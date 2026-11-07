import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NetworkQualityService extends ChangeNotifier {
  static NetworkQualityService? _instance;
  static NetworkQualityService get instance =>
      _instance ??= NetworkQualityService._();
  NetworkQualityService._();

  bool _autoQuality = false;
  String _manualQuality = 'high'; // 'low', 'medium', 'high', 'lossless'
  String _effectiveQuality = 'high';
  StreamSubscription? _connSub;

  bool get autoQuality => _autoQuality;
  String get manualQuality => _manualQuality;
  String get currentQuality => _effectiveQuality;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _autoQuality = prefs.getBool('auto_quality') ?? false;
    _manualQuality = prefs.getString('audio_quality') ?? 'high';

    await _updateEffectiveQuality();

    _connSub?.cancel();
    _connSub = Connectivity().onConnectivityChanged.listen((_) {
      if (_autoQuality) {
        _updateEffectiveQuality();
      }
    });
  }

  Future<void> _updateEffectiveQuality() async {
    if (!_autoQuality) {
      if (_effectiveQuality != _manualQuality) {
        _effectiveQuality = _manualQuality;
        notifyListeners();
      }
      return;
    }

    try {
      final result = await Connectivity().checkConnectivity();
      String calculated;
      if (result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.ethernet)) {
        calculated = 'high';   // WiFi / Ethernet → 320 kbps
      } else if (result.contains(ConnectivityResult.mobile)) {
        calculated = 'medium'; // Données mobiles → 192 kbps
      } else {
        calculated = 'low';    // Pas de connexion → 128 kbps
      }
      if (_effectiveQuality != calculated) {
        _effectiveQuality = calculated;
        notifyListeners();
      }
    } catch (_) {
      _effectiveQuality = _manualQuality;
    }
  }

  Future<void> setAutoQuality(bool v) async {
    if (_autoQuality == v) return;
    _autoQuality = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_quality', v);
    await _updateEffectiveQuality();
  }

  Future<void> setAudioQuality(String quality) async {
    if (!{'low', 'medium', 'high', 'lossless'}.contains(quality)) return;
    if (_manualQuality == quality) return;
    _manualQuality = quality;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('audio_quality', quality);
    await _updateEffectiveQuality();
  }

  /// Retourne la qualité adaptée au réseau actuel
  Future<String> getQuality() async {
    await _updateEffectiveQuality();
    return _effectiveQuality;
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }
}
