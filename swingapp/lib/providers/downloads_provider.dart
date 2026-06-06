import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';
import '../models/album.dart'; // for Playlist
import '../services/api_service.dart';

class DownloadsProvider extends ChangeNotifier {
  final Set<String> _downloadedHashes = {};
  final Set<String> _offlinePlaylists = {};
  bool _isDownloadingPlaylist = false;

  List<Song> _downloadedSongs = [];
  List<Playlist> _downloadedPlaylists = [];
  
  Set<String> get downloadedHashes => _downloadedHashes;
  Set<String> get offlinePlaylists => _offlinePlaylists;
  bool get isDownloadingPlaylist => _isDownloadingPlaylist;

  List<Song> get downloadedSongs => _downloadedSongs;
  List<Playlist> get downloadedPlaylists => _downloadedPlaylists;

  DownloadsProvider() {
    refresh();
    _loadOfflinePlaylists();
  }

  Future<void> _loadOfflinePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('offline_playlists') ?? [];
    _offlinePlaylists.addAll(list);
    notifyListeners();
  }

  bool isDownloaded(String hash) => _downloadedHashes.contains(hash);
  bool isPlaylistOffline(String playlistId) => _offlinePlaylists.contains(playlistId);

  Future<void> loadOfflineData() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final offlineDir = Directory('${dir.path}/offline');
      if (!offlineDir.existsSync()) {
        _downloadedSongs = [];
        _downloadedPlaylists = [];
        notifyListeners();
        return;
      }

      final files = offlineDir.listSync().whereType<File>().toList();
      
      // 1. Charger les chansons téléchargées
      final songsList = <Song>[];
      final songMetaFiles = files.where((f) => f.path.endsWith('.meta.json') && !f.path.split('/').last.startsWith('playlist_'));
      for (final f in songMetaFiles) {
        try {
          final content = await f.readAsString();
          final meta = json.decode(content) as Map<String, dynamic>;
          songsList.add(Song(
            hash: meta['hash'] ?? '',
            title: meta['title'] ?? 'Unknown',
            artist: meta['artist'] ?? 'Unknown Artist',
            album: meta['album'] ?? 'Unknown Album',
            filepath: meta['filepath'],
            albumHash: '',
            artistHash: '',
            duration: meta['duration'] ?? 0,
            image: meta['image'],
          ));
        } catch (_) {}
      }
      _downloadedSongs = songsList;

      // 2. Charger les playlists téléchargées
      final playlistsList = <Playlist>[];
      final playlistMetaFiles = files.where((f) => f.path.endsWith('.meta.json') && f.path.split('/').last.startsWith('playlist_'));
      for (final f in playlistMetaFiles) {
        try {
          final content = await f.readAsString();
          final meta = json.decode(content) as Map<String, dynamic>;
          playlistsList.add(Playlist(
            id: meta['id']?.toString() ?? '',
            name: meta['name'] ?? 'Unnamed Playlist',
            description: meta['description'],
            trackCount: meta['trackCount'] ?? 0,
            imageHash: meta['imageHash'],
            isPublic: meta['isPublic'] == true,
          ));
        } catch (_) {}
      }
      _downloadedPlaylists = playlistsList;

      notifyListeners();
    } catch (_) {}
  }

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
    await loadOfflineData();
    notifyListeners();
  }

  Future<void> downloadSong(Song song, BuildContext? context, {bool showSnackBar = true}) async {
    if (!SwingApiService().canDownload) return;
    if (isDownloaded(song.hash)) return;
    
    if (showSnackBar && context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Téléchargement de ${song.title}…'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
    }
    
    final path = await SwingApiService().downloadTrack(song);
    
    if (path != null) {
      _downloadedHashes.add(song.hash);
      await loadOfflineData();
      notifyListeners();
      if (showSnackBar && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${song.title} téléchargé !'),
          backgroundColor: const Color(0xFF282828),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } else {
      if (showSnackBar && context != null && context.mounted) {
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
    await loadOfflineData();
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
    await loadOfflineData();
    notifyListeners();
  }

  Future<void> saveOfflinePlaylistMeta(Playlist playlist, List<Song> tracks) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/offline/playlist_${playlist.id}.meta.json');
      final data = {
        'id': playlist.id,
        'name': playlist.name,
        'description': playlist.description,
        'trackCount': playlist.trackCount,
        'imageHash': playlist.imageHash,
        'isPublic': playlist.isPublic,
        'tracks': tracks.map((t) => {
          'trackhash': t.hash,
          'title': t.title,
          'artist': t.artist,
          'album': t.album,
          'albumhash': t.albumHash,
          'artisthash': t.artistHash,
          'duration': t.duration,
          'track': t.trackNumber,
          'filepath': t.filepath,
          'image': t.image,
        }).toList(),
      };
      await file.writeAsString(json.encode(data));
    } catch (e) {
      debugPrint('Error saving playlist offline meta: $e');
    }
  }

  Future<void> deleteOfflinePlaylistMeta(String playlistId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/offline/playlist_${playlistId}.meta.json');
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }

  Future<List<Song>> getOfflinePlaylistTracks(String playlistId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/offline/playlist_${playlistId}.meta.json');
      if (!file.existsSync()) return [];
      
      final content = await file.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;
      final tracks = data['tracks'] as List?;
      if (tracks == null) return [];
      
      return tracks.map((t) {
        final hash = t['trackhash'] ?? t['hash'] ?? '';
        final fallbackPath = t['filepath'] as String?;
        return Song(
          hash: hash,
          title: t['title'] ?? 'Unknown',
          artist: t['artist'] ?? 'Unknown Artist',
          album: t['album'] ?? 'Unknown Album',
          filepath: fallbackPath,
          albumHash: t['albumhash'] ?? '',
          artistHash: t['artisthash'] ?? '',
          duration: t['duration'] ?? 0,
          image: t['image'] ?? hash,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> syncPlaylist(Playlist playlist, List<Song> tracks, {BuildContext? context}) async {
    final playlistId = playlist.id;
    if (!_offlinePlaylists.contains(playlistId)) {
      _offlinePlaylists.add(playlistId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('offline_playlists', _offlinePlaylists.toList());
      notifyListeners();
    }

    await saveOfflinePlaylistMeta(playlist, tracks);
    await loadOfflineData();
    
    final toDownload = tracks.where((s) => !isDownloaded(s.hash)).toList();
    if (toDownload.isEmpty) return;

    if (!_isDownloadingPlaylist) {
      _isDownloadingPlaylist = true;
      notifyListeners();
    }

    for (final song in toDownload) {
      await downloadSong(song, context, showSnackBar: false);
    }

    _isDownloadingPlaylist = false;
    await loadOfflineData();
    notifyListeners();
  }

  Future<void> unsyncPlaylist(String playlistId) async {
    if (_offlinePlaylists.contains(playlistId)) {
      _offlinePlaylists.remove(playlistId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('offline_playlists', _offlinePlaylists.toList());
      
      await deleteOfflinePlaylistMeta(playlistId);
      await loadOfflineData();
      
      notifyListeners();
    }
  }

  Future<void> autoSyncPlaylist(Playlist playlist, List<Song> tracks) async {
    final playlistId = playlist.id;
    if (_offlinePlaylists.contains(playlistId)) {
      await saveOfflinePlaylistMeta(playlist, tracks);
      await loadOfflineData();

      final toDownload = tracks.where((s) => !isDownloaded(s.hash)).toList();
      if (toDownload.isEmpty) return;

      if (!_isDownloadingPlaylist) {
        _isDownloadingPlaylist = true;
        notifyListeners();
      }

      for (final song in toDownload) {
        await downloadSong(song, null, showSnackBar: false);
      }

      _isDownloadingPlaylist = false;
      await loadOfflineData();
      notifyListeners();
    }
  }
}
