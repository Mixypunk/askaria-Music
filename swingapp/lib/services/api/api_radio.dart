part of '../api_service.dart';

extension ApiRadio on SwingApiService {
  // ── RADIO ─────────────────────────────────────────────────────────────────
  Future<List<Song>> getRadio(String seedHash, {int limit = 30}) async {
    try {
      final uri = Uri.parse('$_baseUrl/radio/$seedHash')
          .replace(queryParameters: {'limit': '$limit'});
      final r = await _authedGet(uri);
      if (r.statusCode == 200) {
        final data  = json.decode(r.body) as Map<String, dynamic>;
        final items = (data['tracks'] as List?) ?? [];
        return items
            .map((e) => Song.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('getRadio error: $e');
    }
    return [];
  }
  Future<List<double>?> getWaveform(String hash) async {
    try {
      final r = await _authedGet(Uri.parse('$_baseUrl/waveform/$hash'));
      if (r.statusCode == 200) {
        final data = json.decode(r.body) as Map<String, dynamic>;
        final peaks = data['peaks'] as List?;
        return peaks?.map((v) => (v as num).toDouble()).toList();
      }
    } catch (e) { LoggerService.warning('Silent error caught in api_radio.dart', e); }
    return null;
  }
}
