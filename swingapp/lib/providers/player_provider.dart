import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../services/api_service.dart';
import '../services/color_service.dart';
import '../services/widget_service.dart';
import '../services/network_quality_service.dart';
import '../services/eq_service.dart';

enum RepeatMode { off, all, one }

class PlayerProvider extends ChangeNotifier {
  late final AudioPlayer _player;
  final SwingApiService _api = SwingApiService();
  final _random = Random();

  // ConcatenatingAudioSource — Android voit une vraie playlist
  // → affiche les boutons Précédent/Suivant dans la notification
  ConcatenatingAudioSource _playlist =
      ConcatenatingAudioSource(children: []);

  List<Song> _queue = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  RepeatMode _repeatMode = RepeatMode.off;
  bool _shuffle = false;
  String? _error;
  bool _disposed = false;

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
  Song? get currentSong =>
      _currentIndex >= 0 && _currentIndex < _queue.length
          ? _queue[_currentIndex]
          : null;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get mounted => !_disposed;
  Duration get position => _position;
  Duration get duration => _duration;
  RepeatMode get repeatMode => _repeatMode;
  bool get shuffle => _shuffle;
  String? get lyrics => _lyrics;
  bool get lyricsLoading => _lyricsLoading;
  bool get lyricsSynced => _lyricsSynced;
  List<Map<String, dynamic>>? get syncedLines => _syncedLines;
  List<String>? get unsyncedLines => _unsyncedLines;
  bool get hasLyrics =>
      !_lyricsLoading &&
      ((_syncedLines != null && _syncedLines!.isNotEmpty) ||
          (_unsyncedLines != null && _unsyncedLines!.isNotEmpty));
  String? get error => _error;
  double get progress => _duration.inMilliseconds > 0
      ? _position.inMilliseconds / _duration.inMilliseconds
      : 0.0;

  // Volume
  double _volume = 1.0;
  double get volume => _volume;

  // ── Crossfade ──────────────────────────────────────────────────────────────
  int _crossfadeSeconds = 0;   // 0 = désactivé
  Timer? _crossfadeTimer;
  bool _crossfading = false;

  int get crossfadeSeconds => _crossfadeSeconds;

  Future<void> setCrossfade(int seconds) async {
    _crossfadeSeconds = seconds.clamp(0, 12);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('crossfade_seconds', _crossfadeSeconds);
    notifyListeners();
  }

  Future<void> _loadCrossfade() async {
    final prefs = await SharedPreferences.getInstance();
    _crossfadeSeconds = prefs.getInt('crossfade_seconds') ?? 0;
  }

  /// Démarre le fondu sortant et enchaîne sur le titre suivant.
  /// Appelé [_crossfadeSeconds] secondes avant la fin du titre.
  Future<void> _startCrossfade() async {
    if (_crossfading || _crossfadeSeconds <= 0) return;
    if (!_player.hasNext && _repeatMode != RepeatMode.all) return;
    _crossfading = true;

    final steps    = _crossfadeSeconds * 20;  // 20 ticks/s
    final interval = const Duration(milliseconds: 50);
    final startVol = _volume;
    int tick = 0;

    _crossfadeTimer?.cancel();
    _crossfadeTimer = Timer.periodic(interval, (t) async {
      tick++;
      final ratio = tick / steps;
      if (ratio >= 1.0 || !mounted) {
        t.cancel();
        _crossfading = false;
        // Passer au titre suivant et remettre le volume
        await _player.setVolume(0);
        await next();
        // Fade in
        await _fadeIn(startVol);
        return;
      }
      // Fade out progressif
      await _player.setVolume(startVol * (1.0 - ratio));
    });
  }

  Future<void> _fadeIn(double targetVolume) async {
    const steps    = 30;
    const interval = Duration(milliseconds: 50);
    for (int i = 0; i <= steps; i++) {
      if (!mounted) return;
      await _player.setVolume(targetVolume * (i / steps));
      await Future.delayed(interval);
    }
    await _player.setVolume(targetVolume);
  }

  PlayerProvider() {
    _initPlayer();
    _loadFavourites();
    _loadCrossfade();
    _restoreQueue();
  }

