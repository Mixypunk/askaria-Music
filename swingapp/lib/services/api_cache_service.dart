import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'logger_service.dart';

class ApiCacheService {
  static final ApiCacheService instance = ApiCacheService._();
  ApiCacheService._();

  Directory? _cacheDir;
  bool _initDone = false;

  Future<void> _init() async {
    if (_initDone) return;
    try {
      final temp = await getTemporaryDirectory();
      _cacheDir = Directory('${temp.path}/json_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      _initDone = true;
    } catch (e) {
      LoggerService.warning('Impossible d\'initialiser le cache JSON', e);
    }
  }

  String _hash(String url) {
    final bytes = utf8.encode(url);
    return md5.convert(bytes).toString();
  }

  /// Récupère la réponse mise en cache pour une URL donnée.
  /// Si maxAge est fourni et que le fichier est plus vieux, retourne null (cache expiré).
  Future<String?> getCachedResponse(String url, {Duration? maxAge}) async {
    await _init();
    if (_cacheDir == null) return null;

    final file = File('${_cacheDir!.path}/${_hash(url)}.json');
    if (await file.exists()) {
      try {
        if (maxAge != null) {
          final stat = await file.stat();
          if (DateTime.now().difference(stat.modified) > maxAge) {
            return null; // Expiré
          }
        }
        return await file.readAsString();
      } catch (e) {
        LoggerService.warning('Erreur lecture cache JSON: $url', e);
      }
    }
    return null;
  }

  /// Sauvegarde la réponse JSON dans le cache.
  Future<void> saveResponse(String url, String body) async {
    await _init();
    if (_cacheDir == null) return null;

    final file = File('${_cacheDir!.path}/${_hash(url)}.json');
    try {
      await file.writeAsString(body, flush: true);
    } catch (e) {
      LoggerService.warning('Erreur écriture cache JSON: $url', e);
    }
  }

  /// Vide l'intégralité du cache JSON.
  Future<void> clearCache() async {
    await _init();
    if (_cacheDir != null && await _cacheDir!.exists()) {
      try {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
      } catch (_) {}
    }
  }
}
