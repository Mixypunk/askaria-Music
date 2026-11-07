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

  Future<Map<String, dynamic>> getTopTracks({int limit = 10, String period = 'all', bool forceRefresh = false}) async {
    try {
      final uri = Uri.parse('$_baseUrl/stats/top-tracks')
          .replace(queryParameters: {'limit': '$limit', 'period': period});
      var r = await _authedGet(uri, useCache: true, forceRefresh: forceRefresh);
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        if (data is Map<String, dynamic>) {
          final items = data['items'] as List?;
          if ((items == null || items.isEmpty) && !forceRefresh) {
            await ApiCacheService.instance.deleteCachedResponse(uri.toString());
            try {
              r = await _authedGet(uri, useCache: false);
              if (r.statusCode == 200) {
                final fresh = json.decode(r.body);
                if (fresh is Map<String, dynamic>) {
                  ApiCacheService.instance.saveResponse(uri.toString(), r.body);
                  return fresh;
                }
              }
            } catch (_) {}
          }
          return data;
        }
      }
    } catch (e) { LoggerService.warning('Silent error caught in api_stats.dart', e); }
    return {};
  }

  Future<Map<String, dynamic>> getTopArtists({int limit = 10, String period = 'all', bool forceRefresh = false}) async {
    try {
      final uri = Uri.parse('$_baseUrl/stats/top-artists')
          .replace(queryParameters: {'limit': '$limit', 'period': period});
      var r = await _authedGet(uri, useCache: true, forceRefresh: forceRefresh);
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        if (data is Map<String, dynamic>) {
          final items = data['items'] as List?;
          if ((items == null || items.isEmpty) && !forceRefresh) {
            await ApiCacheService.instance.deleteCachedResponse(uri.toString());
            try {
              r = await _authedGet(uri, useCache: false);
              if (r.statusCode == 200) {
                final fresh = json.decode(r.body);
                if (fresh is Map<String, dynamic>) {
                  ApiCacheService.instance.saveResponse(uri.toString(), r.body);
                  return fresh;
                }
              }
            } catch (_) {}
          }
          return data;
        }
      }
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
