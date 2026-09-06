part of '../api_service.dart';

extension ApiStats on SwingApiService {
  // ── STATISTIQUES ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getStatsOverview() async {
    try {
      final r = await _authedGet(Uri.parse('$_baseUrl/stats/overview'));
      if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    } catch (e) { LoggerService.warning('Silent error caught in api_stats.dart', e); }
    return {};
  }

  Future<Map<String, dynamic>> getTopTracks({int limit = 10, String period = 'all'}) async {
    try {
      final uri = Uri.parse('$_baseUrl/stats/top-tracks')
          .replace(queryParameters: {'limit': '$limit', 'period': period});
      final r = await _authedGet(uri, useCache: true);
      if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    } catch (e) { LoggerService.warning('Silent error caught in api_stats.dart', e); }
    return {};
  }

  Future<Map<String, dynamic>> getTopArtists({int limit = 10, String period = 'all'}) async {
    try {
      final uri = Uri.parse('$_baseUrl/stats/top-artists')
          .replace(queryParameters: {'limit': '$limit', 'period': period});
      final r = await _authedGet(uri, useCache: true);
      if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    } catch (e) { LoggerService.warning('Silent error caught in api_stats.dart', e); }
    return {};
  }

  Future<Map<String, dynamic>> getHistory({int limit = 30}) async {
    try {
      final uri = Uri.parse('$_baseUrl/stats/history')
          .replace(queryParameters: {'limit': '$limit'});
      final r = await _authedGet(uri, useCache: true);
      if (r.statusCode == 200) return json.decode(r.body) as Map<String, dynamic>;
    } catch (e) { LoggerService.warning('Silent error caught in api_stats.dart', e); }
    return {};
  }

  Future<List<Map<String, dynamic>>> getHeatmap() async {
    try {
      final r = await _authedGet(Uri.parse('$_baseUrl/stats/heatmap'));
      if (r.statusCode == 200) {
        final data = json.decode(r.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['hours'] ?? []);
      }
    } catch (e) { LoggerService.warning('Silent error caught in api_stats.dart', e); }
    return [];
  }

  Future<List<Map<String, dynamic>>> getDailyStats({int days = 7}) async {
    try {
      final uri = Uri.parse('$_baseUrl/stats/daily')
          .replace(queryParameters: {'days': '$days'});
      final r = await _authedGet(uri, useCache: true);
      if (r.statusCode == 200) {
        final data = json.decode(r.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['items'] ?? []);
      }
    } catch (e) { LoggerService.warning('Silent error caught in api_stats.dart', e); }
    return [];
  }

  Future<List<Map<String, dynamic>>> getTopGenres() async {
    try {
      final r = await _authedGet(Uri.parse('$_baseUrl/stats/genres'));
      if (r.statusCode == 200) {
        final data = json.decode(r.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['items'] ?? []);
      }
    } catch (e) { LoggerService.warning('Silent error caught in api_stats.dart', e); }
    return [];
  }

}
