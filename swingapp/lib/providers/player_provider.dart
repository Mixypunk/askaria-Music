import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import '../services/api_service.dart';

enum RepeatMode { off, all, one }

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final SwingApiService _api = SwingApiService();

  List<Song> _queue = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  RepeatMode _repeatMode = RepeatMode.off;
  bool _shuffle = false;
  String? _lyrics;
  bool _lyricsLoading = false;
  bool _lyricsSynced = false;
  String? _error;

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
  String? get error => _error;

  double get progress => _duration.inMilliseconds > 0
      ? _position.inMilliseconds / _duration.inMilliseconds : 0.0;

  PlayerProvider() {
    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isLoading = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      if (state.processingState == ProcessingState.completed) _onTrackComplete();
      notifyListeners();
    });
    _player.positionStream.listen((pos) { _position = pos; notifyListeners(); });
    _player.durationStream.listen((dur) { _duration = dur ?? Duration.zero; notifyListeners(); });
  }

  Future<void> playSong(Song song, {List<Song>? queue, int? index}) async {
    if (queue != null) {
      _queue = List.from(queue);
      _currentIndex = index ?? queue.indexOf(song);
    } else if (!_queue.contains(song)) {
      _queue.add(song);
      _currentIndex = _queue.length - 1;
    } else {
      _currentIndex = _queue.indexOf(song);
    }
    await _loadAndPlay();
    _fetchLyrics();
  }

  Future<void> _loadAndPlay() async {
    if (currentSong == null) return;
    _error = null;
    try {
      // Format officiel: /file/{trackhash}/legacy?filepath={encodedPath}
      final url = _api.getStreamUrl(currentSong!.hash, filepath: currentSong!.filepath);
      debugPrint('🎵 Stream: $url');

      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          headers: _api.authHeaders, // Authorization: Bearer {token}
        ),
      );
      await _player.play();
      notifyListeners();
    } catch (e) {
      _error = 'Erreur: $e';
      debugPrint('Stream error: $e');
      notifyListeners();
    }
  }

  void _onTrackComplete() {
    switch (_repeatMode) {
      case RepeatMode.one:
        _player.seek(Duration.zero); _player.play(); break;
      case RepeatMode.all:
        _currentIndex = (_currentIndex + 1) % _queue.length;
        _loadAndPlay(); _fetchLyrics(); break;
      case RepeatMode.off:
        if (_currentIndex < _queue.length - 1) next(); break;
    }
  }

  Future<void> playPause() async {
    if (_isPlaying) await _player.pause();
    else await _player.play();
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    _currentIndex = _shuffle
        ? DateTime.now().millisecondsSinceEpoch % _queue.length
        : (_currentIndex + 1) % _queue.length;
    await _loadAndPlay(); _fetchLyrics();
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (_position.inSeconds > 3) { await _player.seek(Duration.zero); return; }
    _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
    await _loadAndPlay(); _fetchLyrics();
  }

  Future<void> seek(Duration position) async => await _player.seek(position);

  void addToQueue(Song song) {
    if (!_queue.contains(song)) { _queue.add(song); notifyListeners(); }
  }

  void removeFromQueue(int index) {
    if (index == _currentIndex) return;
    if (index < _currentIndex) _currentIndex--;
    _queue.removeAt(index);
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex--;
    final song = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, song);
    if (oldIndex == _currentIndex) _currentIndex = newIndex;
    else if (oldIndex < _currentIndex && newIndex >= _currentIndex) _currentIndex--;
    else if (oldIndex > _currentIndex && newIndex <= _currentIndex) _currentIndex++;
    notifyListeners();
  }

  void toggleRepeat() {
    _repeatMode = RepeatMode.values[(_repeatMode.index + 1) % RepeatMode.values.length];
    notifyListeners();
  }

  void toggleShuffle() { _shuffle = !_shuffle; notifyListeners(); }

  List<Map<String,dynamic>>? _syncedLines; // [{time: ms, text: str}]
  List<String>? _unsyncedLines;           // [str, str, ...]

  List<Map<String,dynamic>>? get syncedLines => _syncedLines;
  List<String>? get unsyncedLines => _unsyncedLines;

  Future<void> _fetchLyrics() async {
    if (currentSong == null) return;
    _lyrics = null; _syncedLines = null; _unsyncedLines = null;
    _lyricsSynced = false; _lyricsLoading = true; notifyListeners();

    final result = await _api.getLyrics(
      currentSong!.hash,
      filepath: currentSong!.filepath,
    );
    if (result != null) {
      _lyricsSynced = result['synced'] == true;
      final raw = result['lyrics'];
      if (_lyricsSynced && raw is List) {
        // [{time: double/int ms, text: str}, ...]
        _syncedLines = List<Map<String,dynamic>>.from(
          raw.map((e) => {'time': (e['time'] as num).toInt(), 'text': e['text'] as String})
        );
        _lyrics = 'synced';
      } else if (raw is List) {
        _unsyncedLines = List<String>.from(raw.map((e) => e.toString()));
        _lyrics = _unsyncedLines!.join("\n");
      } else if (raw is String) {
        _lyrics = raw;
      }
    }
    _lyricsLoading = false; notifyListeners();
  }

  @override
  void dispose() { _player.dispose(); super.dispose(); }
}
