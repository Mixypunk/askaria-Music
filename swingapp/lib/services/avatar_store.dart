import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'logger_service.dart';

/// Cache persistant des photos de profil.
///
/// Contrairement au cache d'artwork (répertoire temporaire, purgeable par
/// Android), les avatars sont stockés dans le répertoire *support* de l'app :
/// ils restent disponibles après un redémarrage et **sans réseau**.
///
/// Le store est un [ChangeNotifier] : quand une image est téléchargée ou
/// remplacée, tous les widgets [AvatarImage] montés se mettent à jour.
class AvatarStore extends ChangeNotifier {
  AvatarStore._();
  static final AvatarStore instance = AvatarStore._();

  final Map<int, Uint8List> _memory = {};
  final Map<int, Future<Uint8List?>> _inFlight = {};
  Future<Directory?>? _dirFuture;

  // ── Chemins ───────────────────────────────────────────────────────────────
  Future<Directory?> _ensureDir() => _dirFuture ??= _initDir();

  Future<Directory?> _initDir() async {
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}/avatars');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    } catch (e) {
      LoggerService.warning('AvatarStore: impossible de créer le dossier', e);
      return null;
    }
  }

  File? _fileFor(Directory? dir, int userId) =>
      dir == null ? null : File('${dir.path}/avatar_$userId.img');

  // ── Lecture ───────────────────────────────────────────────────────────────
  /// Version synchrone (RAM uniquement) : utile au premier build.
  Uint8List? memory(int userId) => _memory[userId];

  /// RAM → disque. Retourne `null` si aucune image n'a encore été mise en cache.
  Future<Uint8List?> cached(int userId) async {
    if (userId <= 0) return null;
    final ram = _memory[userId];
    if (ram != null) return ram;

    final file = _fileFor(await _ensureDir(), userId);
    if (file == null) return null;
    try {
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      _memory[userId] = bytes;
      return bytes;
    } catch (e) {
      LoggerService.warning('AvatarStore: lecture impossible ($userId)', e);
      return null;
    }
  }

  // ── Écriture ──────────────────────────────────────────────────────────────
  Future<void> save(int userId, Uint8List bytes) async {
    if (userId <= 0 || bytes.isEmpty) return;
    _memory[userId] = bytes;
    notifyListeners();
    try {
      final file = _fileFor(await _ensureDir(), userId);
      await file?.writeAsBytes(bytes, flush: true);
    } catch (e) {
      LoggerService.warning('AvatarStore: écriture impossible ($userId)', e);
    }
  }

  Future<void> forget(int userId) async {
    if (userId <= 0) return;
    _memory.remove(userId);
    notifyListeners();
    try {
      final file = _fileFor(await _ensureDir(), userId);
      if (file != null && await file.exists()) await file.delete();
    } catch (e) {
      LoggerService.warning('AvatarStore: suppression impossible ($userId)', e);
    }
  }

  // ── Réseau ────────────────────────────────────────────────────────────────
  /// Télécharge l'avatar puis le met en cache.
  ///
  /// Ne lève jamais d'exception : hors ligne (ou en cas d'erreur serveur) la
  /// version en cache reste utilisée. Les appels concurrents sont fusionnés.
  Future<Uint8List?> fetch({
    required int userId,
    required String url,
    Map<String, String>? headers,
  }) {
    if (userId <= 0 || url.isEmpty) return Future.value(null);
    final running = _inFlight[userId];
    if (running != null) return running;

    final future = _doFetch(userId: userId, url: url, headers: headers);
    _inFlight[userId] = future;
    future.whenComplete(() => _inFlight.remove(userId));
    return future;
  }

  Future<Uint8List?> _doFetch({
    required int userId,
    required String url,
    Map<String, String>? headers,
  }) async {
    try {
      final r = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
        await save(userId, r.bodyBytes);
        return r.bodyBytes;
      }
    } catch (e) {
      // Hors ligne : silencieux, on garde le cache disque.
      LoggerService.warning('AvatarStore: téléchargement ignoré ($userId)', e);
    }
    return null;
  }
}
