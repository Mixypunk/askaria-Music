import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/playlist.dart';

class SwingApiService {
  static final SwingApiService _instance = SwingApiService._internal();
  factory SwingApiService() => _instance;
  SwingApiService._internal();

  String _baseUrl = 'https://askaria-music.duckdns.org';
  String? _accessToken;
  String? _refreshToken;

  String get baseUrl => _baseUrl;
  bool get isLoggedIn => _accessToken != null;

  // Headers avec Bearer token (format utilisé par l'app officielle)
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  // ── SETTINGS ───────────────────────────────────────────────────────────
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('server_url') ?? 'https://askaria-music.duckdns.org';
    // Enlève le slash final si présent
    if (_baseUrl.endsWith('/')) _baseUrl = _baseUrl.substring(0, _baseUrl.length - 1);
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
  }

  Future<void> saveUrl(String url) async {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', _baseUrl);
  }

  Future<void> _storeTokens(String access, String? refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    if (refresh != null) await prefs.setString('refresh_token', refresh);
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
          await _storeTokens(token.toString(), 
            (data['refreshtoken'] ?? data['refresh_token'])?.toString());
          return true;
        }
      }
      return false;
    } catch (_) {
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
          await _storeTokens(token.toString(),
            (data['refreshtoken'] ?? data['refresh_token'])?.toString());
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
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
    if (_accessToken == null) return false;
    try {
      final response = await _authedGet(Uri.parse('$_baseUrl/auth/user'));
      if (response.statusCode == 200) return true;
      // Essayer le refresh si 401
      if (response.statusCode == 401) {
        return await _refreshAccessToken();
      }
      return false;
    } catch (_) {
      return false;
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
  // Format officiel: {baseUrl}file/{trackhash}/legacy?filepath={encodedPath}
  String getStreamUrl(String trackHash,
      {String? filepath, String quality = 'high'}) {
    // Paramètre bitrate selon la qualité choisie
    final bitrate = quality == 'low' ? '96'
                  : quality == 'medium' ? '192'
                  : '0'; // 0 = qualité originale (lossless si dispo)
    if (filepath != null && filepath.isNotEmpty) {
      final encoded = Uri.encodeComponent(filepath);
      return '$_baseUrl/file/$trackHash/legacy?filepath=$encoded&bitrate=$bitrate';
    }
    return '$_baseUrl/file/$trackHash/legacy?bitrate=$bitrate';
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
}