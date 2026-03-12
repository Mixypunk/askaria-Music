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
  String? _cookie;
  String? _token; // JWT token seul (sans "access_token_cookie=")

  String get baseUrl => _baseUrl;
  bool get isLoggedIn => _cookie != null;
  String? get cookie => _cookie;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('server_url') ?? 'https://askaria-music.duckdns.org';
    _cookie = prefs.getString('auth_cookie');
    _token = prefs.getString('auth_token');
  }

  Future<void> saveUrl(String url) async {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', _baseUrl);
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_cookie != null) 'Cookie': _cookie!,
  };

  void _storeCookieAndToken(String setCookieHeader) {
    final match = RegExp(r'access_token_cookie=([^;]+)').firstMatch(setCookieHeader);
    if (match != null) {
      _token = match.group(1);
      _cookie = 'access_token_cookie=${_token!}';
    }
  }

  Future<void> _persistAuth() async {
    final prefs = await SharedPreferences.getInstance();
    if (_cookie != null) await prefs.setString('auth_cookie', _cookie!);
    if (_token != null) await prefs.setString('auth_token', _token!);
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
        final setCookie = response.headers['set-cookie'] ?? '';
        if (setCookie.isNotEmpty) {
          _storeCookieAndToken(setCookie);
          await _persistAuth();
          return _cookie != null;
        }
        try {
          final data = json.decode(response.body);
          if (data['access_token'] != null) {
            _token = data['access_token'].toString();
            _cookie = 'access_token_cookie=$_token';
            await _persistAuth();
            return true;
          }
        } catch (_) {}
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> pairWithCode(String serverUrl, String code) async {
    await saveUrl(serverUrl);
    for (final endpoint in ['/auth/pair', '/auth/confirmpairing', '/auth/login/pair']) {
      try {
        final r = await http.post(
          Uri.parse('$serverUrl$endpoint'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'code': code}),
        ).timeout(const Duration(seconds: 10));
        if (r.statusCode == 200) {
          final setCookie = r.headers['set-cookie'] ?? '';
          if (setCookie.isNotEmpty) {
            _storeCookieAndToken(setCookie);
            await _persistAuth();
            return _cookie != null;
          }
        }
      } catch (_) {}
    }
    return false;
  }

  Future<void> logout() async {
    _cookie = null;
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_cookie');
    await prefs.remove('auth_token');
  }

  Future<bool> checkAuth() async {
    if (_cookie == null) return false;
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/user'),
        headers: _headers,
      ).timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── SONGS ──────────────────────────────────────────────────────────────
  Future<List<Song>> getSongs({int start = 0, int limit = 200}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/folder'),
      headers: _headers,
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
      throw Exception('getSongs HTTP ${response.statusCode}: ${response.body.substring(0, 100)}');
    }
    final data = json.decode(response.body);
    final items = data['tracks'] ?? [];
    return (items as List).map((e) => Song.fromJson(e)).toList();
  }

  Future<List<Song>> searchSongs(String query) async {
    // Swing Music search endpoint
    for (final path in ['/search', '/search/tracks']) {
      try {
        final uri = Uri.parse('$_baseUrl$path').replace(
          queryParameters: {'q': query},
        );
        final response = await http.get(uri, headers: _headers);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final tracks = data['tracks'] ?? data['results'] ?? (data is List ? data : []);
          return (tracks as List).map((e) => Song.fromJson(e)).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  // ── ALBUMS ─────────────────────────────────────────────────────────────
  Future<List<Album>> getAlbums({int start = 0, int limit = 200}) async {
    final uri = Uri.parse('$_baseUrl/getall/albums').replace(
      queryParameters: {
        'start': '$start',
        'limit': '$limit',
        'sortby': 'created_date',
        'reverse': '1',
      },
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('getAlbums HTTP ${response.statusCode}: ${response.body.substring(0, 100)}');
    }
    final data = json.decode(response.body);
    final items = data['albums'] ?? data['items'] ?? (data is List ? data : []);
    return (items as List).map((e) => Album.fromJson(e)).toList();
  }

  Future<List<Song>> getAlbumTracks(String albumHash) async {
    // Try multiple possible endpoints
    for (final path in [
      '/album/$albumHash/tracks',
      '/album/tracks/$albumHash',
      '/getall/album/tracks/$albumHash',
      '/getall/albums/$albumHash/tracks',
    ]) {
      try {
        final r = await http.get(Uri.parse('$_baseUrl$path'), headers: _headers);
        if (r.statusCode == 200) {
          final data = json.decode(r.body);
          final tracks = data['tracks'] ?? (data is List ? data : []);
          return (tracks as List).map((e) => Song.fromJson(e)).toList();
        }
      } catch (_) {}
    }
    throw Exception('Album tracks: endpoint not found');
  }

  // ── ARTISTS ────────────────────────────────────────────────────────────
  Future<List<Artist>> getArtists({int start = 0, int limit = 200}) async {
    final uri = Uri.parse('$_baseUrl/getall/artists').replace(
      queryParameters: {
        'start': '$start',
        'limit': '$limit',
        'sortby': 'name',
        'reverse': '0',
      },
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('getArtists HTTP ${response.statusCode}: ${response.body.substring(0, 100)}');
    }
    final data = json.decode(response.body);
    final items = data['artists'] ?? data['items'] ?? (data is List ? data : []);
    return (items as List).map((e) => Artist.fromJson(e)).toList();
  }

  // ── PLAYLISTS ──────────────────────────────────────────────────────────
  Future<List<Playlist>> getPlaylists() async {
    for (final path in [
      '/playlist/all',
      '/playlists',
      '/getall/playlists',
      '/playlist',
    ]) {
      try {
        final r = await http.get(Uri.parse('$_baseUrl$path'), headers: _headers);
        if (r.statusCode == 200) {
          final data = json.decode(r.body);
          final items = data['playlists'] ?? data['items'] ?? (data is List ? data : []);
          return (items as List).map((e) => Playlist.fromJson(e)).toList();
        }
      } catch (_) {}
    }
    throw Exception('Playlists: endpoint not found');
  }

  Future<List<Song>> getPlaylistTracks(String playlistId) async {
    for (final path in [
      '/playlist/$playlistId/tracks',
      '/playlist/tracks/$playlistId',
      '/getall/playlist/tracks/$playlistId',
    ]) {
      try {
        final r = await http.get(Uri.parse('$_baseUrl$path'), headers: _headers);
        if (r.statusCode == 200) {
          final data = json.decode(r.body);
          final tracks = data['tracks'] ?? (data is List ? data : []);
          return (tracks as List).map((e) => Song.fromJson(e)).toList();
        }
      } catch (_) {}
    }
    throw Exception('Playlist tracks: endpoint not found');
  }

  // ── LYRICS ─────────────────────────────────────────────────────────────
  Future<String?> getLyrics(String trackHash) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/lyrics/track/$trackHash'),
        headers: _headers,
      );
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body);
      return data['lyrics'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ── STREAM / IMAGES ────────────────────────────────────────────────────
  String getStreamUrl(String trackHash) => '$_baseUrl/stream/track/$trackHash';
  String getArtworkUrl(String hash, {String type = 'track'}) => '$_baseUrl/img/$type/$hash';
  String getThumbnailUrl(String hash, {String type = 'track'}) => '$_baseUrl/img/$type/$hash/thumbnail';
}
