import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../services/api_service.dart';
import '../services/color_service.dart';

enum RepeatMode { off, all, one }

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final SwingApiService _api = SwingApiService();
  final _random = Random();

  List<Song> _queue = [];
  List<int> _shuffleOrder = []; // indices shufflés
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  RepeatMode _repeatMode = RepeatMode.off;
  bool _shuffle = false;
  String? _error;

  // Lyrics
  String? _lyrics;
  bool _lyricsLoading = false;
  bool _lyricsSynced = false;
  List<Map<String, dynamic>>? _syncedLines;
  List<String>? _unsyncedLines;

  // Dynamic color
  DynamicColors _dynamicColors = DynamicColors.fallback();
  DynamicColors get dynamicColors => _dynamicColors;

  // Getters
  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  Song? get currentSong => _currentIndex >= 0 && _currentIndex < _queue.length
      ? _queue[_currentIndex] : null;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Duration get position => _position;
  Duration get duration => _duration;
  RepeatMode get repeatMode => _repeatMode;
  bool get shuffle => _shuffle;
  String? get lyrics => _lyrics;
  bool get lyricsLoading => _lyricsLoading;
  bool get lyricsSynced => _lyricsSynced;
  List<Map<String, dynamic>>? get syncedLines => _syncedLines;
  List<String>? get unsyncedLines => _unsyncedLines;
  /// Vrai si les paroles sont disponibles (après chargement terminé)
  bool get hasLyrics => !_lyricsLoading &&
      ((_syncedLines != null && _syncedLines!.isNotEmpty) ||
       (_unsyncedLines != null && _unsyncedLines!.isNotEmpty));
  String? get error => _error;

  double get progress => _duration.inMilliseconds > 0
      ? _position.inMilliseconds / _duration.inMilliseconds : 0.0;

  PlayerProvider() {
    _loadFavourites();
    _restoreQueue();
    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isLoading = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      if (state.processingState == ProcessingState.completed) {
        _onTrackComplete();
      }
      notifyListeners();
    });
    _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });
    _player.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });
  }

  // ── Shuffle order ──────────────────────────────────────────────────────
  void _buildShuffleOrder() {
    _shuffleOrder = List.generate(_queue.length, (i) => i);
    _shuffleOrder.shuffle(_random);
    // Met la chanson courante en premier
    if (_currentIndex >= 0) {
      _shuffleOrder.remove(_currentIndex);
      _shuffleOrder.insert(0, _currentIndex);
    }
  }

  int get _shufflePos {
    if (_shuffleOrder.isEmpty) return 0;
    final pos = _shuffleOrder.indexOf(_currentIndex);
    return pos < 0 ? 0 : pos;
  }

  // ── Play ───────────────────────────────────────────────────────────────
  Future<void> playSong(Song song, {List<Song>? queue, int? index}) async {
    if (queue != null) {
      _queue = List.from(queue);
      _currentIndex = index ?? queue.indexOf(song);
      if (_currentIndex < 0) _currentIndex = 0;
    } else if (!_queue.contains(song)) {
      _queue.add(song);
      _currentIndex = _queue.length - 1;
    } else {
      _currentIndex = _queue.indexOf(song);
    }
    if (_shuffle) _buildShuffleOrder();
    await _loadAndPlay();
    _fetchLyrics();
    _fetchColors();
    _persistQueue();
  }

  Future<void> _loadAndPlay() async {
    if (currentSong == null) return;
    _error = null;
    try {
      final song = currentSong!;
      final prefs   = await SharedPreferences.getInstance();
      final quality  = prefs.getString('audio_quality') ?? 'high';
      final url      = await _api.buildStreamUrl(song.hash,
          filepath: song.filepath, quality: quality);
      _addToHistory(song);
      final artUrl = '${_api.baseUrl}/img/thumbnail/${song.image ?? song.hash}';
      debugPrint('🎵 Stream: $url');
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          headers: _api.authHeaders,
          tag: MediaItem(
            id:     song.hash,
            title:  song.title,
            artist: song.artist,
            album:  song.album,
            artUri: Uri.parse(artUrl),
          ),
        ),
      );
      await _player.play();
      notifyListeners();
    } catch (e) {
      _error = e.toString().contains('Connection refused')
          ? 'Serveur inaccessible — vérifiez la connexion'
          : e.toString().contains('404')
              ? 'Fichier audio introuvable sur le serveur'
              : e.toString().contains('401')
                  ? 'Session expirée — reconnectez-vous'
                  : 'Erreur de lecture : \${e.toString().split(':').last.trim()}';
      debugPrint('Stream error: \$e');
      if (mounted) notifyListeners();
    }
  }

  // ── Track complete ─────────────────────────────────────────────────────
  void _onTrackComplete() {
    if (_queue.isEmpty) return;
    switch (_repeatMode) {
      case RepeatMode.one:
        _player.seek(Duration.zero);
        _player.play();
        return;
      case RepeatMode.all:
        _nextTrack(loop: true);
        return;
      case RepeatMode.off:
        // Comportement Spotify : toujours passer à la suivante,
        // boucler sauf si une seule chanson dans la file
        _nextTrack(loop: _queue.length > 1);
        return;
    }
  }

  void _nextTrack({required bool loop}) {
    if (_shuffle) {
      final pos = _shufflePos;
      final nextPos = pos + 1;
      if (nextPos >= _shuffleOrder.length) {
        if (loop) {
          _buildShuffleOrder();
          _currentIndex = _shuffleOrder[0];
          _loadAndPlay();
          _fetchLyrics();
          _fetchColors();
        }
        return;
      }
      _currentIndex = _shuffleOrder[nextPos];
    } else {
      final next = _currentIndex + 1;
      if (next >= _queue.length) {
        if (loop) {
          _currentIndex = 0;
        } else {
          return;
        }
      } else {
        _currentIndex = next;
      }
    }
    _loadAndPlay();
    _fetchLyrics();
    _fetchColors();
  }

  void _prevTrack() {
    if (_shuffle) {
      final pos = _shufflePos;
      final prevPos = (pos - 1 + _shuffleOrder.length) % _shuffleOrder.length;
      _currentIndex = _shuffleOrder[prevPos];
    } else {
      _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
    }
    _loadAndPlay();
    _fetchLyrics();
    _fetchColors();
  }

  // ── Controls ───────────────────────────────────────────────────────────
  Future<void> playPause() async {
    if (_isPlaying) await _player.pause();
    else await _player.play();
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    _nextTrack(loop: _repeatMode == RepeatMode.all);
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    // Si > 3s : retour au début de la chanson
    if (_position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    _prevTrack();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _persistQueue();
  }

  // Volume (0.0 → 1.0)
  double _volume = 1.0;
  double get volume => _volume;
  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
    notifyListeners();
  }

  void toggleRepeat() {
    _repeatMode = RepeatMode.values[(_repeatMode.index + 1) % RepeatMode.values.length];
    notifyListeners();
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    if (_shuffle) _buildShuffleOrder();
    notifyListeners();
  }

  // ── Queue management ───────────────────────────────────────────────────
  void addToQueue(Song song) {
    if (!_queue.contains(song)) {
      _queue.add(song);
      if (_shuffle) _shuffleOrder.add(_queue.length - 1);
      notifyListeners();
    }
  }

  void addNextInQueue(Song song) {
    _queue.remove(song);
    final insertAt = (_currentIndex + 1).clamp(0, _queue.length);
    _queue.insert(insertAt, song);
    if (insertAt <= _currentIndex) _currentIndex++;
    if (_shuffle) _buildShuffleOrder();
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index == _currentIndex) return;
    if (index < _currentIndex) _currentIndex--;
    _queue.removeAt(index);
    if (_shuffle) _buildShuffleOrder();
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex--;
    final song = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, song);
    if (oldIndex == _currentIndex) _currentIndex = newIndex;
    else if (oldIndex < _currentIndex && newIndex >= _currentIndex) _currentIndex--;
    else if (oldIndex > _currentIndex && newIndex <= _currentIndex) _currentIndex++;
    if (_shuffle) _buildShuffleOrder();
    notifyListeners();
  }

  // ── Dynamic colors ─────────────────────────────────────────────────────
  Future<void> _fetchColors() async {
    if (currentSong == null || !mounted) return;
    final song = currentSong!;
    final cacheKey = song.image ?? song.hash;
    try {
      final url = '${_api.baseUrl}/img/thumbnail/$cacheKey';
      final r = await http.get(Uri.parse(url), headers: _api.authHeaders)
          .timeout(const Duration(seconds: 6));
      // Verifier mounted apres l'await (le provider peut avoir ete dispose)
      if (r.statusCode == 200 && r.bodyBytes.isNotEmpty && mounted) {
        _dynamicColors = await ColorService.fromBytes(cacheKey, r.bodyBytes);
        if (mounted) notifyListeners();
      }
    } catch (_) {}
  }

  bool _disposed = false;

  bool get mounted => !_disposed;

  // ── Lyrics ─────────────────────────────────────────────────────────────
  Future<void> _fetchLyrics() async {
    if (currentSong == null) return;
    _lyrics = null;
    _syncedLines = null;
    _unsyncedLines = null;
    _lyricsSynced = false;
    _lyricsLoading = true;
    notifyListeners();

    final result = await _api.getLyrics(
      currentSong!.hash,
      filepath: currentSong!.filepath,
    );

    if (result != null) {
      _lyricsSynced = result['synced'] == true;
      final raw = result['lyrics'];
      if (_lyricsSynced && raw is List) {
        _syncedLines = List<Map<String, dynamic>>.from(
          raw.map((e) => {
            'time': (e['time'] as num).toInt(),
            'text': (e['text'] ?? '').toString(),
          }),
        );
        _lyrics = 'synced';
      } else if (raw is List) {
        _unsyncedLines = List<String>.from(raw.map((e) => e.toString()));
        _lyrics = _unsyncedLines!.join("\n");
      } else if (raw is String) {
        _lyrics = raw;
      }
    }

    _lyricsLoading = false;
    notifyListeners();
  }

  // ── Favourites ────────────────────────────────────────────────────────
  final Set<String> _favourites = {};

  bool isFavourite(String hash) => _favourites.contains(hash);

  Future<void> toggleFavourite(String hash) async {
    final wasLiked = _favourites.contains(hash);
    if (wasLiked) { _favourites.remove(hash); } else { _favourites.add(hash); }
    notifyListeners();
    final ok = await _api.toggleFavourite(hash);
    if (!ok) {
      if (wasLiked) { _favourites.add(hash); } else { _favourites.remove(hash); }
      notifyListeners();
    }
  }

  // Charger les favoris depuis le serveur au démarrage
  Future<void> _loadFavourites() async {
    try {
      final songs = await _api.getFavourites();
      _favourites.addAll(songs.map((s) => s.hash));
      notifyListeners();
    } catch (_) {}
  }

  // ── Cache playlists (évite les appels API répétés) ───────────────────
  List<dynamic> _cachedPlaylists = [];
  DateTime? _playlistsCachedAt;

  Future<List<dynamic>> getCachedPlaylists() async {
    final now = DateTime.now();
    // Rafraîchir si pas encore chargé ou si > 60 secondes
    if (_cachedPlaylists.isEmpty ||
        _playlistsCachedAt == null ||
        now.difference(_playlistsCachedAt!) > const Duration(seconds: 60)) {
      try {
        _cachedPlaylists = await _api.getPlaylists();
        _playlistsCachedAt = now;
      } catch (_) {}
    }
    return _cachedPlaylists;
  }

  /// Invalider le cache (après création/suppression de playlist)
  void invalidatePlaylistsCache() {
    _cachedPlaylists = [];
    _playlistsCachedAt = null;
  }

  // ── Sleep timer ───────────────────────────────────────────────────────
  Timer? _sleepTimer;
  Timer? _periodicTimer;  // Timer de tick pour le sleep timer
  DateTime? _sleepAt;
  Duration? get sleepRemaining {
    if (_sleepAt == null) return null;
    final rem = _sleepAt!.difference(DateTime.now());
    return rem.isNegative ? null : rem;
  }
  bool get hasSleepTimer => _sleepAt != null;

  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    if (minutes <= 0) {
      _sleepAt = null;
      notifyListeners();
      return;
    }
    _sleepAt = DateTime.now().add(Duration(minutes: minutes));
    _sleepTimer = Timer(Duration(minutes: minutes), () async {
      await _player.pause();
      _sleepAt = null;
      notifyListeners();
    });
    // Tick chaque minute pour mettre à jour le temps restant
    _periodicTimer?.cancel();  // Annuler l'ancien avant d'en creer un nouveau
    _periodicTimer = Timer.periodic(const Duration(minutes: 1), (t) {
      if (_sleepAt == null) { t.cancel(); _periodicTimer = null; return; }
      notifyListeners();
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _sleepAt = null;
    notifyListeners();
  }

  // ── Persistance queue ─────────────────────────────────────────────────

  /// Restaure la derniere queue et position au demarrage
  Future<void> _restoreQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIndex = prefs.getInt('queue_index') ?? 0;
      final savedPosition = prefs.getInt('queue_position') ?? 0;

      // Restauration depuis JSON (plus rapide que charger 5000 titres)
      final queueJson = prefs.getString('queue_json');
      if (queueJson == null || queueJson.isEmpty) return;

      final List<dynamic> decoded = json.decode(queueJson) as List<dynamic>;
      final restored = decoded
          .map((e) => Song.fromJson(e as Map<String, dynamic>))
          .toList();
      if (restored.isEmpty) return;

      _queue = restored;
      _currentIndex = savedIndex.clamp(0, restored.length - 1);

      // Charger le titre sans le jouer (juste mettre a jour l'UI)
      final song = _queue[_currentIndex];
      final artUrl = '${_api.baseUrl}/img/thumbnail/${song.image ?? song.hash}';
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(_api.getStreamUrl(song.hash, filepath: song.filepath)),
          headers: _api.authHeaders,
          tag: MediaItem(
            id:     song.hash,
            title:  song.title,
            artist: song.artist,
            album:  song.album,
            artUri: Uri.parse(artUrl),
          ),
        ),
      );
      // Seek a la position sauvegardee
      if (savedPosition > 0) {
        await _player.seek(Duration(seconds: savedPosition));
      }
      if (mounted) notifyListeners();
      debugPrint('Queue restauree : \${restored.length} titres, index \$_currentIndex');
    } catch (e) {
      debugPrint('Erreur restauration queue: \$e');
    }
  }

  Future<void> _persistQueue() async {
    if (_queue.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Sauvegarder les objets Song complets en JSON (restauration rapide)
      final queueJson = json.encode(_queue.map((s) => {
        'trackhash': s.hash, 'hash': s.hash, 'title': s.title,
        'artist': s.artist, 'album': s.album, 'albumhash': s.albumHash,
        'artisthash': s.artistHash, 'duration': s.duration,
        'filepath': s.filepath, 'image': s.image,
      }).toList());
      await prefs.setString('queue_json', queueJson);
      await prefs.setInt('queue_index', _currentIndex);
      await prefs.setInt('queue_position', _position.inSeconds);
    } catch (_) {}
  }

  // ── Historique ────────────────────────────────────────────────────────
  final List<Song> _history = [];
  List<Song> get history => List.unmodifiable(_history);

  void _addToHistory(Song song) {
    _history.removeWhere((s) => s.hash == song.hash);
    _history.insert(0, song);
    if (_history.length > 50) _history.removeLast();
    notifyListeners();
  }


  @override
  void dispose() {
    _disposed = true;
    _sleepTimer?.cancel();
    _periodicTimer?.cancel();
    _player.dispose();
    super.dispose();
  }
}