part of '../player_provider.dart';

extension PlayerAudio on PlayerProvider {
  void _initPlayer() {
    // Créer le player avec l'EQ dans le pipeline (Android uniquement)
    // L'EQ DOIT être dans le constructeur — impossible à ajouter après
    if (defaultTargetPlatform == TargetPlatform.android) {
      _player = AudioPlayer(
        audioPipeline: AudioPipeline(
          androidAudioEffects: [EqService.instance.equalizer],
        ),
      );
    } else {
      _player = AudioPlayer();
    }
    // Charger les réglages EQ — deux déclencheurs pour fiabilité :
    // 1. Dès la première source audio
    _player.playbackEventStream.first.then((_) {
      EqService.instance.loadSettings();
    }).catchError((_) {});
    // 2. Fallback après 2s si aucun event (player idle au démarrage)
    Future.delayed(const Duration(seconds: 2), () {
      if (EqService.instance.gains.isEmpty) {
        EqService.instance.loadSettings();
      }
    });

    // Écouter l'index courant — just_audio gère le passage automatique entre titres
    _subs.add(_player.currentIndexStream.listen((idx) {
      if (idx != null && idx != _currentIndex && idx < _queue.length) {
        _currentIndex = idx;
        _fetchLyrics();
        _fetchColors();
        _updateWidget();
        _persistQueue();
        notify();
      }
    }));

    _subs.add(_player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isLoading = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      if (state.processingState == ProcessingState.completed) {
        // Fin de la playlist complète
        if (_repeatMode == RepeatMode.all) {
          _player.seek(Duration.zero, index: 0);
          _player.play();
        }
      }
      _updateWidget();
      if (mounted) notify();
    }));

    _subs.add(_player.positionStream.listen((pos) {
      _position = pos;
      // Déclencher le crossfade N secondes avant la fin
      if (_crossfadeSeconds > 0 &&
          !_crossfading &&
          _duration.inSeconds > _crossfadeSeconds + 2 &&
          pos.inSeconds >= _duration.inSeconds - _crossfadeSeconds &&
          _isPlaying) {
        _startCrossfade();
      }
      // Throttle : ne notifier l'UI qu'au max toutes les 500ms
      // Les widgets qui ont besoin de la position exacte l'écoutent via StreamBuilder
      if (!mounted) return;
      final now = DateTime.now();
      if (now.difference(_lastPositionNotify) >= PlayerProvider._positionNotifyThrottle) {
        _lastPositionNotify = now;
        notify();
      }
    }));

    _subs.add(_player.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      if (mounted) notify();
    }));

    // Configurer la répétition dans just_audio
    _player.setLoopMode(LoopMode.off);
  }

  // ── Construction de la playlist ────────────────────────────────────────
  // Construit un AudioSource pour un titre (sync — utilise getStreamUrl)
  // Si le fichier est stocké localement (offline), utilise le chemin local
}


