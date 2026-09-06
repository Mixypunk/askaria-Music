part of '../home_tab.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with AutomaticKeepAliveClientMixin {
  List<Song>   _songs   = [];
  List<Album>  _albums  = [];
  List<Artist> _artists = [];
  bool _loading = true;
  bool _offline = false;

  String? _username;
  String? _avatarUrl;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final api  = SwingApiService();
    final prof = await api.getMyProfile();
    final uid  = prof['id'] as int?;
    if (uid != null && mounted) {
      setState(() {
        _username  = prof['username'] as String?;
        _avatarUrl = api.getAvatarUrl(uid);
      });
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _offline = false; });
    try {
      final api = SwingApiService();
      final results = await Future.wait([
        api.getTopTracks(limit: 30),
        api.getAlbums(limit: 20),
        api.getTopArtists(limit: 15),
      ]).timeout(const Duration(seconds: 15));

      _albums = results[1] as List<Album>;

      final topTracksData = results[0] as Map<String, dynamic>;
      _songs = (topTracksData['items'] as List?)
          ?.map((x) => Song.fromJson(x as Map<String, dynamic>))
          .toList() ?? [];
      if (_songs.isEmpty) {
        _songs = await api.getSongs(limit: 30);
      }

      final topArtistsData = results[2] as Map<String, dynamic>;
      _artists = (topArtistsData['items'] as List?)
          ?.map((x) => Artist.fromJson(x as Map<String, dynamic>))
          .toList() ?? [];
      if (_artists.isEmpty) {
        _artists = await api.getArtists(limit: 15);
      }
    } catch (_) {
      _offline = _songs.isEmpty;
    }
    if (mounted) setState(() => _loading = false);
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      color: Sp.g2,
      backgroundColor: Sp.card,
      displacement: 80,
      onRefresh: _load,
      child: CustomScrollView(slivers: [

        // ── App Bar ───────────────────────────────────────────────
        SliverAppBar(
          floating: true,
          snap: true,
          backgroundColor: Sp.bg,
          expandedHeight: 0,
          title: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_greeting(),
                style: const TextStyle(
                  fontSize: 13, color: Sp.white70,
                  fontWeight: FontWeight.w400)),
              const SizedBox(height: 1),
              if (_username != null)
                Text(_username!,
                  style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold,
                    color: Sp.white)),
            ]),
          ]),
          actions: [
            _AvatarButton(
              avatarUrl: _avatarUrl,
              username: _username ?? '',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
            const SizedBox(width: 12),
          ],
        ),

        if (_loading)
          const SliverFillRemaining(child: Center(
            child: CircularProgressIndicator(color: Sp.g2, strokeWidth: 2)))

        else if (_offline)
          _buildOfflineView(context)

        else ...[ // ── Contenu principal ──────────────────────────

          // Récemment joués — Selector ciblé sur l'historique uniquement
          // (évite les rebuilds toutes les 500ms depuis positionStream)
          Selector<PlayerProvider, List<Song>>(
            selector: (_, p) => p.history,
            shouldRebuild: (prev, next) => prev.length != next.length,
            builder: (ctx, recent, _) {
              if (recent.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
              return SliverToBoxAdapter(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _SectionHeader(
                    title: 'Récemment joués',
                    icon: Icons.history_rounded,
                  ),
                  SizedBox(
                    height: 70,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: recent.length.clamp(0, 8),
                      itemBuilder: (ctx, i) => _RecentTile(
                        song: recent[i], allSongs: recent, idx: i),
                    ),
                  ),
                ]),
              );
            }),

          // Albums
          if (_albums.isNotEmpty) ...[ 
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Nouveaux albums',
                icon: Icons.album_rounded,
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(
              height: 210,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _albums.length,
                itemBuilder: (ctx, i) => _AlbumCard(album: _albums[i]),
              ),
            )),
          ],

          // Artistes
          if (_artists.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Artistes les plus écoutés',
                icon: Icons.people_rounded,
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(
              height: 148,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _artists.length,
                itemBuilder: (ctx, i) => _ArtistCard(artist: _artists[i]),
              ),
            )),
          ],

          // Tous les titres
          if (_songs.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Titres les plus populaires',
                icon: Icons.music_note_rounded,
                trailing: GestureDetector(
                  onTap: () => _showAllSongs(context),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Voir tout (${_songs.length})',
                      style: const TextStyle(
                        color: Sp.white70, fontSize: 13)),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded,
                      color: Sp.white40, size: 18),
                  ]),
                ),
              ),
            ),
            SliverList(delegate: SliverChildBuilderDelegate(
              (ctx, i) => _SongRow(song: _songs[i], all: _songs, idx: i, index: i),
              childCount: _songs.length.clamp(0, 10),
            )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: GestureDetector(
                onTap: () => _showAllSongs(context),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border.all(color: Sp.white12),
                    borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text('Voir tous les titres',
                    style: TextStyle(color: Sp.white70,
                        fontSize: 14, fontWeight: FontWeight.w500)))),
              ),
            )),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ]),
    );
  }

  void _showAllSongs(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _AllSongsScreen(songs: _songs)));
  }

  Widget _buildOfflineView(BuildContext context) {
    return Consumer<DownloadsProvider>(
      builder: (context, dlProvider, _) {
        final offlineSongs = dlProvider.downloadedSongs;
        final offlinePlaylists = dlProvider.downloadedPlaylists;

        if (offlineSongs.isEmpty && offlinePlaylists.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: Sp.card,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.wifi_off_rounded,
                        color: Sp.white40, size: 40),
                  ),
                  const SizedBox(height: 20),
                  const Text('Serveur inaccessible',
                    style: TextStyle(color: Sp.white, fontSize: 18,
                        fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 48),
                    child: Text('Aucune musique téléchargée pour le mode hors connexion.',
                      style: TextStyle(color: Sp.white70, fontSize: 14),
                      textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: _load,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: kGrad,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(
                          color: Sp.g2.withOpacity(0.3),
                          blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: const Text('Réessayer',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold)))),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildListDelegate([
            // Banner hors connexion
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Sp.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Sp.white12),
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Sp.g2.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cloud_off_rounded, color: Sp.g2, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mode hors connexion',
                      style: TextStyle(color: Sp.white, fontSize: 14,
                          fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('Titres et playlists disponibles hors ligne.',
                      style: TextStyle(color: Sp.white70, fontSize: 12)),
                  ],
                )),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Sp.white70, size: 20),
                  onPressed: _load,
                ),
              ]),
            ),

            if (offlinePlaylists.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(children: const [
                  Icon(Icons.queue_music_rounded, color: Sp.white70, size: 16),
                  SizedBox(width: 8),
                  Text('Playlists hors connexion',
                    style: TextStyle(color: Sp.white, fontSize: 18,
                        fontWeight: FontWeight.bold)),
                ]),
              ),
              SizedBox(
                height: 168,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: offlinePlaylists.length,
                  itemBuilder: (ctx, i) {
                    final pl = offlinePlaylists[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => PlaylistDetailScreen(playlist: pl, readOnly: true))),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: SizedBox(
                          width: 120,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 120, height: 120,
                                decoration: BoxDecoration(
                                  color: Sp.card,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.queue_music_rounded,
                                    color: Sp.white40, size: 48),
                              ),
                              const SizedBox(height: 8),
                              Text(pl.name,
                                style: const TextStyle(color: Sp.white,
                                    fontSize: 13, fontWeight: FontWeight.w500),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('${pl.trackCount} titres',
                                style: const TextStyle(color: Sp.white70, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            if (offlineSongs.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(children: const [
                  Icon(Icons.download_done_rounded, color: Sp.white70, size: 16),
                  SizedBox(width: 8),
                  Text('Titres téléchargés',
                    style: TextStyle(color: Sp.white, fontSize: 18,
                        fontWeight: FontWeight.bold)),
                ]),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: offlineSongs.length,
                itemBuilder: (ctx, i) =>
                    _SongRow(song: offlineSongs[i], all: offlineSongs, idx: i, index: i),
              ),
            ],

            const SizedBox(height: 100),
          ]),
        );
      },
    );
  }
}

// ── Avatar button ──────────────────────────────────────────────────────────────

