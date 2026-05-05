import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/song.dart';
import '../../services/database_manager.dart';

class QueuePersistenceManager {
  Timer? _debounce;

  Future<void> restore(
    void Function(List<Song> queue, int index, int position) onRestore
  ) async {
    try {
      final prefs       = await SharedPreferences.getInstance();
      final savedIndex  = prefs.getInt('queue_index') ?? 0;
      final savedPos    = prefs.getInt('queue_position') ?? 0;

      final dbQueue = await DatabaseManager().loadQueue();
      if (dbQueue.isEmpty) return;

      final restored = dbQueue
          .map((e) => Song.fromJson(e))
          .toList();
      if (restored.isEmpty) return;

      onRestore(restored, savedIndex, savedPos);
    } catch (e) {
      debugPrint('Erreur restauration queue: $e');
    }
  }

  void persist(List<Song> queue, int currentIndex, Duration position, bool disposed) {
    if (queue.isEmpty || disposed) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), () async {
      if (disposed || queue.isEmpty) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        
        final queueMaps = queue.map((s) => {
          'trackhash': s.hash, 'hash': s.hash, 'title': s.title,
          'artist': s.artist, 'album': s.album, 'albumhash': s.albumHash,
          'artisthash': s.artistHash, 'duration': s.duration,
          'filepath': s.filepath, 'image': s.image,
        }).toList();
        
        await DatabaseManager().saveQueue(queueMaps);
        await prefs.setInt('queue_index', currentIndex);
        await prefs.setInt('queue_position', position.inSeconds);
      } catch (_) {}
    });
  }

  void dispose() {
    _debounce?.cancel();
  }
}
