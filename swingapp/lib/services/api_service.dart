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
  String? _token;

  String get baseUrl => _baseUrl;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('server_url') ?? '';
    _token = prefs.getString('auth_token');
  }

  Future<void> saveSettings(String url, {String? token}) async {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', _baseUrl);
    if (token != null) await prefs.setString('auth_token', token);
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/ping'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── SONGS ──────────────────────────────────────────────────────────────
  Future<List<Song>> getSongs({int page = 1, int limit = 50}) async {
    final uri = Uri.parse('$_baseUrl/api/songs').replace(
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) throw Exception('Failed to load songs');
    final data = json.decode(response.body);
    final items = data['tracks'] ?? data['songs'] ?? data ?? [];
    return (items as List).map((e) => Song.fromJson(e)).toList();
  }

  Future<List<Song>> searchSongs(String query) async {
    final uri = Uri.parse('$_baseUrl/api/search').replace(
      queryParameters: {'q': query},
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) throw Exception('Search failed');
    final data = json.decode(response.body);
    final tracks = data['tracks'] ?? data['songs'] ?? [];
    return (tracks as List).map((e) => Song.fromJson(e)).toList();
  }

  // ── ALBUMS ─────────────────────────────────────────────────────────────
  Future<List<Album>> getAlbums({int page = 1, int limit = 50}) async {
    final uri = Uri.parse('$_baseUrl/api/albums').replace(
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) throw Exception('Failed to load albums');
    final data = json.decode(response.body);
    final items = data['albums'] ?? data ?? [];
    return (items as List).map((e) => Album.fromJson(e)).toList();
  }

  Future<List<Song>> getAlbumTracks(String albumHash) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/albums/$albumHash/tracks'),
      headers: _headers,
    );
    if (response.statusCode != 200) throw Exception('Failed to load album tracks');
    final data = json.decode(response.body);
    final tracks = data['tracks'] ?? data ?? [];
    return (tracks as List).map((e) => Song.fromJson(e)).toList();
  }

  // ── ARTISTS ────────────────────────────────────────────────────────────
  Future<List<Artist>> getArtists({int page = 1, int limit = 50}) async {
    final uri = Uri.parse('$_baseUrl/api/artists').replace(
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) throw Exception('Failed to load artists');
    final data = json.decode(response.body);
    final items = data['artists'] ?? data ?? [];
    return (items as List).map((e) => Artist.fromJson(e)).toList();
  }

  // ── PLAYLISTS ──────────────────────────────────────────────────────────
  Future<List<Playlist>> getPlaylists() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/playlists'),
      headers: _headers,
    );
    if (response.statusCode != 200) throw Exception('Failed to load playlists');
    final data = json.decode(response.body);
    final items = data['playlists'] ?? data ?? [];
    return (items as List).map((e) => Playlist.fromJson(e)).toList();
  }

  Future<List<Song>> getPlaylistTracks(String playlistId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/playlists/$playlistId/tracks'),
      headers: _headers,
    );
    if (response.statusCode != 200) throw Exception('Failed to load playlist tracks');
    final data = json.decode(response.body);
    final tracks = data['tracks'] ?? data ?? [];
    return (tracks as List).map((e) => Song.fromJson(e)).toList();
  }

  Future<void> addToPlaylist(String playlistId, String trackHash) async {
    await http.post(
      Uri.parse('$_baseUrl/api/playlists/$playlistId/tracks'),
      headers: _headers,
      body: json.encode({'trackhash': trackHash}),
    );
  }

  // ── LYRICS ─────────────────────────────────────────────────────────────
  Future<String?> getLyrics(String trackHash) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/lyrics/$trackHash'),
        headers: _headers,
      );
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body);
      return data['lyrics'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ── STREAM URL ─────────────────────────────────────────────────────────
  String getStreamUrl(String trackHash) =>
      '$_baseUrl/api/stream/$trackHash';

  String getArtworkUrl(String hash, {String type = 'track'}) =>
      '$_baseUrl/api/img/$type/$hash';

  String getThumbnailUrl(String hash, {String type = 'track'}) =>
      '$_baseUrl/api/img/$type/$hash/thumbnail';
}
