import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/song.dart';
import '../../services/api_service.dart';
import '../../services/color_service.dart';

class ColorManager {
  DynamicColors dynamicColors = DynamicColors.fallback();
  final SwingApiService _api = SwingApiService();

  Future<void> fetch(Song? currentSong, VoidCallback onUpdate, bool Function() isMounted) async {
    if (currentSong == null || !isMounted()) return;
    final cacheKey = currentSong.image ?? currentSong.hash;
    try {
      final url = '${_api.baseUrl}/img/thumbnail/$cacheKey';
      final r = await http
          .get(Uri.parse(url), headers: _api.authHeaders)
          .timeout(const Duration(seconds: 6));
      if (r.statusCode == 200 && r.bodyBytes.isNotEmpty && isMounted()) {
        dynamicColors = await ColorService.fromBytes(cacheKey, r.bodyBytes);
        if (isMounted()) onUpdate();
      }
    } catch (_) {}
  }
}
