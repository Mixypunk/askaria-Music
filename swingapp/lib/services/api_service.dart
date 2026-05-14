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
import '../models/artist.dart';
import '../models/playlist.dart';

class SwingApiService {
  static final SwingApiService _instance = SwingApiService._internal();
  factory SwingApiService() => _instance;
  SwingApiService._internal();

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
    } catch (_) {}
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
    } catch (_) {}

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
      final response = await http.post(
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
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
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
    } catch (_) {}
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
    final r = await http.post(
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
      } catch (_) {}
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
      final r = await http.post(
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
    } catch (_) {}
    return false;
  }

  // Requête GET avec retry automatique si 401
  Future<http.Response> _authedGet(Uri uri) async {
    var r = await http.get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 401) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        r = await http.get(uri, headers: _headers)
            .timeout(const Duration(seconds: 10));
      }
    }
    return r;
  }

  // Requête POST avec retry automatique si 401
  Future<http.Response> _authedPost(Uri uri, {Object? body}) async {
    var r = await http.post(uri, headers: _headers, body: body)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 401) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        r = await http.post(uri, headers: _headers, body: body)
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
        return await _refreshAccessToken();
      }
      return false;
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
      final response = await http.get(
        Uri.parse('$url/auth/users'),
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final users = data['users'] ?? data['items'] ?? (data is List ? data : []);
        return (users as List).map((u) => (u['username'] ?? u['name'] ?? '').toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  // ── SONGS (POST /folder) ───────────────────────────────────────────────
  Future<List<Song>> getSongs({int start = 0, int limit = 500}) async {
    final response = await _authedPost(Uri.parse('$_baseUrl/folder'),
      body: json.encode({
        'folder': '/music/',
        'start': start,
        'limit': limit,
        'tracks_only': true,
        'sorttracksby': 'default',
        'tracksort_reverse': false,
        'foldersort_reverse': false,
        'sortfoldersby': 'lastmod',
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('getSongs HTTP ${response.statusCode}');
    }
    final data = json.decode(response.body);
    final items = data['tracks'] ?? [];
    return (items as List).map((e) => Song.fromJson(e)).toList();
  }

  // ── SEARCH ─────────────────────────────────────────────────────────────
  Future<List<Song>> searchSongs(String query) async {
    try {
      final uri = Uri.parse('$_baseUrl/search/').replace(
        queryParameters: {'q': query, 'limit': '-1', 'itemtype': 'tracks'},
      );
      final response = await _authedGet(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tracks = data['tracks'] ?? data['results'] ?? (data is List ? data : []);
        return (tracks as List).map((e) => Song.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> searchTop(String query) async {
    try {
      final uri = Uri.parse('$_baseUrl/search/top').replace(
        queryParameters: {'q': query, 'limit': '5'},
      );
      final response = await _authedGet(uri);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  // ── ALBUMS ─────────────────────────────────────────────────────────────
  Future<List<Album>> getAlbums({int start = 0, int limit = 500}) async {
    final uri = Uri.parse('$_baseUrl/getall/albums').replace(
      queryParameters: {
        'start': '$start',
        'limit': '$limit',
        'sortby': 'created_date',
        'reverse': '1',
      },
    );
    final response = await _authedGet(uri);
    if (response.statusCode != 200) {
      throw Exception('getAlbums HTTP ${response.statusCode}');
    }
    final data = json.decode(response.body);
    final items = data['items'] ?? data['albums'] ?? (data is List ? data : []);
    return (items as List).map((e) => Album.fromJson(e)).toList();
  }

  // POST /album avec {albumhash: hash}
  Future<List<Song>> getAlbumTracks(String albumHash) async {
    final response = await _authedGet(Uri.parse('$_baseUrl/album/$albumHash/tracks'));
    if (response.statusCode != 200) {
      throw Exception('Album tracks HTTP ${response.statusCode}');
    }
    final data = json.decode(response.body);
    final tracks = data is List ? data : (data['tracks'] ?? []);
    return (tracks as List).map((e) => Song.fromJson(e)).toList();
  }

  // ── ARTISTS ────────────────────────────────────────────────────────────
  Future<List<Artist>> getArtists({int start = 0, int limit = 500}) async {
    final uri = Uri.parse('$_baseUrl/getall/artists').replace(
      queryParameters: {
        'start': '$start',
        'limit': '$limit',
        'sortby': 'name',
        'reverse': '0',
      },
    );
    final response = await _authedGet(uri);
    if (response.statusCode != 200) {
      throw Exception('getArtists HTTP ${response.statusCode}');
    }
    final data = json.decode(response.body);
    final items = data['items'] ?? data['artists'] ?? (data is List ? data : []);
    return (items as List).map((e) => Artist.fromJson(e)).toList();
  }

  Future<List<Song>> getArtistTracks(String artistHash) async {
    final response = await _authedGet(Uri.parse('$_baseUrl/artist/$artistHash/tracks'));
    if (response.statusCode != 200) return [];
    final data = json.decode(response.body);
    final tracks = data is List ? data : (data['tracks'] ?? []);
    return (tracks as List).map((e) => Song.fromJson(e)).toList();
  }

  /// Cherche un artiste par nom — utile quand artistHash est vide
  Future<Artist?> searchArtistByName(String name) async {
    try {
      final data = await searchTop(name);
      final artists = data['artists'] ?? data['top_result']?['artists'] ?? [];
      if (artists is List && artists.isNotEmpty) {
        return Artist.fromJson(artists.first as Map<String, dynamic>);
      }
      // Fallback : chercher dans getArtists
      final all = await getArtists(limit: 500);
      final match = all.where((a) =>
        a.name.toLowerCase() == name.toLowerCase()).toList();
      if (match.isNotEmpty) return match.first;
    } catch (_) {}
    return null;
  }

  Future<List<Album>> getArtistAlbums(String artistHash) async {
    try {
      final response = await _authedGet(
          Uri.parse('$_baseUrl/artist/$artistHash/albums'));
      if (response.statusCode != 200) return [];
      final data = json.decode(response.body);
      final items = data is List ? data : (data['albums'] ?? data['items'] ?? []);
      return (items as List).map((e) => Album.fromJson(e)).toList();
    } catch (_) { return []; }
  }

  // ── PLAYLISTS ──────────────────────────────────────────────────────────
  Future<List<Playlist>> getPlaylists() async {
    final uri = Uri.parse('$_baseUrl/playlists').replace(
      queryParameters: {'start': '0', 'limit': '200', 'no_tracks': 'true'},
    );
    final response = await _authedGet(uri);
    if (response.statusCode != 200) {
      throw Exception('getPlaylists HTTP ${response.statusCode}');
    }
    final data = json.decode(response.body);
    // Server returns {"data": [...]}
    final items = data['data'] ?? data['playlists'] ?? data['items'] ?? (data is List ? data : []);
    return (items as List).map((e) => Playlist.fromJson(e)).toList();
  }

  Future<List<Song>> getPlaylistTracks(String playlistId) async {
    final uri = Uri.parse('$_baseUrl/playlists/$playlistId').replace(
      queryParameters: {'no_tracks': 'false', 'start': '0', 'limit': '500'},
    );
    final response = await _authedGet(uri);
    if (response.statusCode != 200) {
      throw Exception('Playlist tracks HTTP ${response.statusCode}');
    }
    final data = json.decode(response.body);
    // Server returns {info: ..., tracks: [...]}
    final tracks = data['tracks'] ?? (data is List ? data : []);
    return (tracks as List).map((e) => Song.fromJson(e)).toList();
  }

  Future<List<Playlist>> getPublicPlaylists() async {
    try {
      final uri = Uri.parse('$_baseUrl/playlists/public');
      final response = await _authedGet(uri);
      if (response.statusCode != 200) return [];
      final data = json.decode(response.body);
      final items = data['data'] ?? data['playlists'] ?? data['items'] ?? (data is List ? data : []);
      return (items as List).map((e) => Playlist.fromJson(e)).toList();
    } catch (_) { return []; }
  }

  // ── PLAYLIST CRUD ─────────────────────────────────────────────────────
  /// Créer une nouvelle playlist
  Future<Playlist?> createPlaylist(String name, {String description = '', bool isPublic = false}) async {
    try {
      final r = await _authedPost(
        Uri.parse('$_baseUrl/playlists/new'),
        body: json.encode({'name': name, 'description': description, 'is_public': isPublic}),
      );
      if (r.statusCode == 200 || r.statusCode == 201) {
        final data = json.decode(r.body);
        final pl = data['playlist'] ?? data['data'] ?? data;
        if (pl is Map) return Playlist.fromJson(pl as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  /// Renommer / modifier la description d'une playlist
  Future<bool> updatePlaylist(String playlistId,
      {String? name, String? description, bool? isPublic}) async {
    try {
      final body = <String, dynamic>{};
      if (name != null)        body['name']        = name;
      if (description != null) body['description'] = description;
      if (isPublic != null)    body['is_public']   = isPublic;
      final r = await _authedPost(
        Uri.parse('$_baseUrl/playlists/$playlistId/update'),
        body: json.encode(body),
      );
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  /// Supprimer une playlist
  Future<bool> deletePlaylist(String playlistId) async {
    try {
      final r = await _authedPost(
        Uri.parse('$_baseUrl/playlists/$playlistId/delete'),
        body: json.encode({}),
      );
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  /// Ajouter des titres à une playlist
  Future<bool> addTracksToPlaylist(
      String playlistId, List<String> trackHashes) async {
    try {
      final r = await _authedPost(
        Uri.parse('$_baseUrl/playlists/$playlistId/add'),
        body: json.encode({'trackhashes': trackHashes}),
      );
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  /// Retirer un titre d'une playlist (par index dans la liste)
  Future<bool> removeTrackFromPlaylist(
      String playlistId, String trackHash, int index) async {
    try {
      final r = await _authedPost(
        Uri.parse('$_baseUrl/playlists/$playlistId/remove'),
        body: json.encode({'trackhash': trackHash, 'index': index}),
      );
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  /// Réordonner les titres d'une playlist
  Future<bool> reorderPlaylist(
      String playlistId, int oldIndex, int newIndex) async {
    try {
      final r = await _authedPost(
        Uri.parse('$_baseUrl/playlists/$playlistId/reorder'),
        body: json.encode({'old_index': oldIndex, 'new_index': newIndex}),
      );
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  // ── LYRICS ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getLyrics(String trackHash, {String? filepath}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/lyrics'),
        headers: _headers,
        body: json.encode({
          'trackhash': trackHash,
          'filepath': filepath ?? '',
        }),
      );
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body);
      if (data['error'] != null) return null;
      return data; // {lyrics: str, synced: bool, copyright: str}
    } catch (_) {
      return null;
    }
  }

  // ── STREAM / IMAGES ────────────────────────────────────────────────────
  // Format officiel: {baseUrl}file/{trackhash}/legacy
  // Utilise le stream token (courte durée) plutôt que l'access token
  Future<String> buildStreamUrl(String trackHash,
      {String? filepath, String quality = 'high'}) async {
    final bitrate = quality == 'low' ? '96'
                  : quality == 'medium' ? '192'
                  : '0';
    final token = await _getStreamToken();
    if (filepath != null && filepath.isNotEmpty) {
      final encoded = Uri.encodeComponent(filepath);
      return '$_baseUrl/file/$trackHash/legacy?filepath=$encoded&bitrate=$bitrate&token=$token';
    }
    return '$_baseUrl/file/$trackHash/legacy?bitrate=$bitrate&token=$token';
  }

  // Compatibilité sync (utilisé dans les endroits qui ne peuvent pas await)
  String getStreamUrl(String trackHash,
      {String? filepath, String quality = 'high'}) {
    final bitrate = quality == 'low' ? '96'
                  : quality == 'medium' ? '192'
                  : '0';
    final token = _streamToken ?? _accessToken ?? '';
    if (filepath != null && filepath.isNotEmpty) {
      final encoded = Uri.encodeComponent(filepath);
      return '$_baseUrl/file/$trackHash/legacy?filepath=$encoded&bitrate=$bitrate&token=$token';
    }
    return '$_baseUrl/file/$trackHash/legacy?bitrate=$bitrate&token=$token';
  }

  // Format officiel: {baseUrl}img/thumbnail/{track.image}
  String getArtworkUrl(String imageHash, {String type = 'track'}) {
    return '$_baseUrl/img/thumbnail/$imageHash';
  }

  String getThumbnailUrl(String imageHash, {String type = 'track'}) {
    return '$_baseUrl/img/thumbnail/$imageHash';
  }

  // Headers pour les requêtes image/stream (just_audio, cached_network_image)
  Map<String, String> get authHeaders => {
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  String? get accessToken => _accessToken;

  // ── FAVOURITES ────────────────────────────────────────────────────────
  Future<bool> toggleFavourite(String trackHash) async {
    try {
      final r = await http.post(
        Uri.parse('$_baseUrl/track/favourite'),
        headers: _headers,
        body: json.encode({'trackhash': trackHash}),
      );
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  Future<List<Song>> getFavourites() async {
    try {
      final r = await _authedGet(Uri.parse('$_baseUrl/favourites'));
      if (r.statusCode != 200) return [];
      final data = json.decode(r.body);
      final list = data['tracks'] ?? data['items'] ?? [];
      return (list as List).map((e) => Song.fromJson(e)).toList();
    } catch (_) { return []; }
  }

  // ── STATISTIQUES ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getStatsOverview() async {
    try {
      final r = await _authedGet(Uri.parse('$_baseUrl/stats/overview'));
      if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    return {};
  }

  Future<Map<String, dynamic>> getTopTracks({int limit = 10, String period = 'all'}) async {
    try {
      final uri = Uri.parse('$_baseUrl/stats/top-tracks')
          .replace(queryParameters: {'limit': '$limit', 'period': period});
      final r = await _authedGet(uri);
      if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    return {};
  }

  Future<Map<String, dynamic>> getTopArtists({int limit = 10, String period = 'all'}) async {
    try {
      final uri = Uri.parse('$_baseUrl/stats/top-artists')
          .replace(queryParameters: {'limit': '$limit', 'period': period});
      final r = await _authedGet(uri);
      if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    return {};
  }

  Future<Map<String, dynamic>> getHistory({int limit = 30}) async {
    try {
      final uri = Uri.parse('$_baseUrl/stats/history')
          .replace(queryParameters: {'limit': '$limit'});
      final r = await _authedGet(uri);
      if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    return {};
  }

  Future<List<Map<String, dynamic>>> getHeatmap() async {
    try {
      final r = await _authedGet(Uri.parse('$_baseUrl/stats/heatmap'));
      if (r.statusCode == 200) {
        final data = json.decode(r.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['hours'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getDailyStats({int days = 7}) async {
    try {
      final uri = Uri.parse('$_baseUrl/stats/daily')
          .replace(queryParameters: {'days': '$days'});
      final r = await _authedGet(uri);
      if (r.statusCode == 200) {
        final data = json.decode(r.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['items'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getTopGenres() async {
    try {
      final r = await _authedGet(Uri.parse('$_baseUrl/stats/genres'));
      if (r.statusCode == 200) {
        final data = json.decode(r.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['items'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  // ── PROFIL ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final r = await _authedGet(Uri.parse('$_baseUrl/users/me'));
      if (r.statusCode == 200) {
        final data = json.decode(r.body) as Map<String, dynamic>;
        _canDownload = data['can_download'] ?? false;
        return data;
      }
    } catch (_) {}
    return {};
  }

  Future<Map<String, dynamic>?> updateProfile({
    String? username, String? email, String? birthDate, String? bio,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (username  != null) body['username']   = username;
      if (email     != null) body['email']      = email;
      if (birthDate != null) body['birth_date'] = birthDate;
      if (bio       != null) body['bio']        = bio;
      final r = await http.patch(
        Uri.parse('$_baseUrl/users/me'),
        headers: _headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
      final err = json.decode(r.body);
      throw Exception(err['detail'] ?? 'Erreur serveur');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> changePassword(String current, String newPwd) async {
    final r = await http.post(
      Uri.parse('$_baseUrl/users/me/password'),
      headers: _headers,
      body: json.encode({'current_password': current, 'new_password': newPwd}),
    ).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) {
      final err = json.decode(r.body);
      throw Exception(err['detail'] ?? 'Erreur changement mot de passe');
    }
  }

  Future<String?> uploadAvatar(List<int> imageBytes) async {
    try {
      final r = await http.post(
        Uri.parse('$_baseUrl/users/me/avatar'),
        headers: {..._headers, 'Content-Type': 'application/octet-stream'},
        body: imageBytes,
      ).timeout(const Duration(seconds: 30));
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        return data['avatar'] as String?;
      }
    } catch (_) {}
    return null;
  }

  String getAvatarUrl(int userId) => '$_baseUrl/users/me/avatar/$userId';



  // ── RADIO ─────────────────────────────────────────────────────────────────
  Future<List<Song>> getRadio(String seedHash, {int limit = 30}) async {
    try {
      final uri = Uri.parse('$_baseUrl/radio/$seedHash')
          .replace(queryParameters: {'limit': '$limit'});
      final r = await _authedGet(uri);
      if (r.statusCode == 200) {
        final data  = json.decode(r.body) as Map<String, dynamic>;
        final items = (data['tracks'] as List?) ?? [];
        return items
            .map((e) => Song.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('getRadio error: $e');
    }
    return [];
  }
  Future<List<double>?> getWaveform(String hash) async {
    try {
      final r = await _authedGet(Uri.parse('$_baseUrl/waveform/$hash'));
      if (r.statusCode == 200) {
        final data = json.decode(r.body) as Map<String, dynamic>;
        final peaks = data['peaks'] as List?;
        return peaks?.map((v) => (v as num).toDouble()).toList();
      }
    } catch (_) {}
    return null;
  }
  // ── TÉLÉCHARGEMENT OFFLINE ───────────────────────────────────────────────────
  String getDownloadUrl(String hash) => '$_baseUrl/download/$hash';

  Future<String?> downloadTrack(Song song, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final offlineDir = Directory('${dir.path}/offline');
      await offlineDir.create(recursive: true);

      // Utilise l'extension du filepath ; fallback sur 'mp3' si absent
      final rawExt = (song.filepath ?? '').split('.').last.toLowerCase();
      final ext = (rawExt.isNotEmpty && rawExt.length <= 4 && rawExt != song.filepath) ? rawExt : 'mp3';
      final safe = '${song.hash}.$ext';
      final file = File('${offlineDir.path}/$safe');

      if (await file.exists()) {
        // Recréer les métadonnées si manquantes (migration)
        await _saveOfflineMeta(song, file.path, ext: ext);
        return file.path;
      }

      final uri = Uri.parse(getDownloadUrl(song.hash));
      final req  = http.Request('GET', uri);
      req.headers['Authorization'] = 'Bearer $_accessToken';

      final client   = http.Client();
      final streamed = await client.send(req);

      if (streamed.statusCode != 200) { client.close(); return null; }

      final total  = streamed.contentLength ?? -1;
      int received = 0;
      final sink   = file.openWrite();
      await for (final chunk in streamed.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.close();
      client.close();

      // Sauvegarder les métadonnées pour affichage dans Downloads screen
      await _saveOfflineMeta(song, file.path, ext: ext);

      return file.path;
    } catch (e) {
      debugPrint('downloadTrack error: $e');
      return null;
    }
  }

  Future<void> _saveOfflineMeta(Song song, String filePath, {String ext = 'mp3'}) async {
    try {
      final dir     = await getApplicationDocumentsDirectory();
      final metaFile = File('${dir.path}/offline/${song.hash}.meta.json');
      final meta = {
        'hash':       song.hash,
        'title':      song.title,
        'artist':     song.artist,
        'album':      song.album,
        'duration':   song.duration,
        'image':      song.image ?? song.hash,
        'filepath':   filePath,
        'ext':        ext,
        'downloaded': DateTime.now().toIso8601String(),
      };
      await metaFile.writeAsString(json.encode(meta));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> getOfflineMeta(String hash) async {
    try {
      final dir      = await getApplicationDocumentsDirectory();
      final metaFile = File('${dir.path}/offline/$hash.meta.json');
      if (!metaFile.existsSync()) return null;
      return json.decode(metaFile.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) { return null; }
  }

  /// Retourne l'extension stockée dans le meta, ou déduit depuis filepath, ou 'mp3'.
  String _resolveExt(String filepath, [Map<String, dynamic>? meta]) {
    final fromMeta = meta?['ext'] as String?;
    if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;
    final raw = filepath.split('.').last.toLowerCase();
    return (raw.isNotEmpty && raw.length <= 4 && raw != filepath) ? raw : 'mp3';
  }

  Future<bool> isDownloaded(String hash, String filepath) async {
    try {
      final dir  = await getApplicationDocumentsDirectory();
      // Priorité : lire l'ext depuis le meta si disponible
      final meta = await getOfflineMeta(hash);
      final ext  = _resolveExt(filepath, meta);
      final file = File('${dir.path}/offline/$hash.$ext');
      return file.existsSync();
    } catch (_) { return false; }
  }

  Future<String?> getOfflinePath(String hash, String filepath) async {
    try {
      final dir  = await getApplicationDocumentsDirectory();
      final meta = await getOfflineMeta(hash);
      // Utiliser le filepath sauvegardé dans le meta (le plus fiable)
      final savedPath = meta?['filepath'] as String?;
      if (savedPath != null && File(savedPath).existsSync()) return savedPath;
      // Fallback : reconstruire depuis le hash + extension
      final ext  = _resolveExt(filepath, meta);
      final file = File('${dir.path}/offline/$hash.$ext');
      return file.existsSync() ? file.path : null;
    } catch (_) { return null; }
  }

  Future<List<Map<String, dynamic>>> getDownloadedTracks() async {
    try {
      final dir      = await getApplicationDocumentsDirectory();
      final offlineDir = Directory('${dir.path}/offline');
      if (!offlineDir.existsSync()) return [];
      return offlineDir
          .listSync()
          .whereType<File>()
          .map((f) => {'path': f.path, 'hash': f.path.split('/').last.split('.').first})
          .toList();
    } catch (_) { return []; }
  }

  Future<void> deleteOfflineTrack(String hash, String filepath) async {
    try {
      final dir  = await getApplicationDocumentsDirectory();
      final meta = await getOfflineMeta(hash);
      final ext  = _resolveExt(filepath, meta);
      final file = File('${dir.path}/offline/$hash.$ext');
      if (file.existsSync()) await file.delete();
      // Supprimer aussi le fichier meta
      final metaFile = File('${dir.path}/offline/$hash.meta.json');
      if (metaFile.existsSync()) await metaFile.delete();
    } catch (_) {}
  }
}