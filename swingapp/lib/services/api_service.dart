import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/song.dart';
import '../models/album.dart';

import 'logger_service.dart';
import 'resilient_http_client.dart';
import 'api_cache_service.dart';

part 'api/api_music.dart';
part 'api/api_playlists.dart';
part 'api/api_media.dart';
part 'api/api_stats.dart';
part 'api/api_profile.dart';
part 'api/api_radio.dart';
part 'api/api_offline.dart';


// ── Fonctions top-level pour compute() ────────────────────────────────────────
// Doivent être top-level (pas des méthodes) pour être envoyées dans un isolate.

List<Album> _decodeAlbums(String body) {
  final data = json.decode(body) as Map<String, dynamic>;
  final items = data['items'] ?? data['albums'] ?? [];
  return (items as List).map((e) => Album.fromJson(e as Map<String, dynamic>)).toList();
}

List<Artist> _decodeArtists(String body) {
  final data = json.decode(body) as Map<String, dynamic>;
  final items = data['items'] ?? data['artists'] ?? [];
  return (items as List).map((e) => Artist.fromJson(e as Map<String, dynamic>)).toList();
}

List<Song> _decodeSongs(String body) {
  final data = json.decode(body) as Map<String, dynamic>;
  final tracks = data['tracks'] ?? [];
  return (tracks as List).map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
}



class SwingApiService {
  static final SwingApiService _instance = SwingApiService._internal();
  factory SwingApiService() => _instance;
  SwingApiService._internal();

  final _client = ResilientHttpClient();


  String _baseUrl = 'https://askaria-music.duckdns.org';
  final _secure = const FlutterSecureStorage();
  String? _accessToken;
  String? _refreshToken;
  String? _streamToken;
  DateTime? _streamTokenExpiry;
  bool _canDownload = false;

  /// Cache du chemin du répertoire hors-ligne (initialisé au démarrage)
  String? offlineDirPath;

  String get baseUrl => _baseUrl;
  bool get isLoggedIn => _accessToken != null;
  bool get canDownload => _canDownload;

