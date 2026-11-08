import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:just_audio_background/just_audio_background.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../services/api_service.dart';
import '../services/color_service.dart';
import '../services/widget_service.dart';
import '../services/network_quality_service.dart';
import '../widgets/artwork_widget.dart' show artCache;
import 'package:askaria/services/logger_service.dart';

part 'player/player_crossfade.dart';
part 'player/player_audio.dart';
part 'player/player_queue.dart';
part 'player/player_metadata.dart';
part 'player/player_storage.dart';



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
  final List<StreamSubscription> _subs = [];

  // Throttle positionStream — équilibre fluidité UI (4x/sec) et conso CPU
  DateTime _lastPositionNotify = DateTime.fromMillisecondsSinceEpoch(0);
  static const _positionNotifyThrottle = Duration(milliseconds: 250);

  // Debounce _persistQueue — évite d'écrire sur disque à chaque seekbar drag
  Timer? _persistDebounce;

  // Guard _updateWidget — évite les platform channels si rien n'a changé
  String? _lastWidgetSongHash;
  bool? _lastWidgetPlaying;

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

  /// `true` quand le titre en cours est lu depuis le stockage hors ligne.
  ///
  /// Le [Song] courant peut être un objet « réseau » alors que le lecteur a
  /// résolu un fichier local dans le dossier `/offline/` : on vérifie donc
  /// aussi la présence du fichier téléchargé.
  bool get isPlayingLocal {
    final song = currentSong;
    if (song == null) return false;
    final fp = song.filepath;
    if (fp != null && fp.contains('/offline/')) return true;
    final dir = _api.offlineDirPath;
    if (dir == null) return false;
    final extRaw = (fp ?? '').split('.').last.toLowerCase();
    final ext = (extRaw.isNotEmpty && extRaw.length <= 4 && extRaw != fp)
        ? extRaw
        : 'mp3';
    try {
      return File('$dir/${song.hash}.$ext').existsSync();
    } catch (_) {
      return false;
    }
  }
  bool get isLoading => _isLoading;
  bool get mounted => !_disposed;
  Duration get position => _position;
  Duration get duration {
    if (_duration > Duration.zero) return _duration;
    if (currentSong != null && currentSong!.duration > 0) {
      return Duration(seconds: currentSong!.duration);
    }
    return Duration.zero;
  }
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
  double get progress {
    final d = duration;
    return d.inMilliseconds > 0
        ? _position.inMilliseconds / d.inMilliseconds
        : 0.0;
  }

  // Volume
  double _volume = 1.0;
  double get volume => _volume;

  // ── Crossfade ──────────────────────────────────────────────────────────────
  int _crossfadeSeconds = 0;   // 0 = désactivé
  Timer? _crossfadeTimer;
  bool _crossfading = false;
  int _fadeId = 0;

  int get crossfadeSeconds => _crossfadeSeconds;



  final Set<String> _favourites = {};
  List<dynamic> _cachedPlaylists = [];
  DateTime? _playlistsCachedAt;
  Timer? _sleepTimer;
  Timer? _periodicTimer;
  DateTime? _sleepAt;
  Duration? get sleepRemaining {
    if (_sleepAt == null) return null;
    final rem = _sleepAt!.difference(DateTime.now());
    return rem.isNegative ? null : rem;
  }
  bool get hasSleepTimer => _sleepAt != null;
  void notify() => notifyListeners();

  //  Historique 
  final List<Song> _history = [];
  List<Song> get history => List.unmodifiable(_history);

  PlayerProvider() {
    _initPlayer();
    _loadFavourites();
    _loadCrossfade();
    _restoreQueue();
    NetworkQualityService.instance.addListener(_onQualityChanged);
  }

  void _onQualityChanged() {
    final song = currentSong;
    if (song != null && mounted) {
      final isLocal = song.filepath != null && song.filepath!.contains('/offline/');
      if (!isLocal && !song.hash.startsWith('dz_')) {
        _reloadPlaylistForQuality(song);
      }
    }
  }

  Future<void> _reloadPlaylistForQuality(Song song) async {
    final playing = _isPlaying;
    final position = _player.position;
    final index = _player.currentIndex ?? _currentIndex;
    final queue = List<Song>.from(_queue);
    if (queue.isEmpty || index < 0 || index >= queue.length) return;
    try {
      final sources = await Future.wait(queue.map(_buildSourceAsync));
      final queueUnchanged = _queue.length == queue.length &&
          Iterable<int>.generate(queue.length)
              .every((i) => _queue[i].hash == queue[i].hash);
      if (!mounted || !queueUnchanged || currentSong?.hash != song.hash) return;
      _playlist = ConcatenatingAudioSource(children: sources);
      await _player.setAudioSource(
        _playlist,
        initialIndex: index,
        initialPosition: position,
      );
      if (playing && mounted) await _player.play();
    } catch (_) {
      // Conserver la lecture en cours si le serveur ne peut pas changer le flux.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    NetworkQualityService.instance.removeListener(_onQualityChanged);
    for (final sub in _subs) { sub.cancel(); }
    _sleepTimer?.cancel();
    _periodicTimer?.cancel();
    _crossfadeTimer?.cancel();
    _persistDebounce?.cancel();
    _player.dispose();
    super.dispose();
  }
}


