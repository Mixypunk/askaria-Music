import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

/// État de connexion au serveur Askaria, partagé par toute l'application.
///
/// Contrairement au cache HTTP (qui peut afficher des données périmées sans
/// réseau), ce service expose un **état fiable** : il sonde périodiquement
/// `/ping`, réagit au retour au premier plan, et est mis à jour par les
/// requêtes API elles-mêmes (succès → en ligne, échec réseau → hors ligne).
class ServerStatus extends ChangeNotifier with WidgetsBindingObserver {
  ServerStatus._();
  static final ServerStatus instance = ServerStatus._();

  String? _baseUrl;
  bool _offline = false;
  bool _observing = false;
  Timer? _timer;
  Future<bool>? _inFlight;

  bool get isOffline => _offline;
  bool get isOnline => !_offline;

  /// À appeler au démarrage (ou quand l'URL du serveur change).
  void configure(String baseUrl) => _baseUrl = baseUrl;

  void markOnline() {
    if (_offline) {
      _offline = false;
      notifyListeners();
    }
  }

  void markOffline() {
    if (!_offline) {
      _offline = true;
      notifyListeners();
    }
  }

  /// Sonde le serveur (dédupliquée : un seul appel à la fois).
  Future<bool> check() {
    final running = _inFlight;
    if (running != null) return running;
    final future = _probe();
    _inFlight = future;
    future.whenComplete(() => _inFlight = null);
    return future;
  }

  Future<bool> _probe() async {
    final base = _baseUrl;
    if (base == null || base.isEmpty) return true;
    final root = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;

    // `/ping` est la route système du serveur ; `/auth/ping` sert de secours
    // pour les anciennes versions. Un 4xx prouve que le serveur répond.
    for (final path in const ['/ping', '/auth/ping']) {
      try {
        final r = await http
            .get(Uri.parse('$root$path'))
            .timeout(const Duration(seconds: 4));
        if (r.statusCode < 500) {
          markOnline();
          return true;
        }
      } catch (_) {
        // Panne réseau : aucun chemin ne répondra, on évite un second timeout.
        break;
      }
    }
    markOffline();
    return false;
  }

  /// Vérifie l'état toutes les [interval] et à chaque retour au premier plan.
  void startAutoCheck({Duration interval = const Duration(seconds: 30)}) {
    _timer?.cancel();
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _timer = Timer.periodic(interval, (_) => check());
    check();
  }

  void stopAutoCheck() {
    _timer?.cancel();
    _timer = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) check();
  }
}