  void _initPlayer() {
    // Créer le player avec l'EQ dans le pipeline (Android uniquement)
    // L'EQ DOIT être dans le constructeur — impossible à ajouter après
    if (defaultTargetPlatform == TargetPlatform.android) {
      _player = AudioPlayer(
        audioPipeline: AudioPipeline(
          androidAudioEffects: [EqService.instance.equalizer],
        ),
      );
    } else {
      _player = AudioPlayer();
    }
    // Charger les réglages EQ — deux déclencheurs pour fiabilité :
    // 1. Dès la première source audio
    _player.playbackEventStream.first.then((_) {
      EqService.instance.loadSettings();
    }).catchError((_) {});
    // 2. Fallback après 2s si aucun event (player idle au démarrage)
    Future.delayed(const Duration(seconds: 2), () {
      if (EqService.instance.gains.isEmpty) {
        EqService.instance.loadSettings();
      }
    });

    // Écouter l'index courant — just_audio gère le passage automatique entre titres
    _player.currentIndexStream.listen((idx) {
      if (idx != null && idx != _currentIndex && idx < _queue.length) {
        _currentIndex = idx;
        _fetchLyrics();
        _fetchColors();
        _updateWidget();
        _persistQueue();
        notifyListeners();
      }
    });

    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isLoading = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      if (state.processingState == ProcessingState.completed) {
        // Fin de la playlist complète
        if (_repeatMode == RepeatMode.all) {
          _player.seek(Duration.zero, index: 0);
          _player.play();
        }
      }
      _updateWidget();
      if (mounted) notifyListeners();
    });

    _player.positionStream.listen((pos) {
      _position = pos;
      // Déclencher le crossfade N secondes avant la fin
      if (_crossfadeSeconds > 0 &&
          !_crossfading &&
          _duration.inSeconds > _crossfadeSeconds + 2 &&
          pos.inSeconds >= _duration.inSeconds - _crossfadeSeconds &&
          _isPlaying) {
        _startCrossfade();
      }
      if (mounted) notifyListeners();
    });

    _player.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      if (mounted) notifyListeners();
    });

    // Configurer la répétition dans just_audio
    _player.setLoopMode(LoopMode.off);
  }

  // ── Construction de la playlist ────────────────────────────────────────
  // Construit un AudioSource pour un titre (sync — utilise getStreamUrl)
  // Si le fichier est stocké localement (offline), utilise le chemin local
  AudioSource _buildSource(Song song) {
    final localPath = song.filepath;
    final isLocal   = localPath != null &&
        (localPath.startsWith('/') || localPath.startsWith('file://')) &&
        !localPath.startsWith('/music');  // /music = NAS, pas local

    final uri = isLocal
        ? Uri.file(localPath)
        : Uri.parse(_api.getStreamUrl(song.hash, filepath: song.filepath));

    final headers = isLocal ? <String, String>{} : _api.authHeaders;

    return AudioSource.uri(
      uri,
      headers: headers,
      tag: MediaItem(
        id:     song.hash,
        title:  song.title,
        artist: song.artist ?? '',
        album:  song.album ?? '',
        artUri: Uri.parse(
            '${_api.baseUrl}/img/thumbnail/${song.image ?? song.hash}'),
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

  // Mise à jour asynchrone de l'artUri dans le MediaItem (pour la notification)
  Future<void> _updateArtUri(Song song, int index) async {
    if (index < 0 || index >= _playlist.length) return;
    try {
      final artUrl =
          '${_api.baseUrl}/img/thumbnail/${song.image ?? song.hash}';
      final localUri = await _cacheArtwork(artUrl, song.image ?? song.hash);
      // Remplacer la source avec l'artUri local
      final newSource = AudioSource.uri(
        Uri.parse(_api.getStreamUrl(song.hash, filepath: song.filepath)),
        headers: _api.authHeaders,
        tag: MediaItem(
          id:     song.hash,
          title:  song.title,
          artist: song.artist ?? '',
          album:  song.album ?? '',
          artUri: localUri,
        ),
      );
      await _playlist.removeRange(index, index + 1);
      await _playlist.insert(index, newSource);
    } catch (e) {
      debugPrint('_updateArtUri error: $e');
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
    notifyListeners();
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
    notifyListeners();
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
    notifyListeners();
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    _player.setShuffleModeEnabled(_shuffle);
    notifyListeners();
  }

  // ── Queue management ───────────────────────────────────────────────────
  void addToQueue(Song song) {
    if (!_queue.contains(song)) {
      _queue.add(song);
      _playlist.add(_buildSource(song));
      notifyListeners();
    }
  }

  void addNextInQueue(Song song) {
    _queue.remove(song);
    final insertAt = (_currentIndex + 1).clamp(0, _queue.length);
    _queue.insert(insertAt, song);
    _playlist.insert(insertAt, _buildSource(song));
    if (insertAt <= _currentIndex) _currentIndex++;
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index == _currentIndex) return;
    if (index < _currentIndex) _currentIndex--;
    _queue.removeAt(index);
    _playlist.removeRange(index, index + 1);
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex--;
    final song = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, song);
    // Reconstruire la playlist pour la réorganisation
    _rebuildPlaylist(startIndex: _currentIndex);
    if (oldIndex == _currentIndex) _currentIndex = newIndex;
    else if (oldIndex < _currentIndex && newIndex >= _currentIndex) _currentIndex--;
    else if (oldIndex > _currentIndex && newIndex <= _currentIndex) _currentIndex++;
    notifyListeners();
  }

  // ── Widget & notification ─────────────────────────────────────────────
  void _updateWidget() {
    if (currentSong == null) return;
    final song = currentSong!;
    final artUrl =
        '${_api.baseUrl}/img/thumbnail/${song.image ?? song.hash}';
    WidgetService.instance.update(
      title:     song.title,
      artist:    song.artist ?? '',
      artUrl:    artUrl,
      isPlaying: _isPlaying,
      authToken: _api.accessToken,
    );
  }

  // ── Cache pochette locale (notification Android) ──────────────────────
  final Map<String, Uri> _artCache = {};

  Future<Uri> _cacheArtwork(String url, String hash) async {
    if (_artCache.containsKey(hash)) return _artCache[hash]!;
    try {
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/art_$hash.jpg');
      if (await file.exists()) {
        return _artCache[hash] = file.uri;
      }
      final r = await http
          .get(Uri.parse(url), headers: _api.authHeaders)
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
        await file.writeAsBytes(r.bodyBytes);
        return _artCache[hash] = file.uri;
      }
    } catch (e) {
      debugPrint('cacheArtwork error: $e');
    }
    return Uri.parse(url);
  }

  // ── Dynamic colors ─────────────────────────────────────────────────────
  Future<void> _fetchColors() async {
    if (currentSong == null || !mounted) return;
    final song = currentSong!;
    final cacheKey = song.image ?? song.hash;
    try {
      final url = '${_api.baseUrl}/img/thumbnail/$cacheKey';
      final r = await http
          .get(Uri.parse(url), headers: _api.authHeaders)
          .timeout(const Duration(seconds: 6));
      if (r.statusCode == 200 && r.bodyBytes.isNotEmpty && mounted) {
        _dynamicColors = await ColorService.fromBytes(cacheKey, r.bodyBytes);
        if (mounted) notifyListeners();
      }
    } catch (_) {}
  }

  // ── Lyrics ─────────────────────────────────────────────────────────────
  Future<void> _fetchLyrics() async {
    if (currentSong == null) return;
    _lyrics = null;
    _syncedLines = null;
    _unsyncedLines = null;
    _lyricsSynced = false;
    _lyricsLoading = true;
    if (mounted) notifyListeners();

    final result = await _api.getLyrics(
      currentSong!.hash,
      filepath: currentSong!.filepath,
    );

    if (result != null) {
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
    if (mounted) notifyListeners();
  }

  // ── Favourites ─────────────────────────────────────────────────────────
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

  Future<void> _loadFavourites() async {
    try {
      final songs = await _api.getFavourites();
      _favourites.addAll(songs.map((s) => s.hash));
      if (mounted) notifyListeners();
    } catch (_) {}
  }

  // ── Cache playlists ────────────────────────────────────────────────────
  List<dynamic> _cachedPlaylists = [];
  DateTime? _playlistsCachedAt;

  Future<List<dynamic>> getCachedPlaylists() async {
    final now = DateTime.now();
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

  void invalidatePlaylistsCache() {
    _cachedPlaylists = [];
    _playlistsCachedAt = null;
  }

  // ── Sleep timer ────────────────────────────────────────────────────────
  Timer? _sleepTimer;
  Timer? _periodicTimer;
  DateTime? _sleepAt;
  Duration? get sleepRemaining {
    if (_sleepAt == null) return null;
    final rem = _sleepAt!.difference(DateTime.now());
    return rem.isNegative ? null : rem;
  }
  bool get hasSleepTimer => _sleepAt != null;

  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    if (minutes <= 0) { _sleepAt = null; notifyListeners(); return; }
    _sleepAt = DateTime.now().add(Duration(minutes: minutes));
    _sleepTimer = Timer(Duration(minutes: minutes), () async {
      await _player.pause();
      _sleepAt = null;
      notifyListeners();
    });
    _periodicTimer?.cancel();
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

  // ── Historique ─────────────────────────────────────────────────────────
  final List<Song> _history = [];
  List<Song> get history => List.unmodifiable(_history);

  void _addToHistory(Song song) {
    _history.removeWhere((s) => s.hash == song.hash);
    _history.insert(0, song);
    if (_history.length > 50) _history.removeLast();
    notifyListeners();
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

      if (mounted) notifyListeners();
      debugPrint('Queue restaurée : ${restored.length} titres, index $_currentIndex');
    } catch (e) {
      debugPrint('Erreur restauration queue: $e');
    }
  }

  Future<void> _persistQueue() async {
    if (_queue.isEmpty) return;
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
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _sleepTimer?.cancel();
    _periodicTimer?.cancel();
    _crossfadeTimer?.cancel();
    _player.dispose();
    super.dispose();
  }
}
