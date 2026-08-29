part of '../player_provider.dart';

extension PlayerQueueExt on PlayerProvider {
  AudioSource _buildSource(Song song) {
    String? localPath = song.filepath;

    if (localPath == null || !localPath.contains('/offline/')) {
      final offlineDir = _api.offlineDirPath;
      if (offlineDir != null) {
        final extRaw = (song.filepath ?? '').split('.').last.toLowerCase();
        final ext = (extRaw.isNotEmpty && extRaw.length <= 4 && extRaw != song.filepath) ? extRaw : 'mp3';
        final possibleLocalPath = '$offlineDir/${song.hash}.$ext';
        if (File(possibleLocalPath).existsSync()) {
          localPath = possibleLocalPath;
        }
      }
    }

    final isLocal = localPath != null && localPath.contains('/offline/');
    final isDeezerPreview = song.hash.startsWith('dz_');

    final uri = isLocal
        ? Uri.file(localPath)
        : isDeezerPreview
            ? Uri.parse(song.filepath ?? '')
            : Uri.parse(_api.getStreamUrl(song.hash, filepath: song.filepath));

    final headers = (isLocal || isDeezerPreview) ? null : _api.authHeaders;

    return AudioSource.uri(
      uri,
      headers: headers,
      tag: MediaItem(
        id:     song.hash,
        title:  song.title,
        artist: song.artist,
        album:  song.album,
        artUri: Uri.parse(_api.getArtworkUrl(song.image ?? song.hash)),
      ),
    );
  }

  // Reconstruit toute la ConcatenatingAudioSource depuis _queue
  Future<void> _rebuildPlaylist({int startIndex = 0}) async {
    try {
      final sources = _queue.map(_buildSource).toList();
      _playlist = ConcatenatingAudioSource(children: sources);

      await _player.setAudioSource(
        _playlist,
        initialIndex: startIndex,
        initialPosition: Duration.zero,
      );
    } catch (e) {
      debugPrint('_rebuildPlaylist error: $e');
    }
  }



  // ── Play ───────────────────────────────────────────────────────────────
  Future<void> playSong(Song song, {List<Song>? queue, int? index}) async {
    _error = null;

    if (queue != null) {
      _queue = List.from(queue);
      _currentIndex = index ?? queue.indexOf(song);
      if (_currentIndex < 0) _currentIndex = 0;
      await _rebuildPlaylist(startIndex: _currentIndex);
    } else if (!_queue.contains(song)) {
      _queue.add(song);
      _currentIndex = _queue.length - 1;
      await _playlist.add(_buildSource(song));
      await _player.seek(Duration.zero, index: _currentIndex);
    } else {
      _currentIndex = _queue.indexOf(song);
      await _player.seek(Duration.zero, index: _currentIndex);
    }

    _addToHistory(song);
    await _player.play();
    _fetchLyrics();
    _fetchColors();
    _persistQueue();
    notify();

    // Deezer background downloading and hot-swapping
    if (song.hash.startsWith('dz_')) {
      final deezerId = song.hash.replaceFirst('dz_', '');
      _api.downloadDeezerTrack(deezerId).then((newHash) async {
        if (newHash != null && currentSong?.hash == song.hash && _disposed == false) {
          final currentPos = _player.position;
          final updatedSong = Song(
            hash: newHash,
            title: song.title,
            artist: song.artist,
            album: song.album,
            albumHash: song.albumHash,
            artistHash: song.artistHash,
            duration: song.duration,
            image: song.image,
          );
          _queue[_currentIndex] = updatedSong;
          await _playlist.insert(_currentIndex + 1, _buildSource(updatedSong));
          await _player.seek(currentPos, index: _currentIndex + 1);
          await _playlist.removeAt(_currentIndex);
          notify();
        }
      });
    }
  }

  // ── Controls ───────────────────────────────────────────────────────────
  Future<void> playPause() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    _crossfadeTimer?.cancel();
    _crossfading = false;
    // Restaurer le volume avant de passer au titre suivant
    if (_player.volume < _volume) await _player.setVolume(_volume);
    if (_shuffle) {
      final idx = _random.nextInt(_queue.length);
      await _player.seek(Duration.zero, index: idx);
    } else if (_player.hasNext) {
      await _player.seekToNext();
    } else if (_repeatMode == RepeatMode.all) {
      await _player.seek(Duration.zero, index: 0);
    }
    await _player.play();
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    _crossfadeTimer?.cancel();
    _crossfading = false;
    if (_player.volume < _volume) await _player.setVolume(_volume);
    if (_position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_shuffle) {
      final idx = _random.nextInt(_queue.length);
      await _player.seek(Duration.zero, index: idx);
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else {
      await _player.seek(Duration.zero, index: _queue.length - 1);
    }
    await _player.play();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _persistQueue();
  }

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
    notify();
  }

  void toggleRepeat() {
    _repeatMode =
        RepeatMode.values[(_repeatMode.index + 1) % RepeatMode.values.length];
    switch (_repeatMode) {
      case RepeatMode.off:
        _player.setLoopMode(LoopMode.off);
        break;
      case RepeatMode.all:
        _player.setLoopMode(LoopMode.all);
        break;
      case RepeatMode.one:
        _player.setLoopMode(LoopMode.one);
        break;
    }
    notify();
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    _player.setShuffleModeEnabled(_shuffle);
    notify();
  }

  // ── Queue management ───────────────────────────────────────────────────
  void addToQueue(Song song) {
    if (!_queue.contains(song)) {
      _queue.add(song);
      _playlist.add(_buildSource(song));
      notify();
    }
  }

  void addNextInQueue(Song song) {
    _queue.remove(song);
    final insertAt = (_currentIndex + 1).clamp(0, _queue.length);
    _queue.insert(insertAt, song);
    _playlist.insert(insertAt, _buildSource(song));
    if (insertAt <= _currentIndex) _currentIndex++;
    notify();
  }

  void removeFromQueue(int index) {
    if (index == _currentIndex) return;
    if (index < _currentIndex) _currentIndex--;
    _queue.removeAt(index);
    _playlist.removeRange(index, index + 1);
    notify();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex--;
    final song = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, song);
    if (oldIndex == _currentIndex) _currentIndex = newIndex;
    else if (oldIndex < _currentIndex && newIndex >= _currentIndex) _currentIndex--;
    else if (oldIndex > _currentIndex && newIndex <= _currentIndex) _currentIndex++;
    // Reconstruire la playlist pour la réorganisation
    _rebuildPlaylist(startIndex: _currentIndex);
    notify();
  }

  // ── Widget & notification ─────────────────────────────────────────────
}

