part of '../player_provider.dart';

extension PlayerCrossfade on PlayerProvider {
  Future<void> setCrossfade(int seconds) async {
    _crossfadeSeconds = seconds.clamp(0, 12);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('crossfade_seconds', _crossfadeSeconds);
    notify();
  }

  Future<void> _loadCrossfade() async {
    final prefs = await SharedPreferences.getInstance();
    _crossfadeSeconds = prefs.getInt('crossfade_seconds') ?? 0;
  }

  /// Démarre le fondu sortant et enchaîne sur le titre suivant.
  /// Appelé [_crossfadeSeconds] secondes avant la fin du titre.
  Future<void> _startCrossfade() async {
    if (_crossfading || _crossfadeSeconds <= 0) return;
    if (!_player.hasNext && _repeatMode != RepeatMode.all) return;
    _crossfading = true;

    final steps    = _crossfadeSeconds * 20;  // 20 ticks/s
    final interval = const Duration(milliseconds: 50);
    final startVol = _volume;
    int tick = 0;

    _crossfadeTimer?.cancel();
    _crossfadeTimer = Timer.periodic(interval, (t) async {
      tick++;
      final ratio = tick / steps;
      if (ratio >= 1.0 || !mounted) {
        t.cancel();
        _crossfading = false;
        // Passer au titre suivant et remettre le volume
        await _player.setVolume(0);
        await next();
        // Fade in
        await _fadeIn(startVol);
        return;
      }
      // Fade out progressif
      await _player.setVolume(startVol * (1.0 - ratio));
    });
  }

  Future<void> _fadeIn(double targetVolume) async {
    _fadeId++;
    final currentFadeId = _fadeId;
    const steps    = 30;
    const interval = Duration(milliseconds: 50);
    for (int i = 0; i <= steps; i++) {
      if (!mounted || _fadeId != currentFadeId) return;
      await _player.setVolume(targetVolume * (i / steps));
      await Future.delayed(interval);
    }
    if (_fadeId == currentFadeId && mounted) await _player.setVolume(targetVolume);
  }

  PlayerProvider() {
    _initPlayer();
}

}
