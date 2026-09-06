part of '../api_service.dart';

extension ApiOffline on SwingApiService {
  // ── TÉLÉCHARGEMENT OFFLINE ───────────────────────────────────────────────────
  String getDownloadUrl(String hash) => '$_baseUrl/download/$hash';

  Future<String?> downloadTrack(Song song, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final offlineDir = Directory('${dir.path}/offline');
      await offlineDir.create(recursive: true);

      // Utilise l'extension du filepath ; fallback sur 'mp3' si absent
      final rawExt = (song.filepath ?? '').split('.').last.toLowerCase();
      final ext = (rawExt.isNotEmpty && rawExt.length <= 4 && rawExt != song.filepath) ? rawExt : 'mp3';
      final safe = '${song.hash}.$ext';
      final file = File('${offlineDir.path}/$safe');

      if (await file.exists()) {
        // Recréer les métadonnées si manquantes (migration)
        await _saveOfflineMeta(song, file.path, ext: ext);
        return file.path;
      }

      final uri = Uri.parse(getDownloadUrl(song.hash));
      final req  = http.Request('GET', uri);
      req.headers['Authorization'] = 'Bearer $_accessToken';

      try {
        final streamed = await _client.send(req);

        if (streamed.statusCode != 200) { return null; }

        final total  = streamed.contentLength ?? -1;
        int received = 0;
        final sink   = file.openWrite();
        await for (final chunk in streamed.stream) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        }
        await sink.close();
        
        // Sauvegarder les métadonnées pour affichage dans Downloads screen
        await _saveOfflineMeta(song, file.path, ext: ext);

        return file.path;
      } finally {
        
      }
    } catch (e) {
      debugPrint('downloadTrack error: $e');
      return null;
    }
  }

  Future<void> _saveOfflineMeta(Song song, String filePath, {String ext = 'mp3'}) async {
    try {
      final dir     = await getApplicationDocumentsDirectory();
      final metaFile = File('${dir.path}/offline/${song.hash}.meta.json');
      final meta = {
        'hash':       song.hash,
        'title':      song.title,
        'artist':     song.artist,
        'album':      song.album,
        'duration':   song.duration,
        'image':      song.image ?? song.hash,
        'filepath':   filePath,
        'ext':        ext,
        'downloaded': DateTime.now().toIso8601String(),
      };
      await metaFile.writeAsString(json.encode(meta));
    } catch (e) { debugPrint('meta error: $e'); }
  }

  Future<Map<String, dynamic>?> getOfflineMeta(String hash) async {
    try {
      final dir      = await getApplicationDocumentsDirectory();
      final metaFile = File('${dir.path}/offline/$hash.meta.json');
      if (!metaFile.existsSync()) return null;
      return json.decode(metaFile.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) { return null; }
  }

  /// Retourne l'extension stockée dans le meta, ou déduit depuis filepath, ou 'mp3'.
  String _resolveExt(String filepath, [Map<String, dynamic>? meta]) {
    final fromMeta = meta?['ext'] as String?;
    if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;
    final raw = filepath.split('.').last.toLowerCase();
    return (raw.isNotEmpty && raw.length <= 4 && raw != filepath) ? raw : 'mp3';
  }

  Future<bool> isDownloaded(String hash, String filepath) async {
    try {
      final dir  = await getApplicationDocumentsDirectory();
      // Priorité : lire l'ext depuis le meta si disponible
      final meta = await getOfflineMeta(hash);
      final ext  = _resolveExt(filepath, meta);
      final file = File('${dir.path}/offline/$hash.$ext');
      return file.existsSync();
    } catch (_) { return false; }
  }

  Future<String?> getOfflinePath(String hash, String filepath) async {
    try {
      final dir  = await getApplicationDocumentsDirectory();
      final meta = await getOfflineMeta(hash);
      // Utiliser le filepath sauvegardé dans le meta (le plus fiable)
      final savedPath = meta?['filepath'] as String?;
      if (savedPath != null && File(savedPath).existsSync()) return savedPath;
      // Fallback : reconstruire depuis le hash + extension
      final ext  = _resolveExt(filepath, meta);
      final file = File('${dir.path}/offline/$hash.$ext');
      return file.existsSync() ? file.path : null;
    } catch (_) { return null; }
  }

  Future<List<Map<String, dynamic>>> getDownloadedTracks() async {
    try {
      final dir      = await getApplicationDocumentsDirectory();
      final offlineDir = Directory('${dir.path}/offline');
      if (!offlineDir.existsSync()) return [];
      return offlineDir
          .listSync()
          .whereType<File>()
          .map((f) => {'path': f.path, 'hash': f.path.split('/').last.split('.').first})
          .toList();
    } catch (_) { return []; }
  }

  Future<void> deleteOfflineTrack(String hash, String filepath) async {
    try {
      final dir  = await getApplicationDocumentsDirectory();
      final meta = await getOfflineMeta(hash);
      final ext  = _resolveExt(filepath, meta);
      final file = File('${dir.path}/offline/$hash.$ext');
      if (file.existsSync()) await file.delete();
      // Supprimer aussi le fichier meta
      final metaFile = File('${dir.path}/offline/$hash.meta.json');
      if (metaFile.existsSync()) await metaFile.delete();
    } catch (e) { debugPrint('delete offline error: $e'); }
  }
}
