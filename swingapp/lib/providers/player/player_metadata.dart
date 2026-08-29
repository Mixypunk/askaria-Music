part of '../player_provider.dart';

extension PlayerMetadata on PlayerProvider {
  void _updateWidget() {
    if (currentSong == null) return;
    final song = currentSong!;
    // Guard : ne mettre à jour le widget que si le titre ou l'état a changé
    final hashChanged = song.hash != _lastWidgetSongHash;
    final playingChanged = _isPlaying != _lastWidgetPlaying;
    if (!hashChanged && !playingChanged) return;
    _lastWidgetSongHash = song.hash;
    _lastWidgetPlaying = _isPlaying;
    final artUrl = _api.getArtworkUrl(song.image ?? song.hash);
    WidgetService.instance.update(
      title:     song.title,
      artist:    song.artist,
      artUrl:    artUrl,
      isPlaying: _isPlaying,
      authToken: _api.accessToken,
    );
  }

  // ── Dynamic colors ─────────────────────────────────────────────────────
  Future<void> _fetchColors() async {
    if (currentSong == null || !mounted) return;
    final song = currentSong!;
    final cacheKey = song.image ?? song.hash;
    try {
      final url = _api.getArtworkUrl(cacheKey);

      // 1. Lire depuis artCache partagé avec ArtworkWidget (évite le double download)
      Uint8List? bytes = await artCache.getAsync(url);

      // 2. Si absent, télécharger ET stocker pour que ArtworkWidget en profite aussi
      if (bytes == null) {
        final isOurApi = url.startsWith(_api.baseUrl);
        final r = await http
            .get(Uri.parse(url), headers: isOurApi ? _api.authHeaders : null)
            .timeout(const Duration(seconds: 6));
        if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
          artCache.put(url, r.bodyBytes);
          bytes = r.bodyBytes;
        }
      }

      if (bytes != null && mounted) {
        if (currentSong?.hash != song.hash) return;
        _dynamicColors = await ColorService.fromBytes(cacheKey, bytes);
        if (mounted) notify();
      }
    } catch (e) { LoggerService.warning('Silent error caught in player_provider.dart', e); }
  }

  // ── Lyrics ─────────────────────────────────────────────────────────────
  Future<void> _fetchLyrics() async {
    if (currentSong == null) return;
    _lyrics = null;
    _syncedLines = null;
    _unsyncedLines = null;
    _lyricsSynced = false;
    _lyricsLoading = true;
    if (mounted) notify();

    final songHash = currentSong!.hash;
    final result = await _api.getLyrics(
      songHash,
      filepath: currentSong!.filepath,
    );

    if (result != null) {
      if (currentSong?.hash != songHash) return;
      _lyricsSynced = result['synced'] == true;
      final raw = result['lyrics'];
      if (_lyricsSynced && raw is List) {
        _syncedLines = List<Map<String, dynamic>>.from(raw.map((e) => {
          'time': (e['time'] as num).toInt(),
          'text': (e['text'] ?? '').toString(),
        }));
        _lyrics = 'synced';
      } else if (raw is List) {
        _unsyncedLines = List<String>.from(raw.map((e) => e.toString()));
        _lyrics = _unsyncedLines!.join('\n');
      } else if (raw is String) {
        _lyrics = raw;
      }
    }

    _lyricsLoading = false;
    if (mounted) notify();
  }

  // ── Favourites ─────────────────────────────────────────────────────────


}