  // Headers avec Bearer token (format utilisé par l'app officielle)
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  /// Retourne un token court (15min) dédié au streaming audio.
  /// Évite d'exposer l'access token principal dans les URLs.
  Future<String> _getStreamToken() async {
    final now = DateTime.now();
    // Réutiliser si encore valide (marge de 2 minutes)
    if (_streamToken != null &&
        _streamTokenExpiry != null &&
        _streamTokenExpiry!.isAfter(now.add(const Duration(minutes: 2)))) {
      return _streamToken!;
    }
    try {
      final r = await _authedGet(Uri.parse('$_baseUrl/auth/stream-token'));
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        _streamToken = data['stream_token'] as String?;
        _streamTokenExpiry = now.add(const Duration(minutes: 13));
        if (_streamToken != null) return _streamToken!;
      }
    } catch (e) { LoggerService.warning('Silent error caught in api_service.dart', e); }
    // Fallback : access token si stream-token indispo
    return _accessToken ?? '';
  }

  // ── SETTINGS ───────────────────────────────────────────────────────────
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('server_url') ?? 'https://askaria-music.duckdns.org';
    if (_baseUrl.endsWith('/')) _baseUrl = _baseUrl.substring(0, _baseUrl.length - 1);
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      offlineDirPath = '${dir.path}/offline';
    } catch (e) { LoggerService.warning('Silent error caught in api_service.dart', e); }

    // Tokens chiffrés dans SecureStorage
    _accessToken  = await _secure.read(key: 'access_token');
    _refreshToken = await _secure.read(key: 'refresh_token');
    // Migration : lire l'ancien token non chiffré si présent
    if (_accessToken == null) {
      _accessToken = prefs.getString('access_token');
      if (_accessToken != null) {
        await _secure.write(key: 'access_token', value: _accessToken!);
        await prefs.remove('access_token');
      }
    }
  }

  Future<void> saveUrl(String url) async {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', _baseUrl);
  }

  Future<void> _storeTokens(String access, String? refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    // Stockage chiffré via Keystore Android
    await _secure.write(key: 'access_token',  value: access);
    if (refresh != null) {
      await _secure.write(key: 'refresh_token', value: refresh);
    }
  }

  // ── AUTH ───────────────────────────────────────────────────────────────
  Future<bool> login(String username, String password) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // L'app officielle utilise "accesstoken" (sans underscore)
        final token = data['accesstoken'] ?? data['access_token'] ?? data['token'];
        if (token != null) {
          if (data['user'] != null && data['user']['can_download'] != null) {
            _canDownload = data['user']['can_download'];
          }
          await _storeTokens(token.toString(), 
            (data['refreshtoken'] ?? data['refresh_token'])?.toString());
          return true;
        }
      }
      return false;
    } on TimeoutException {
      debugPrint('Login timeout — serveur inaccessible');
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  // QR Code: GET /auth/pair?code={code}
  Future<bool> pairWithCode(String serverUrl, String code) async {
    await saveUrl(serverUrl);
    try {
      final uri = Uri.parse('$serverUrl/auth/pair').replace(
        queryParameters: {'code': code},
      );
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['accesstoken'] ?? data['access_token'] ?? data['token'];
        if (token != null) {
          if (data['user'] != null && data['user']['can_download'] != null) {
            _canDownload = data['user']['can_download'];
          }
          await _storeTokens(token.toString(),
            (data['refreshtoken'] ?? data['refresh_token'])?.toString());
          return true;
        }
      }
    } catch (e) { LoggerService.warning('Silent error caught in api_service.dart', e); }
    return false;
  }

  /// [Mobile → TV] Valide un code TV à 6 chiffres depuis le mobile connecté.
  /// Retourne le message de confirmation du serveur.
  /// Lance une Exception avec message lisible en cas d'erreur.
  Future<String> confirmTvPair(String code) async {
    final cleanCode = code.trim().replaceAll(' ', '');
    if (cleanCode.length != 6 || int.tryParse(cleanCode) == null) {
      throw Exception('Le code doit contenir exactement 6 chiffres.');
    }
    final r = await _client.post(
      Uri.parse('$_baseUrl/auth/tv/confirm'),
      headers: _headers,
      body: json.encode({'code': cleanCode}),
    ).timeout(const Duration(seconds: 10));

    if (r.statusCode == 200) {
      final data = json.decode(r.body) as Map<String, dynamic>;
      return data['message']?.toString() ?? 'TV connectée ✓';
    } else if (r.statusCode == 404) {
      throw Exception('Code introuvable. Vérifiez le code affiché sur la TV.');
    } else if (r.statusCode == 410) {
      throw Exception('Code expiré. La TV doit en générer un nouveau.');
    } else if (r.statusCode == 409) {
      throw Exception('Ce code a déjà été utilisé.');
    } else {
      String detail = 'Erreur serveur (HTTP ${r.statusCode}).';
      try {
        final err = json.decode(r.body);
        if (err['detail'] != null) detail = err['detail'].toString();
      } catch (e) { LoggerService.warning('Silent error caught in api_service.dart', e); }
      throw Exception(detail);
    }
  }


  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    await _secure.delete(key: 'access_token');
    await _secure.delete(key: 'refresh_token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  // ── Refresh token automatique ────────────────────────────────────────
  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;
    try {
      final r = await _client.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': _refreshToken}),
      ).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        final token = data['accesstoken'] ?? data['access_token'] ?? data['token'];
        if (token != null) {
          await _storeTokens(token.toString(), _refreshToken);
          return true;
        }
      }
    } catch (e) { LoggerService.warning('Silent error caught in api_service.dart', e); }
    return false;
  }

  // Requête GET avec retry automatique si 401 et Cache-First optionnel
  Future<http.Response> _authedGet(
    Uri uri, {
    bool useCache = false,
    Duration cacheMaxAge = const Duration(hours: 4),
  }) async {
    final urlStr = uri.toString();

    // 1. Stratégie Cache-First
    if (useCache) {
      final cachedBody = await ApiCacheService.instance.getCachedResponse(urlStr, maxAge: cacheMaxAge);
      if (cachedBody != null) {
        // Stale-While-Revalidate : on lance la requête réseau en fond pour MAJ le cache
        _fetchAndCacheInBackground(uri, urlStr);
        // On retourne immédiatement le cache à l'UI
        return http.Response(cachedBody, 200);
      }
    }

    // 2. Fetch Réseau classique avec gestion 401
    return await _fetchWith401Retry(uri, urlStr, useCache);
  }

  Future<void> _fetchAndCacheInBackground(Uri uri, String urlStr) async {
    try {
      await _fetchWith401Retry(uri, urlStr, true);
    } catch (_) {
      // Ignoré en fond (le cache est déjà affiché)
    }
  }

  Future<http.Response> _fetchWith401Retry(Uri uri, String urlStr, bool saveToCache) async {
    var r = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
    if (r.statusCode == 401) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        r = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
      }
    }
    // Sauvegarder dans le cache si succès et demandé
    if (r.statusCode == 200 && saveToCache) {
      ApiCacheService.instance.saveResponse(urlStr, r.body);
    }
    return r;
  }

  // Requête POST avec retry automatique si 401
  Future<http.Response> _authedPost(Uri uri, {Object? body}) async {
    var r = await _client.post(uri, headers: _headers, body: body)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 401) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        r = await _client.post(uri, headers: _headers, body: body)
            .timeout(const Duration(seconds: 10));
      }
    }
    return r;
  }

  Future<bool> checkAuth() async {
    // Pas de token du tout → login obligatoire
    if (_accessToken == null) return false;
    try {
      final response = await _authedGet(Uri.parse('$_baseUrl/auth/user'))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _canDownload = data['can_download'] ?? false;
        return true;
      }
      if (response.statusCode == 401) {
        // Token potentiellement expiré → tenter un refresh avant de déconnecter
        final refreshed = await _refreshAccessToken();
        if (refreshed) return true;
        return false; // Vraiment invalide
      }
      // 5xx, 502, 503, 504, etc. → serveur indisponible mais token présent → mode offline
      debugPrint('checkAuth server error ${response.statusCode} — mode offline');
      return true;
    } on TimeoutException catch (_) {
      // Timeout = serveur inaccessible mais token présent → mode offline
      debugPrint('checkAuth timeout — mode offline');
      return true;
    } catch (_) {
      // Toute autre erreur réseau (SocketException, etc.) → mode offline si token présent
      debugPrint('checkAuth network error — mode offline');
      return true;
    }
  }

  // Récupère les utilisateurs disponibles sur le serveur (avant login)
  Future<List<String>> getUsers(String serverUrl) async {
    try {
      final url = serverUrl.endsWith('/') ? serverUrl.substring(0, serverUrl.length - 1) : serverUrl;
      final response = await _client.get(
        Uri.parse('$url/auth/users'),
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final users = data['users'] ?? data['items'] ?? (data is List ? data : []);
        return (users as List).map((u) => (u['username'] ?? u['name'] ?? '').toString()).toList();
      }
    } catch (e) { LoggerService.warning('Silent error caught in api_service.dart', e); }
    return [];
  }

}
