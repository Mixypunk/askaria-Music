part of '../api_service.dart';

extension ApiMedia on SwingApiService {
  // ── LYRICS ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getLyrics(String trackHash, {String? filepath}) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/lyrics'),
        headers: _headers,
        body: json.encode({
          'trackhash': trackHash,
          'filepath': filepath ?? '',
        }),
      ).timeout(const Duration(seconds: 10));
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

  Future<List<Song>> searchDeezer(String query) async {
    try {
      final uri = Uri.parse('$_baseUrl/downloader/deezer/search').replace(
        queryParameters: {'q': query, 'limit': '20'},
      );
      final response = await _authedGet(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null) {
          return (data['data'] as List).map((e) => Song.fromDeezer(e)).toList();
        }
      }
    } catch (e) { LoggerService.warning('Silent error caught in api_media.dart', e); }
    return [];
  }

  Future<String?> downloadDeezerTrack(String deezerId) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/downloader/deezer/$deezerId'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['hash'];
      }
    } catch (e) { LoggerService.warning('Silent error caught in api_media.dart', e); }
    return null;
  }

  // Format officiel: {baseUrl}img/artwork/{track.image}
  String getArtworkUrl(String imageHash, {String type = 'track'}) {
    if (imageHash.startsWith('http')) return imageHash;
    return '$_baseUrl/img/artwork/$imageHash';
  }

  String getThumbnailUrl(String imageHash, {String type = 'track'}) {
    if (imageHash.startsWith('http')) return imageHash;
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
      final r = await _client.post(
        Uri.parse('$_baseUrl/track/favourite'),
        headers: _headers,
        body: json.encode({'trackhash': trackHash}),
      ).timeout(const Duration(seconds: 10));
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
