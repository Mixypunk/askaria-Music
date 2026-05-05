import 'package:flutter/foundation.dart';
import '../../models/song.dart';
import '../../services/api_service.dart';

class LyricsManager {
  String? lyrics;
  bool loading = false;
  bool synced = false;
  List<Map<String, dynamic>>? syncedLines;
  List<String>? unsyncedLines;

  final SwingApiService _api = SwingApiService();

  bool get hasLyrics =>
      !loading &&
      ((syncedLines != null && syncedLines!.isNotEmpty) ||
          (unsyncedLines != null && unsyncedLines!.isNotEmpty));

  Future<void> fetch(Song? currentSong, VoidCallback onUpdate) async {
    if (currentSong == null) return;
    lyrics = null;
    syncedLines = null;
    unsyncedLines = null;
    synced = false;
    loading = true;
    onUpdate();

    final result = await _api.getLyrics(
      currentSong.hash,
      filepath: currentSong.filepath,
    );

    if (result != null) {
      synced = result['synced'] == true;
      final raw = result['lyrics'];
      if (synced && raw is List) {
        syncedLines = List<Map<String, dynamic>>.from(raw.map((e) => {
          'time': (e['time'] as num).toInt(),
          'text': (e['text'] ?? '').toString(),
        }));
        lyrics = 'synced';
      } else if (raw is List) {
        unsyncedLines = List<String>.from(raw.map((e) => e.toString()));
        lyrics = unsyncedLines!.join('\n');
      } else if (raw is String) {
        lyrics = raw;
      }
    }

    loading = false;
    onUpdate();
  }
}
