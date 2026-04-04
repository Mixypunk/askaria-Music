import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class NetworkQualityService {
  static NetworkQualityService? _instance;
  static NetworkQualityService get instance =>
      _instance ??= NetworkQualityService._();
  NetworkQualityService._();

  bool _autoQuality = false;
  bool get autoQuality => _autoQuality;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _autoQuality = prefs.getBool('auto_quality') ?? false;
  }

  Future<void> setAutoQuality(bool v) async {
    _autoQuality = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_quality', v);
  }

  /// Retourne la qualité adaptée au réseau actuel
  /// Si auto désactivé, retourne la qualité manuelle depuis les prefs
  Future<String> getQuality() async {
    if (!_autoQuality) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('audio_quality') ?? 'high';
    }
    try {
      final result = await Connectivity().checkConnectivity();
      if (result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.ethernet)) {
        return 'high';   // WiFi → qualité max
      } else if (result.contains(ConnectivityResult.mobile)) {
        return 'medium'; // 4G → 192k
      } else {
        return 'low';    // 2G/connexion faible → 96k
      }
    } catch (_) {
      return 'high';
    }
  }
}
