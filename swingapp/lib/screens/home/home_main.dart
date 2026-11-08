part of '../home_tab.dart';

class HomeTab extends StatefulWidget {
  HomeTab({super.key});
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
  int? _avatarUserId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    ServerStatus.instance.addListener(_onServerStatusChanged);
    _load();
    _loadProfile();
  }

  @override
  void dispose() {
    ServerStatus.instance.removeListener(_onServerStatusChanged);
    super.dispose();
  }

  /// Réagit aux changements d'état réseau détectés par les pings et les
  /// requêtes API : bascule immédiate vers l'accueil hors ligne (ou retour).
  void _onServerStatusChanged() {
    if (!mounted) return;
    final offline = ServerStatus.instance.isOffline;
    if (offline == _offline) return;
    if (offline) {
      setState(() {
        _offline = true;
        _loading = false;
      });
    } else {
      _load();
    }
  }

  Future<void> _loadProfile() async {
    final api  = SwingApiService();
    // Cache d'abord (instantané hors ligne), puis rafraîchissement réseau.
    final cached = await api.getCachedProfile();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _username = cached['username'] as String?;
        _avatarUserId = cached['id'] as int?;
      });
    }
    final prof = await api.getMyProfile();
    if (prof.isNotEmpty && mounted) {
      setState(() {
        _username = prof['username'] as String?;
        _avatarUserId = prof['id'] as int?;
      });
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (mounted) setState(() => _loading = true);
    final api = SwingApiService();

    // Serveur injoignable : inutile d'attendre les timeouts (10 s) de chaque
    // section, on affiche directement l'accueil hors ligne.
    if (!await ServerStatus.instance.check()) {
      if (mounted) {
        setState(() {
          _loading = false;
          _offline = true;
        });
      }
      return;
    }
    if (mounted) setState(() => _offline = false);

    try {
      // 1. Charger les albums
      try {
        _albums = await api.getAlbums(limit: 20, forceRefresh: refresh);
      } catch (e) {
        debugPrint('Home _load albums error: $e');
      }

      // 2. Charger les top titres ou les chansons
      try {
        final topTracksData = await api.getTopTracks(limit: 30, forceRefresh: refresh);
        final rawItems = topTracksData['items'];
        if (rawItems is List) {
          _songs = rawItems
              .whereType<Map<String, dynamic>>()
              .map((x) => Song.fromJson(x))
              .toList();
        } else {
          _songs = [];
        }
        if (_songs.isEmpty) {
          _songs = await api.getSongs(limit: 30);
        }
      } catch (e) {
        try {
          _songs = await api.getSongs(limit: 30);
        } catch (_) {}
      }

      // 3. Charger les artistes
      try {
        final topArtistsData = await api.getTopArtists(limit: 15, forceRefresh: refresh);
        final rawItems = topArtistsData['items'];
        if (rawItems is List) {
          _artists = rawItems
              .whereType<Map<String, dynamic>>()
              .map((x) => Artist.fromJson(x))
              .toList();
        } else {
          _artists = [];
        }
        if (_artists.isEmpty) {
          _artists = await api.getArtists(limit: 15, forceRefresh: refresh);
        }
      } catch (e) {
        try {
          _artists = await api.getArtists(limit: 15, forceRefresh: refresh);
        } catch (_) {}
      }
    } catch (_) {}

    // Le serveur répond : on n'est jamais en mode « hors ligne », même si la
    // bibliothèque est vide.
    _offline = false;
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
      onRefresh: () => _load(refresh: true),
      child: CustomScrollView(slivers: [

        // ── App Bar ───────────────────────────────────────────────
        SliverAppBar(
          floating: true,
          snap: true,
          backgroundColor: Sp.bg,
          expandedHeight: 0,
          title: Row(children: [
            Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_greeting(),
                style: TextStyle(
                  fontSize: 13, color: Sp.white70,
                  fontWeight: FontWeight.w400)),
              SizedBox(height: 1),
              if (_username != null)
                Text(_username!,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold,
                    color: Sp.white)),
            ])),
          ]),
          actions: [
            if (_offline) ...[
              const Center(
                child: OfflinePill(
                  label: 'Lecteur Local',
                  icon: Icons.offline_pin_rounded,
                ),
              ),
              const SizedBox(width: 8),
            ],
            _AvatarButton(
              userId: _avatarUserId ?? 0,
              username: _username ?? '',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => SettingsScreen())),
            ),
            SizedBox(width: 12),
          ],
        ),

        if (_loading)
          SliverFillRemaining(child: Center(
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
              if (recent.isEmpty) return SliverToBoxAdapter(child: SizedBox.shrink());
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
                      padding: EdgeInsets.symmetric(horizontal: 16),
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
                padding: EdgeInsets.symmetric(horizontal: 16),
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
                padding: EdgeInsets.symmetric(horizontal: 16),
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
                      style: TextStyle(
                        color: Sp.white70, fontSize: 13)),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded,
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
              padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: GestureDetector(
                onTap: () => _showAllSongs(context),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border.all(color: Sp.white12),
                    borderRadius: BorderRadius.circular(14)),
                  child: Center(child: Text('Voir tous les titres',
                    style: TextStyle(color: Sp.white70,
                        fontSize: 14, fontWeight: FontWeight.w500)))),
              ),
            )),
          ],

          SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ]),
    );
  }

  void _showAllSongs(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _AllSongsScreen(songs: _songs)));
  }

  Widget _buildOfflineView(BuildContext context) =>
      _OfflineHomeView(onRefresh: () => _load(refresh: true));
}

// ── Avatar button ──────────────────────────────────────────────────────────────

