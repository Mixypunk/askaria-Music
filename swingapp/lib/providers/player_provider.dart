import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
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
  String? get error => _error;

  double get progress => _duration.inMilliseconds > 0
      ? _position.inMilliseconds / _duration.inMilliseconds : 0.0;

  PlayerProvider() {
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
  }

  Future<void> _loadAndPlay() async {
    if (currentSong == null) return;
    _error = null;
    try {
      final url = _api.getStreamUrl(currentSong!.hash, filepath: currentSong!.filepath);
      debugPrint('🎵 Stream: $url');
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(url), headers: _api.authHeaders),
      );
      await _player.play();
      notifyListeners();
    } catch (e) {
      _error = 'Erreur: $e';
      debugPrint('Stream error: $e');
      notifyListeners();
    }
  }

  // ── Track complete ─────────────────────────────────────────────────────
  void _onTrackComplete() {
    if (_queue.isEmpty) return;

    switch (_repeatMode) {
      case RepeatMode.one:
        // Rejouer la même chanson
        _player.seek(Duration.zero);
        _player.play();
        return;

      case RepeatMode.all:
        // Toujours passer à la suivante, boucler en fin de liste
        _nextTrack(loop: true);
        return;

      case RepeatMode.off:
        // Passer à la suivante, s'arrêter en fin de liste
        _nextTrack(loop: false);
        return;
    }
  }

  void _nextTrack({required bool loop}) {
    if (_shuffle) {
      final pos = _shufflePos;
      final nextPos = pos + 1;
      if (nextPos >= _shuffleOrder.length) {
        if (loop) {
          // Rebattre et recommencer
          _buildShuffleOrder();
          _currentIndex = _shuffleOrder[0];
          _loadAndPlay();
          _fetchLyrics();
        }
        // Sinon s'arrête
        return;
      }
      _currentIndex = _shuffleOrder[nextPos];
    } else {
      final next = _currentIndex + 1;
      if (next >= _queue.length) {
        if (loop) {
          _currentIndex = 0;
        } else {
          // Fin de la liste — on s'arrête sans crash
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

  Future<void> seek(Duration position) async => await _player.seek(position);

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
    if (currentSong == null) return;
    final song = currentSong!;
    final cacheKey = song.image ?? song.hash;
    try {
      final url = '${_api.baseUrl}/img/thumbnail/$cacheKey';
      final r = await http.get(Uri.parse(url), headers: _api.authHeaders)
          .timeout(const Duration(seconds: 6));
      if (r.statusCode == 200 && r.bodyBytes.isNotEmpty && mounted) {
        _dynamicColors = await ColorService.fromBytes(cacheKey, r.bodyBytes);
        notifyListeners();
      }
    } catch (_) {}
  }

  bool get mounted => true; // Provider est toujours actif tant qu'il n'est pas dispose

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

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
