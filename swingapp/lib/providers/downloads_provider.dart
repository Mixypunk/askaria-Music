import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/api_service.dart';

class DownloadsProvider extends ChangeNotifier {
  final Set<String> _downloadedHashes = {};
  bool _isDownloadingPlaylist = false;
  
  Set<String> get downloadedHashes => _downloadedHashes;
  bool get isDownloadingPlaylist => _isDownloadingPlaylist;

  DownloadsProvider() {
    refresh();
  }

  bool isDownloaded(String hash) => _downloadedHashes.contains(hash);

  Future<void> refresh() async {
    final tracks = await SwingApiService().getDownloadedTracks();
    _downloadedHashes.clear();
    for (var t in tracks) {
      if (t['hash'] != null) {
        // Ignorer les fichiers meta
        if (!t['path'].toString().endsWith('.meta.json')) {
          _downloadedHashes.add(t['hash']);
        }
      }
    }
    notifyListeners();
  }

  Future<void> downloadSong(Song song, BuildContext context, {bool showSnackBar = true}) async {
    if (isDownloaded(song.hash)) return;
    
    if (showSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Téléchargement de ${song.title}…'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
    }
    
    final path = await SwingApiService().downloadTrack(song);
    
    if (path != null) {
      _downloadedHashes.add(song.hash);
      notifyListeners();
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${song.title} téléchargé !'),
          backgroundColor: const Color(0xFF282828),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } else {
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Échec du téléchargement'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> downloadPlaylist(List<Song> songs, BuildContext context) async {
    if (_isDownloadingPlaylist) return;
    _isDownloadingPlaylist = true;
    notifyListeners();

    final toDownload = songs.where((s) => !isDownloaded(s.hash)).toList();
    if (toDownload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Toute la playlist est déjà téléchargée'),
        behavior: SnackBarBehavior.floating,
      ));
      _isDownloadingPlaylist = false;
      notifyListeners();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Téléchargement de ${toDownload.length} titre(s)...'),
      behavior: SnackBarBehavior.floating,
    ));

    int count = 0;
    for (final song in toDownload) {
      if (!context.mounted) break;
      await downloadSong(song, context, showSnackBar: false);
      count++;
    }

    _isDownloadingPlaylist = false;
    notifyListeners();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$count titre(s) téléchargé(s) avec succès !'),
        backgroundColor: const Color(0xFF282828),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> deleteSong(String hash, String? filepath) async {
    await SwingApiService().deleteOfflineTrack(hash, filepath ?? '');
    _downloadedHashes.remove(hash);
    notifyListeners();
  }
}
