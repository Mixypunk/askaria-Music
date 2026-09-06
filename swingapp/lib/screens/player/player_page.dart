part of '../player_screen.dart';

class _PlayerPage extends StatelessWidget {
  final PlayerProvider player;
  final song;
  final Color accent;
  final VoidCallback onLyricsTap;
  const _PlayerPage({
    required this.player, required this.song,
    required this.accent, required this.onLyricsTap});

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  String _fmtRemaining(Duration? d) {
    if (d == null) return '';
    if (d.inHours > 0) return '${d.inHours}h${d.inMinutes.remainder(60)}min';
    return '${d.inMinutes}min';
  }

  Future<void> _showAddToPlaylist(BuildContext ctx, song) async {
    // Utiliser le cache du provider
    final player = ctx.read<PlayerProvider>();
    final playlists = await player.getCachedPlaylists();
    if (!ctx.mounted) return;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF282828),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              Container(width: 36, height: 4, margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
              const Text('Ajouter à une playlist',
                style: TextStyle(color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.bold)),
            ])),
          const Divider(color: Colors.white12, height: 1),
          if (playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Aucune playlist disponible',
                style: TextStyle(color: Colors.white54)))
          else
            SizedBox(
              height: playlists.length > 4 ? 250 : null,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (_, i) {
                  final pl = playlists[i];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: NetImage(
                        url: '${SwingApiService().baseUrl}/img/playlist/${pl.id}.webp',
                        width: 44, height: 44,
                        headers: SwingApiService().authHeaders,
                        borderRadius: BorderRadius.circular(4),
                        placeholder: Container(width: 44, height: 44,
                          color: Sp.card, child: const Icon(
                              Icons.queue_music_rounded,
                              color: Colors.white38, size: 20)))),
                    title: Text(pl.name,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${pl.trackCount} titre${pl.trackCount != 1 ? "s" : ""}',
                      style: const TextStyle(color: Colors.white54,
                          fontSize: 12)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final ok = await SwingApiService()
                          .addTracksToPlaylist(pl.id, [song.hash]);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(ok
                            ? 'Ajouté à « ${pl.name} »'
                            : 'Erreur lors de l\'ajout'),
                          behavior: SnackBarBehavior.floating));
                      }
                    });
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // La méthode de téléchargement a été déplacée dans DownloadsProvider

  void _showSleepTimer(BuildContext ctx, PlayerProvider player) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF282828),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          const Row(children: [
            Icon(Icons.bedtime_rounded, color: Colors.blueAccent, size: 22),
            SizedBox(width: 10),
            Text('Timer de sommeil', style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 20),
          // Options de durée
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final min in [15, 30, 45, 60, 90])
              GestureDetector(
                onTap: () { player.setSleepTimer(min); Navigator.pop(ctx); },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A3A),
                    borderRadius: BorderRadius.circular(24)),
                  child: Text('${min}min',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)))),
          ]),
          if (player.hasSleepTimer) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () { player.cancelSleepTimer(); Navigator.pop(ctx); },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.redAccent.withOpacity(0.6)),
                  borderRadius: BorderRadius.circular(8)),
                child: const Center(child: Text('Annuler le timer',
                  style: TextStyle(color: Colors.redAccent,
                      fontWeight: FontWeight.bold))))),
          ],
        ]),
      ),
    );
  }

  void _showShareSheet(BuildContext ctx, song, Color accent) {
    final api   = SwingApiService();
    final url   = api.getStreamUrl(song.hash, filepath: song.filepath);
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF282828),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          Text(song.title, style: const TextStyle(color: Colors.white,
              fontSize: 16, fontWeight: FontWeight.bold)),
          Text(song.artist,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
          const SizedBox(height: 8),
          // URL de stream (copiable)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(6)),
            child: Text(url,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              maxLines: 2, overflow: TextOverflow.ellipsis)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _ShareBtn(Icons.copy_rounded, 'Copier le lien', () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                content: const Text('Lien copié dans le presse-papier !'),
                backgroundColor: accent,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2)));
            }),
            _ShareBtn(Icons.share_rounded, 'Partager', () {
              Navigator.pop(ctx);
              Share.share(
                '\${song.title} — \${song.artist}\n\$url',
                subject: song.title,
              );
            }),
            _ShareBtn(Icons.info_outline_rounded, 'Infos', () {
              Navigator.pop(ctx);
              showDialog(context: ctx, builder: (_) => AlertDialog(
                backgroundColor: const Color(0xFF282828),
                title: Text(song.title,
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
                content: Column(mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _InfoRow('Artiste', song.artist),
                  _InfoRow('Album',   song.album),
                  _InfoRow('Durée',
                    '${song.duration ~/ 60}:${(song.duration % 60).toString().padLeft(2,"0")}'),
                ]),
                actions: [TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Fermer', style: TextStyle(color: accent)))],
              ));
            }),
          ]),
        ]),
      ),
    );
  }

  void _showDevicesSheet(BuildContext ctx, Color accent) {
    final connect = ctx.read<ConnectControllerProvider>();
    connect.startDiscovery();
    
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF282828),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Lecture sur', style: TextStyle(color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.bold)),
              Consumer<ConnectControllerProvider>(
                builder: (_, c, __) => c.isScanning 
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: accent))
                  : const SizedBox(),
              )
            ]
          ),
          const SizedBox(height: 16),
          Consumer<ConnectControllerProvider>(
            builder: (ctx, c, _) {
              return Column(
                children: [
                  ListTile(contentPadding: EdgeInsets.zero,
                    leading: Container(width: 44, height: 44,
                      decoration: BoxDecoration(
                          color: !c.isConnected ? accent.withOpacity(0.2) : Colors.white10,
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.phone_android_rounded, 
                          color: !c.isConnected ? accent : Colors.white54, size: 24)),
                    title: Text('Cet appareil',
                        style: TextStyle(
                            color: !c.isConnected ? Colors.white : Colors.white54, 
                            fontWeight: FontWeight.w600)),
                    subtitle: !c.isConnected ? Text('Connecté', style: TextStyle(color: accent, fontSize: 12)) : null,
                    trailing: !c.isConnected ? Icon(Icons.check_circle_rounded, color: accent, size: 20) : null,
                    onTap: () {
                      c.disconnect();
                      Navigator.pop(ctx);
                    },
                  ),
                  for (final device in c.devices)
                    ListTile(contentPadding: EdgeInsets.zero,
                      leading: Container(width: 44, height: 44,
                        decoration: BoxDecoration(
                            color: c.connectedDevice == device ? accent.withOpacity(0.2) : Colors.white10,
                            borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.tv_rounded, 
                            color: c.connectedDevice == device ? accent : Colors.white54, size: 24)),
                      title: Text(device.name,
                          style: TextStyle(
                              color: c.connectedDevice == device ? Colors.white : Colors.white70, 
                              fontWeight: FontWeight.w600)),
                      subtitle: c.connectedDevice == device ? Text('Connecté', style: TextStyle(color: accent, fontSize: 12)) : null,
                      trailing: c.connectedDevice == device ? Icon(Icons.check_circle_rounded, color: accent, size: 20) : null,
                      onTap: () {
                        c.connectTo(device);
                        final player = ctx.read<PlayerProvider>();
                        if (player.currentSong != null) {
                          Future.delayed(const Duration(milliseconds: 500), () {
                            if (player.isPlaying) {
                              player.playPause(); // Mettre en pause en local
                            }
                            c.playSong(player.currentSong!);
                          });
                        }
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              );
            },
          ),
        ]),
      ),
    ).whenComplete(() => connect.stopDiscovery());
  }

  Future<void> _startRadio(BuildContext ctx, PlayerProvider player, dynamic song) async {
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
      content: Text('Génération de la radio…'),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating));
    final tracks = await SwingApiService().getRadio(song.hash);
    if (tracks.isEmpty) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('Pas assez de titres pour la radio'),
        behavior: SnackBarBehavior.floating));
      return;
    }
    // Jouer le premier titre avec toute la radio comme queue
    if (ctx.mounted) player.playSong(tracks.first, queue: tracks, index: 0);
  }

  void _showMoreSheet(BuildContext ctx, PlayerProvider player, song, Color accent) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF282828),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.radio_rounded, color: Colors.white70),
            title: const Text('Lancer la radio',
                style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(ctx); _startRadio(ctx, player, song); }),
          Consumer<DownloadsProvider>(
            builder: (ctx, dl, _) {
              final isDownloaded = dl.isDownloaded(song.hash);
              if (isDownloaded) {
                return ListTile(
                  leading: const Icon(Icons.download_done_rounded, color: Colors.green),
                  title: const Text('Supprimer le téléchargement',
                      style: TextStyle(color: Colors.redAccent)),
                  onTap: () { Navigator.pop(ctx); dl.deleteSong(song.hash, song.filepath); }
                );
              } else {
                return ListTile(
                  leading: const Icon(Icons.download_rounded, color: Colors.white70),
                  title: const Text('Télécharger',
                      style: TextStyle(color: Colors.white)),
                  onTap: () { Navigator.pop(ctx); dl.downloadSong(song, ctx); }
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.queue_music_rounded, color: Colors.white70),
            title: const Text('Ajouter à la file',
                style: TextStyle(color: Colors.white)),
            onTap: () { player.addNextInQueue(song); Navigator.pop(ctx); }),
          ListTile(
            leading: Icon(
              player.isFavourite(song.hash)
                  ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: player.isFavourite(song.hash) ? accent : Colors.white70),
            title: Text(
              player.isFavourite(song.hash)
                  ? 'Retirer des favoris' : 'Ajouter aux favoris',
              style: const TextStyle(color: Colors.white)),
            onTap: () { player.toggleFavourite(song.hash); Navigator.pop(ctx); }),
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded,
                color: Colors.white70),
            title: const Text('Ajouter à une playlist',
              style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(ctx);
              _showAddToPlaylist(ctx, song);
            }),
          ListTile(
            leading: Icon(Icons.bedtime_rounded,
              color: player.hasSleepTimer ? Colors.blueAccent : Colors.white70),
            title: Text(
              player.hasSleepTimer
                ? 'Timer sommeil : ${_fmtRemaining(player.sleepRemaining)}'
                : 'Timer de sommeil',
              style: TextStyle(
                color: player.hasSleepTimer ? Colors.blueAccent : Colors.white)),
            onTap: () {
              Navigator.pop(ctx);
              _showSleepTimer(ctx, player);
            }),
          ListTile(
            leading: const Icon(Icons.album_rounded, color: Colors.white70),
            title: const Text("Aller à l'album",
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(ctx); // fermer le sheet
              // Fermer le player et naviguer vers l'album
              final album = Album(
                hash: song.albumHash,
                title: song.album,
                artist: song.artist,
                artistHash: song.artistHash,
                image: song.image ?? '',
              );
              Navigator.of(ctx).push(MaterialPageRoute(
                builder: (_) => AlbumScreen(album: album)));
            }),
          ListTile(
            leading: const Icon(Icons.person_rounded, color: Colors.white70),
            title: const Text("Aller à l'artiste",
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(ctx);
              final artist = Artist(
                hash: song.artistHash,
                name: song.artist,
                image: '${song.artistHash}.webp',
              );
              Navigator.of(ctx).push(MaterialPageRoute(
                builder: (_) => ArtistScreen(artist: artist)));
            }),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        const SizedBox(height: 8),

        // Artwork avec halo + swipe up → paroles
        Expanded(flex: 5, child: GestureDetector(
          onVerticalDragEnd: (d) {
            if (d.primaryVelocity != null && d.primaryVelocity! < -300) {
              onLyricsTap();
            }
          },
          child: Center(child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(
                color: accent.withOpacity(0.4), blurRadius: 50,
                offset: const Offset(0, 16), spreadRadius: 4)],
            ),
            child: AspectRatio(aspectRatio: 1, child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ArtworkWidget(
                key: ValueKey(song.hash),
                hash: song.image ?? song.hash,
                size: double.infinity,
                borderRadius: BorderRadius.circular(8)),
            )),
          )),
        )),
        const SizedBox(height: 6),

        // Hint "Voir les paroles" — visible seulement si paroles disponibles
        if (player.hasLyrics)
          GestureDetector(
            onTap: onLyricsTap,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.lyrics_rounded, size: 14, color: accent.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text('Voir les paroles', style: TextStyle(
                  color: accent.withOpacity(0.7), fontSize: 12)),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_up_rounded, size: 14,
                  color: accent.withOpacity(0.7)),
            ]),
          )
        else
          const SizedBox(height: 2),
        const SizedBox(height: 14),

        // Titre + like
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(song.title, style: const TextStyle(
                color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.bold, letterSpacing: -0.3),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
              // Badge lossless
              if (song.isLossless) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: accent.withOpacity(0.8), width: 1),
                    borderRadius: BorderRadius.circular(4)),
                  child: Text(song.audioFormat,
                    style: TextStyle(
                      color: accent, fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
                ),
              ],
            ]),
            const SizedBox(height: 4),
            Text(song.artist, style: TextStyle(
              color: Colors.white.withOpacity(0.7), fontSize: 15),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => player.toggleFavourite(song.hash),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                player.isFavourite(song.hash)
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                key: ValueKey(player.isFavourite(song.hash)),
                color: player.isFavourite(song.hash) ? accent : Colors.white70,
                size: 28,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 20),

        // Progress bar dynamique — autonome avec son propre Selector
        _ProgressBar(accent: accent),
        const SizedBox(height: 4),
        // Labels position/durée — Selector isolé
        Consumer2<PlayerProvider, ConnectControllerProvider>(
          builder: (_, p, c, __) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(c.isConnected ? c.position : p.position),
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
              Text(_fmt(c.isConnected ? c.duration : p.duration),
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Contrôles
        Consumer2<PlayerProvider, ConnectControllerProvider>(
          builder: (_, p, c, __) {
            final isPlaying = c.isConnected ? c.isPlaying : p.isPlaying;
            final isLoading = c.isConnected ? false : p.isLoading;
            final shuffle = p.shuffle;
            final repeatMode = p.repeatMode;
            return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center, children: [
              GestureDetector(
                onTap: p.toggleShuffle,
                child: Stack(alignment: Alignment.bottomCenter, children: [
                  Icon(Icons.shuffle_rounded, size: 26,
                    color: shuffle ? accent : Colors.white.withOpacity(0.6)),
                  if (shuffle) Positioned(bottom: -4,
                    child: Container(width: 4, height: 4,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle))),
                ]),
              ),
              GestureDetector(
                onTap: () { if (c.isConnected) { c.previous(); } else { p.previous(); } },
                child: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 46)),
              GestureDetector(
                onTap: () { if (c.isConnected) { c.playPause(); } else { p.playPause(); } },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 68, height: 68,
                  decoration: BoxDecoration(
                    color: accent, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: accent.withOpacity(0.5), blurRadius: 22, spreadRadius: 2)]),
                  child: Center(child: isLoading
                      ? const SizedBox(width: 26, height: 26,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white, size: 42)),
                ),
              ),
              GestureDetector(
                onTap: () { if (c.isConnected) { c.next(); } else { p.next(); } },
                child: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 46)),
              GestureDetector(
                onTap: p.toggleRepeat,
                child: Stack(alignment: Alignment.bottomCenter, children: [
                  Icon(
                    repeatMode == RepeatMode.one
                        ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                    size: 26,
                    color: repeatMode != RepeatMode.off
                        ? accent : Colors.white.withOpacity(0.6)),
                  if (repeatMode != RepeatMode.off) Positioned(bottom: -4,
                    child: Container(width: 4, height: 4,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle))),
                ]),
              ),
            ]);
          },
        ),
        const SizedBox(height: 20),

        // ── Slider volume ─────────────────────────────────────────
        Row(children: [
          Icon(
            player.volume == 0
                ? Icons.volume_off_rounded
                : player.volume < 0.5
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded,
            size: 18, color: Colors.white38),
          Expanded(child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: accent,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: accent.withOpacity(0.2)),
            child: Slider(
              value: player.volume,
              onChanged: (v) => player.setVolume(v)),
          )),
          Icon(Icons.volume_up_rounded, size: 18, color: Colors.white38),
        ]),
        const SizedBox(height: 6),

        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Consumer<ConnectControllerProvider>(
            builder: (_, c, __) => GestureDetector(
              onTap: () => _showDevicesSheet(ctx, accent),
              child: Icon(c.isConnected ? Icons.cast_connected_rounded : Icons.devices_rounded, size: 20,
                  color: c.isConnected ? accent : Colors.white.withOpacity(0.6))),
          ),
          Row(children: [
            GestureDetector(
              onTap: () => _showShareSheet(ctx, song, accent),
              child: Icon(Icons.share_rounded, size: 20,
                  color: Colors.white.withOpacity(0.6))),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: () => _showMoreSheet(ctx, player, song, accent),
              child: Icon(Icons.more_horiz_rounded, size: 24,
                  color: Colors.white.withOpacity(0.6))),
          ]),
        ]),
        const SizedBox(height: 12),
      ]),
    );
  }
}

// ── Progress bar — autonome avec Selector sur position+duration uniquement ──────
// Ne se rebuilde que toutes les 500ms (throttle du provider) sans dépendre
// du Consumer parent.

