import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Gestionnaire de la base de données locale (Offline-first)
class DatabaseManager {
  static final DatabaseManager _instance = DatabaseManager._internal();
  factory DatabaseManager() => _instance;
  DatabaseManager._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'askaria_cache.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Table pour le cache des requêtes (Albums, Artistes, Playlists)
        await db.execute('''
          CREATE TABLE api_cache (
            key TEXT PRIMARY KEY,
            data TEXT
          )
        ''');

        // Table pour la file d'attente (Queue)
        await db.execute('''
          CREATE TABLE queue (
            idx INTEGER PRIMARY KEY,
            data TEXT
          )
        ''');
      },
    );
  }

  // ── CACHE API (Key-Value) ───────────────────────────────────────────────

  /// Sauvegarde une réponse JSON complète pour une clé donnée
  Future<void> saveCache(String key, dynamic data) async {
    final db = await database;
    await db.insert(
      'api_cache',
      {'key': key, 'data': json.encode(data)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Récupère les données en cache
  Future<dynamic> getCache(String key) async {
    final db = await database;
    final maps = await db.query(
      'api_cache',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return json.decode(maps.first['data'] as String);
    }
    return null;
  }

  // ── FILE D'ATTENTE (QUEUE) ───────────────────────────────────────────────

  /// Sauvegarde la file d'attente complète
  Future<void> saveQueue(List<Map<String, dynamic>> queueJson) async {
    final db = await database;
    final batch = db.batch();
    
    // On vide la table précédente
    batch.delete('queue');
    
    // On insère chaque piste avec son index
    for (int i = 0; i < queueJson.length; i++) {
      batch.insert('queue', {
        'idx': i,
        'data': json.encode(queueJson[i]),
      });
    }
    
    await batch.commit(noResult: true);
  }

  /// Charge la file d'attente sauvegardée
  Future<List<Map<String, dynamic>>> loadQueue() async {
    final db = await database;
    final maps = await db.query('queue', orderBy: 'idx ASC');
    
    if (maps.isEmpty) return [];
    
    return maps.map((row) {
      return json.decode(row['data'] as String) as Map<String, dynamic>;
    }).toList();
  }
}
