part of '../api_service.dart';

extension ApiPlaylists on SwingApiService {
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
    } catch (e) { LoggerService.warning('Silent error caught in api_playlists.dart', e); }
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

}
