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
  /// Valide l'intégrité du JSON : si le fichier est corrompu ou vide, il est supprimé.
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
        final content = await file.readAsString();
        final trimmed = content.trim();
        if (trimmed.isEmpty || (!trimmed.startsWith('{') && !trimmed.startsWith('['))) {
          // Contenu invalide, supprimer le cache empoisonné
          await deleteCachedResponse(url);
          return null;
        }

        // Vérification syntaxique rapide pour éviter d'empoisonner l'UI
        try {
          final decoded = json.decode(trimmed);
          if (decoded is Map && (decoded.containsKey('detail') || decoded.containsKey('error'))) {
            // C'était une erreur serveur enregistrée par mégarde
            await deleteCachedResponse(url);
            return null;
          }
        } catch (_) {
          await deleteCachedResponse(url);
          return null;
        }

        return content;
      } catch (e) {
        LoggerService.warning('Erreur lecture cache JSON: $url', e);
        await deleteCachedResponse(url);
      }
    }
    return null;
  }

  /// Sauvegarde la réponse JSON dans le cache de manière atomique.
  /// Ne sauvegarde que si le corps est un JSON valide et ne contient pas d'erreur.
  Future<void> saveResponse(String url, String body) async {
    await _init();
    if (_cacheDir == null) return;

    final trimmed = body.trim();
    if (trimmed.isEmpty || (!trimmed.startsWith('{') && !trimmed.startsWith('['))) {
      return; // Ne pas cacher des réponses non-JSON ou vides
    }

    // Vérifier que c'est du JSON valide et pas une réponse d'erreur
    try {
      final decoded = json.decode(trimmed);
      if (decoded is Map && (decoded.containsKey('detail') || decoded.containsKey('error'))) {
        return; // Ne pas cacher les erreurs API
      }
    } catch (_) {
      return; // JSON malformé, ne pas cacher
    }

    final targetPath = '${_cacheDir!.path}/${_hash(url)}.json';
    final tempPath = '$targetPath.tmp';
    try {
      final tempFile = File(tempPath);
      await tempFile.writeAsString(body, flush: true);
      await tempFile.rename(targetPath);
    } catch (e) {
      LoggerService.warning('Erreur écriture cache JSON: $url', e);
      // Nettoyer le fichier temporaire en cas d'erreur
      try {
        final tmp = File(tempPath);
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
    }
  }

  /// Supprime le fichier de cache associé à une URL spécifique.
  Future<void> deleteCachedResponse(String url) async {
    await _init();
    if (_cacheDir == null) return;

    try {
      final file = File('${_cacheDir!.path}/${_hash(url)}.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
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
