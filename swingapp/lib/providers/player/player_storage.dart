part of '../player_provider.dart';

extension PlayerStorage on PlayerProvider {
  bool isFavourite(String hash) => _favourites.contains(hash);

  Future<void> toggleFavourite(String hash) async {
    final wasLiked = _favourites.contains(hash);
    if (wasLiked) { _favourites.remove(hash); } else { _favourites.add(hash); }
    notify();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('cached_favourites', _favourites.toList());
    } catch (e) { LoggerService.warning('Silent error caught in player_provider.dart', e); }
    final ok = await _api.toggleFavourite(hash);
    if (!ok) {
      if (wasLiked) { _favourites.add(hash); } else { _favourites.remove(hash); }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('cached_favourites', _favourites.toList());
      } catch (e) { LoggerService.warning('Silent error caught in player_provider.dart', e); }
      notify();
    }
  }

  Future<void> _loadFavourites() async {
    try {
      final songs = await _api.getFavourites();
      _favourites.clear();
      _favourites.addAll(songs.map((s) => s.hash));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('cached_favourites', _favourites.toList());
      if (mounted) notify();
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getStringList('cached_favourites') ?? [];
        _favourites.clear();
        _favourites.addAll(cached);
        if (mounted) notify();
      } catch (e) { LoggerService.warning('Silent error caught in player_provider.dart', e); }
    }
  }

  // ── Cache playlists ────────────────────────────────────────────────────



  Future<List<dynamic>> getCachedPlaylists() async {
    final now = DateTime.now();
    if (_cachedPlaylists.isEmpty ||
        _playlistsCachedAt == null ||
        now.difference(_playlistsCachedAt!) > const Duration(seconds: 60)) {
      try {
        _cachedPlaylists = await _api.getPlaylists();
        _playlistsCachedAt = now;
      } catch (e) { LoggerService.warning('Silent error caught in player_provider.dart', e); }
    }
    return _cachedPlaylists;
  }

  void invalidatePlaylistsCache() {
    _cachedPlaylists = [];
    _playlistsCachedAt = null;
  }

  // ── Sleep timer ────────────────────────────────────────────────────────



  Duration? get sleepRemaining {
    if (_sleepAt == null) return null;
    final rem = _sleepAt!.difference(DateTime.now());
    return rem.isNegative ? null : rem;
  }


  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    if (minutes <= 0) { _sleepAt = null; notify(); return; }
    _sleepAt = DateTime.now().add(Duration(minutes: minutes));
    _sleepTimer = Timer(Duration(minutes: minutes), () async {
      await _player.pause();
      _sleepAt = null;
      notify();
    });
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 1), (t) {
      if (_sleepAt == null) { t.cancel(); _periodicTimer = null; return; }
      notify();
    });
    notify();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _sleepAt = null;
    notify();
  }

  // ── Historique ─────────────────────────────────────────────────────────



  void _addToHistory(Song song) {
    _history.removeWhere((s) => s.hash == song.hash);
    _history.insert(0, song);
    if (_history.length > 50) _history.removeLast();
    notify();
  }

  // ── Persistance queue ──────────────────────────────────────────────────
  Future<void> _restoreQueue() async {
    try {
      final prefs       = await SharedPreferences.getInstance();
      final queueJson   = prefs.getString('queue_json');
      final savedIndex  = prefs.getInt('queue_index') ?? 0;
      final savedPos    = prefs.getInt('queue_position') ?? 0;
      if (queueJson == null || queueJson.isEmpty) return;

      final decoded = json.decode(queueJson) as List<dynamic>;
      final restored = decoded
          .map((e) => Song.fromJson(e as Map<String, dynamic>))
          .toList();
      if (restored.isEmpty) return;

      _queue = restored;
      _currentIndex = savedIndex.clamp(0, restored.length - 1);

      // Construire la playlist et charger sans jouer
      final sources = _queue.map(_buildSource).toList();
      await _playlist.addAll(sources);
      await _player.setAudioSource(
        _playlist,
        initialIndex:    _currentIndex,
        initialPosition: Duration(seconds: savedPos),
      );

      _fetchLyrics();
      _fetchColors();
      _updateWidget();

      if (mounted) notify();
      debugPrint('Queue restaurée : ${restored.length} titres, index $_currentIndex');
    } catch (e) {
      debugPrint('Erreur restauration queue: $e');
    }
  }

  Future<void> _persistQueue() async {
    if (_queue.isEmpty) return;
    // Debounce : évite d'écrire sur disque à chaque tick de la seekbar
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(seconds: 1), () async {
      if (_disposed || _queue.isEmpty) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        final queueJson = json.encode(_queue.map((s) => {
          'trackhash': s.hash, 'hash': s.hash, 'title': s.title,
          'artist': s.artist, 'album': s.album, 'albumhash': s.albumHash,
          'artisthash': s.artistHash, 'duration': s.duration,
          'filepath': s.filepath, 'image': s.image,
        }).toList());
        await prefs.setString('queue_json', queueJson);
        await prefs.setInt('queue_index', _currentIndex);
        await prefs.setInt('queue_position', _position.inSeconds);
      } catch (e) { LoggerService.warning('Silent error caught in player_provider.dart', e); }
    });
  }

}




