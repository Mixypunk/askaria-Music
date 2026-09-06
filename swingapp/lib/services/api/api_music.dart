part of '../api_service.dart';

extension ApiMusic on SwingApiService {
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
    // Décodage dans un isolate → pas de freeze UI même avec 500 titres
    return compute(_decodeSongs, response.body);
  }

  // ── SEARCH ─────────────────────────────────────────────────────────────
  Future<List<Song>> searchSongs(String query) async {
    try {
      final uri = Uri.parse('$_baseUrl/search/').replace(
        queryParameters: {'q': query, 'limit': '-1', 'itemtype': 'tracks'},
      );
      final response = await _authedGet(uri, useCache: true);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tracks = data['tracks'] ?? data['results'] ?? (data is List ? data : []);
        return (tracks as List).map((e) => Song.fromJson(e)).toList();
      }
    } catch (e) { LoggerService.warning('Silent error caught in api_music.dart', e); }
    return [];
  }

  Future<Map<String, dynamic>> searchTop(String query) async {
    try {
      final uri = Uri.parse('$_baseUrl/search/top').replace(
        queryParameters: {'q': query, 'limit': '5'},
      );
      final response = await _authedGet(uri, useCache: true);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) { LoggerService.warning('Silent error caught in api_music.dart', e); }
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
    final response = await _authedGet(uri, useCache: true);
    if (response.statusCode != 200) {
      throw Exception('getAlbums HTTP ${response.statusCode}');
    }
    // Décodage dans un isolate → pas de freeze UI même avec 200 albums
    return compute(_decodeAlbums, response.body);
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
    final response = await _authedGet(uri, useCache: true);
    if (response.statusCode != 200) {
      throw Exception('getArtists HTTP ${response.statusCode}');
    }
    // Décodage dans un isolate → pas de freeze UI même avec 200 artistes
    return compute(_decodeArtists, response.body);
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
    } catch (e) { LoggerService.warning('Silent error caught in api_music.dart', e); }
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

}
