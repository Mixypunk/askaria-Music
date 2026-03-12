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

  String get baseUrl => _baseUrl;
  bool get isLoggedIn => _cookie != null;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('server_url') ?? 'https://askaria-music.duckdns.org';
    _cookie = prefs.getString('auth_cookie');
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
        final match = RegExp(r'access_token_cookie=[^;]+').firstMatch(setCookie);
        if (match != null) {
          _cookie = match.group(0);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_cookie', _cookie!);
          return true;
        }
        try {
          final data = json.decode(response.body);
          if (data['access_token'] != null) {
            _cookie = 'access_token_cookie=${data['access_token']}';
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('auth_cookie', _cookie!);
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
    for (final endpoint in ['/auth/pair', '/auth/confirmpairing']) {
      try {
        final r = await http.post(
          Uri.parse('$serverUrl$endpoint'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'code': code}),
        ).timeout(const Duration(seconds: 10));
        if (r.statusCode == 200) {
          final setCookie = r.headers['set-cookie'] ?? '';
          final match = RegExp(r'access_token_cookie=[^;]+').firstMatch(setCookie);
          if (match != null) {
            _cookie = match.group(0);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('auth_cookie', _cookie!);
            return true;
          }
        }
      } catch (_) {}
    }
    return false;
  }

  Future<void> logout() async {
    _cookie = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_cookie');
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
    if (response.statusCode != 200) throw Exception('Failed to load songs');
    final data = json.decode(response.body);
    final items = data['tracks'] ?? [];
    return (items as List).map((e) => Song.fromJson(e)).toList();
  }

  Future<List<Song>> searchSongs(String query) async {
    final uri = Uri.parse('$_baseUrl/search').replace(
      queryParameters: {'q': query},
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) throw Exception('Search failed');
    final data = json.decode(response.body);
    final tracks = data['tracks'] ?? data['results'] ?? [];
    return (tracks as List).map((e) => Song.fromJson(e)).toList();
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
    if (response.statusCode != 200) throw Exception('Failed to load albums');
    final data = json.decode(response.body);
    final items = data['albums'] ?? (data is List ? data : []);
    return (items as List).map((e) => Album.fromJson(e)).toList();
  }

  Future<List<Song>> getAlbumTracks(String albumHash) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/getall/album/tracks/$albumHash'),
      headers: _headers,
    );
    if (response.statusCode != 200) throw Exception('Failed to load album tracks');
    final data = json.decode(response.body);
    final tracks = data['tracks'] ?? (data is List ? data : []);
    return (tracks as List).map((e) => Song.fromJson(e)).toList();
  }

  // ── ARTISTS ────────────────────────────────────────────────────────────
  Future<List<Artist>> getArtists({int start = 0, int limit = 200}) async {
    final uri = Uri.parse('$_baseUrl/getall/artists').replace(
      queryParameters: {
        'start': '$start',
        'limit': '$limit',
        'sortby': 'created_date',
        'reverse': '1',
      },
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) throw Exception('Failed to load artists');
    final data = json.decode(response.body);
    final items = data['artists'] ?? (data is List ? data : []);
    return (items as List).map((e) => Artist.fromJson(e)).toList();
  }

  // ── PLAYLISTS ──────────────────────────────────────────────────────────
  Future<List<Playlist>> getPlaylists() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/getall/playlists'),
      headers: _headers,
    );
    if (response.statusCode != 200) throw Exception('Failed to load playlists');
    final data = json.decode(response.body);
    final items = data['playlists'] ?? (data is List ? data : []);
    return (items as List).map((e) => Playlist.fromJson(e)).toList();
  }

  Future<List<Song>> getPlaylistTracks(String playlistId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/getall/playlist/tracks/$playlistId'),
      headers: _headers,
    );
    if (response.statusCode != 200) throw Exception('Failed to load playlist tracks');
    final data = json.decode(response.body);
    final tracks = data['tracks'] ?? (data is List ? data : []);
    return (tracks as List).map((e) => Song.fromJson(e)).toList();
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
