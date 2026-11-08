part of '../home_tab.dart';

/// Accueil affiché quand le serveur est injoignable : il ne présente que ce
/// qui est réellement disponible en local (titres + playlists téléchargés),
/// avec reprise d'écoute et accès direct à la gestion du hors-ligne.
class _OfflineHomeView extends StatelessWidget {
  final VoidCallback onRefresh;
  const _OfflineHomeView({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadsProvider>(
      builder: (ctx, dl, _) {
        if (!dl.isReady) {
          return SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: Sp.g2, strokeWidth: 2),
            ),
          );
        }

        final songs = List<Song>.of(dl.downloadedSongs)
          ..sort((a, b) =>
              a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        final playlists = List<Playlist>.of(dl.downloadedPlaylists)
          ..sort((a, b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        if (songs.isEmpty && playlists.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: OfflineEmptyState(
              title: 'Serveur inaccessible',
              message:
                  'Aucune musique n\'est encore téléchargée.\n'
                  'Connectez-vous au réseau pour préparer votre écoute hors ligne.',
              actions: [
                OfflineGradientButton(
                  label: 'Réessayer',
                  icon: Icons.refresh_rounded,
                  onTap: onRefresh,
                ),
              ],
            ),
          );
        }

        final history = ctx.read<PlayerProvider>().history;
        final offlineHashes = dl.downloadedHashes;
        final recent = history
            .where((s) => offlineHashes.contains(s.hash))
            .take(8)
            .toList();

        return SliverList(
          delegate: SliverChildListDelegate([
            _OfflineHeaderCard(
              songs: songs,
              playlists: playlists,
              totalBytes: dl.offlineBytes,
              onRefresh: onRefresh,
              onOpenDownloads: () => Navigator.push(
                ctx,
                MaterialPageRoute(builder: (_) => DownloadsScreen()),
              ),
            ),

            // ── Reprise d'écoute ──────────────────────────────────────
            if (recent.isNotEmpty) ...[
              _SectionHeader(
                title: 'Continuer l\'écoute',
                icon: Icons.history_rounded,
              ),
              SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: recent.length,
                  itemBuilder: (c, i) => _RecentTile(
                    song: recent[i],
                    allSongs: recent,
                    idx: i,
                    cacheOnly: true,
                  ),
                ),
              ),
            ],

            // ── Playlists ─────────────────────────────────────────────
            if (playlists.isNotEmpty) ...[
              _SectionHeader(
                title: 'Playlists hors connexion',
                icon: Icons.queue_music_rounded,
                trailing: Text(
                  '${playlists.length}',
                  style: TextStyle(color: Sp.white40, fontSize: 13),
                ),
              ),
              SizedBox(
                height: 196,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: playlists.length,
                  separatorBuilder: (_, __) => SizedBox(width: 12),
                  itemBuilder: (c, i) {
                    final pl = playlists[i];
                    return OfflinePlaylistCard(
                      playlist: pl,
                      width: 132,
                      onTap: () => Navigator.push(
                        c,
                        MaterialPageRoute(
                          builder: (_) =>
                              PlaylistDetailScreen(playlist: pl, readOnly: true),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // ── Titres ────────────────────────────────────────────────
            if (songs.isNotEmpty) ...[
              _SectionHeader(
                title: 'Titres téléchargés',
                icon: Icons.download_done_rounded,
                trailing: GestureDetector(
                  onTap: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(builder: (_) => DownloadsScreen()),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      'Gérer',
                      style: TextStyle(color: Sp.white70, fontSize: 13),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Sp.white40,
                      size: 18,
                    ),
                  ]),
                ),
              ),
              ...songs.take(8).toList().asMap().entries.map(
                    (e) => _OfflineSongRow(
                      song: e.value,
                      all: songs,
                      index: e.key,
                    ),
                  ),
              if (songs.length > 8)
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(builder: (_) => DownloadsScreen()),
                    ),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(color: Sp.white12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          'Voir les ${songs.length} titres',
                          style: TextStyle(
                            color: Sp.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],

            SizedBox(height: 120),
          ]),
        );
      },
    );
  }
}

// ── En-tête « mode hors connexion » ──────────────────────────────────────────
class _OfflineHeaderCard extends StatelessWidget {
  final List<Song> songs;
  final List<Playlist> playlists;
  final int totalBytes;
  final VoidCallback onRefresh;
  final VoidCallback onOpenDownloads;

  const _OfflineHeaderCard({
    required this.songs,
    required this.playlists,
    required this.totalBytes,
    required this.onRefresh,
    required this.onOpenDownloads,
  });

  @override
  Widget build(BuildContext context) {
    void playAll({bool shuffle = false}) {
      if (songs.isEmpty) return;
      final queue = List<Song>.of(songs);
      if (shuffle) queue.shuffle();
      context.read<PlayerProvider>().playSong(queue.first, queue: queue);
    }

    return Container(
      margin: EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Sp.g1.withValues(alpha: 0.18),
            Sp.g2.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(color: Sp.g2.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const OfflinePill(),
            const Spacer(),
            GestureDetector(
              onTap: onRefresh,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Sp.glass,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.refresh_rounded, size: 17, color: Sp.white70),
              ),
            ),
          ]),
          SizedBox(height: 14),
          Text(
            'Votre musique, sans réseau',
            style: TextStyle(
              color: Sp.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Lecture depuis vos téléchargements',
            style: TextStyle(color: Sp.white70, fontSize: 12),
          ),
          SizedBox(height: 16),
          Row(children: [
            OfflineStat(
              icon: Icons.music_note_rounded,
              value: '${songs.length}',
              label: songs.length > 1 ? 'titres' : 'titre',
            ),
            OfflineStat(
              icon: Icons.queue_music_rounded,
              value: '${playlists.length}',
              label: playlists.length > 1 ? 'playlists' : 'playlist',
            ),
            OfflineStat(
              icon: Icons.sd_storage_rounded,
              value: formatOfflineSize(totalBytes),
              label: 'utilisés',
            ),
          ]),
          SizedBox(height: 16),
          Row(children: [
            if (songs.isNotEmpty) ...[
              OfflineGradientButton(
                label: 'Tout lire',
                icon: Icons.play_arrow_rounded,
                onTap: () => playAll(),
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: () => playAll(shuffle: true),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Sp.glass,
                    shape: BoxShape.circle,
                    border: Border.all(color: Sp.white12),
                  ),
                  child: Icon(
                    Icons.shuffle_rounded,
                    size: 17,
                    color: Sp.white70,
                  ),
                ),
              ),
              SizedBox(width: 8),
            ],
            OfflineOutlineButton(
              label: 'Gérer',
              icon: Icons.tune_rounded,
              onTap: onOpenDownloads,
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Ligne de titre (écoute + état courant) ───────────────────────────────────
class _OfflineSongRow extends StatelessWidget {
  final Song song;
  final List<Song> all;
  final int index;
  const _OfflineSongRow({
    required this.song,
    required this.all,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = context.select<PlayerProvider, bool>(
      (p) => p.currentSong?.hash == song.hash,
    );
    final playing = context.select<PlayerProvider, bool>((p) => p.isPlaying);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 7),
      child: OfflineSongTile(
        song: song,
        isCurrent: isCurrent,
        playing: playing,
        onTap: () => context.read<PlayerProvider>().playSong(
              song,
              queue: all,
              index: index,
            ),
      ),
    );
  }
}
