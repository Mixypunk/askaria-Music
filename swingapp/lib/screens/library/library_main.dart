part of '../library_tab.dart';

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});
  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabCtrl;

  List<Playlist> _playlists = [];
  List<Album>    _albums    = [];
  List<Artist>   _artists   = [];

  bool _loading = true;
  String? _error;
  String _sort = 'recent';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    // Guard : ignore les frames d'animation intermédiaires,
    // setState uniquement quand l'onglet est vraiment arrivé.
    _tabCtrl.addListener(_onTabChanged);
    _load();
  }

  void _onTabChanged() {
    // indexIsChanging == true pendant l'animation → on skip
    if (_tabCtrl.indexIsChanging) return;
    if (mounted) setState(() {});
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _createPlaylist() async {
    final nameCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Sp.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Nouvelle playlist',
          style: TextStyle(color: Colors.white, fontSize: 18,
              fontWeight: FontWeight.bold)),
        content: Container(
          decoration: BoxDecoration(
            color: Sp.surface,
            borderRadius: BorderRadius.circular(12)),
          child: TextField(
            controller: nameCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Nom de la playlist',
              hintStyle: TextStyle(color: Colors.white38),
              prefixIcon: Icon(Icons.queue_music_rounded,
                  color: Colors.white38, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14)),
          )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler',
              style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: Text('Créer',
              style: TextStyle(color: Sp.g2,
                  fontWeight: FontWeight.bold))),
        ],
      ));
    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;
    final pl = await SwingApiService().createPlaylist(nameCtrl.text.trim());
    if (pl != null && mounted) {
      context.read<PlayerProvider>().invalidatePlaylistsCache();
      setState(() => _playlists.insert(0, pl));
      final result = await Navigator.push(context,
        MaterialPageRoute(builder: (_) => PlaylistScreen(playlist: pl)));
      if (result == 'deleted') {
        setState(() => _playlists.removeWhere((p) => p.id == pl.id));
      }
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        SwingApiService().getPlaylists(),
        SwingApiService().getAlbums(limit: 200),
        SwingApiService().getArtists(limit: 200),
      ]);
      _playlists = results[0] as List<Playlist>;
      _albums    = results[1] as List<Album>;
      _artists   = results[2] as List<Artist>;
      _applySorting();
    } catch (e) {
      await _loadOfflineLibrary();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadOfflineLibrary() async {
    try {
      final dlProvider = context.read<DownloadsProvider>();
      _playlists = dlProvider.downloadedPlaylists;
      final songs = dlProvider.downloadedSongs;

      final albumMap = <String, List<Song>>{};
      for (final s in songs) {
        albumMap.putIfAbsent(s.album, () => []).add(s);
      }
      _albums = albumMap.entries.map((e) {
        final albumTracks = e.value;
        final firstTrack = albumTracks.first;
        return Album(
          hash: firstTrack.albumHash.isNotEmpty ? firstTrack.albumHash : e.key,
          title: e.key, artist: firstTrack.artist,
          artistHash: firstTrack.artistHash,
          trackCount: albumTracks.length, image: firstTrack.image ?? '',
        );
      }).toList();

      final artistMap = <String, List<Song>>{};
      for (final s in songs) {
        artistMap.putIfAbsent(s.artist, () => []).add(s);
      }
      _artists = artistMap.entries.map((e) {
        final artistTracks = e.value;
        final firstTrack = artistTracks.first;
        final uniqueAlbums = artistTracks.map((s) => s.album).toSet();
        return Artist(
          hash: firstTrack.artistHash.isNotEmpty ? firstTrack.artistHash : e.key,
          name: e.key, trackCount: artistTracks.length,
          albumCount: uniqueAlbums.length, image: firstTrack.image ?? '',
        );
      }).toList();

      _applySorting();
    } catch (e) { LoggerService.warning('Silent error caught in library_main.dart', e); }
  }

  void _applySorting() {
    if (_sort == 'alpha') {
      _playlists.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _albums.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      _artists.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Sp.bg,
      floatingActionButton: _tabCtrl.index == 0
          ? Container(
              decoration: BoxDecoration(
                gradient: kGrad,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                  color: Sp.g2.withOpacity(0.4),
                  blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _createPlaylist,
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Icon(Icons.add_rounded,
                        color: Colors.white, size: 26)),
                ),
              ),
            )
          : null,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            floating: true,
            backgroundColor: Sp.bg,
            surfaceTintColor: Colors.transparent,
            titleSpacing: 16,
            title: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: const BoxDecoration(gradient: kGrad, shape: BoxShape.circle),
                child: const Icon(Icons.person_rounded, size: 18, color: Colors.white)),
              const SizedBox(width: 10),
              const Text('Ma bibliothèque',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                    color: Colors.white)),
            ]),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort_rounded, color: Colors.white),
                color: Sp.card,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 12,
                onSelected: (v) => setState(() { _sort = v; _applySorting(); }),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'recent', child: Row(children: [
                    Icon(Icons.access_time_rounded,
                      color: _sort == 'recent' ? Sp.g2 : Colors.white70, size: 18),
                    const SizedBox(width: 10),
                    Text('Récents', style: TextStyle(
                      color: _sort == 'recent' ? Sp.g2 : Colors.white))])),
                  PopupMenuItem(value: 'alpha', child: Row(children: [
                    Icon(Icons.sort_by_alpha_rounded,
                      color: _sort == 'alpha' ? Sp.g2 : Colors.white70, size: 18),
                    const SizedBox(width: 10),
                    Text('A → Z', style: TextStyle(
                      color: _sort == 'alpha' ? Sp.g2 : Colors.white))])),
                ],
              ),
              const SizedBox(width: 4),
            ],
            bottom: _PillTabBar(controller: _tabCtrl, tabs: [
              _TabLabel('Playlists',
                  _playlists.isNotEmpty ? _playlists.length : null),
              _TabLabel('Albums', _albums.isNotEmpty ? _albums.length : null),
              _TabLabel('Artistes', _artists.isNotEmpty ? _artists.length : null),
              const _TabLabel('Favoris', null),
            ]),
          ),
        ],
        body: _loading
            ? const Center(child: CircularProgressIndicator(
                color: Sp.g2, strokeWidth: 2))
            : _error != null
                ? _ErrorView(error: _error!, onRetry: _load)
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _PlaylistsList(playlists: _playlists,
                          onDeleted: (id) => setState(
                              () => _playlists.removeWhere((p) => p.id == id))),
                      _AlbumsList(albums: _albums),
                      _ArtistsList(artists: _artists),
                      const _FavouritesList(),
                    ],
                  ),
      ),
    );
  }
}

// ── Tab bar style pill ─────────────────────────────────────────────────────────
class _TabLabel extends StatelessWidget {
  final String text;
  final int? count;
  const _TabLabel(this.text, this.count);
  @override
  Widget build(BuildContext context) => Tab(
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(text),
      if (count != null) ...[
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$count',
            style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ),
      ],
    ]),
  );
}

class _PillTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController controller;
  final List<Widget> tabs;
  const _PillTabBar({required this.controller, required this.tabs});

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelColor: Colors.white,
      unselectedLabelColor: Sp.white40,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 13),
      indicator: BoxDecoration(
        gradient: kGrad,
        borderRadius: BorderRadius.circular(20),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      dividerColor: Colors.transparent,
      tabs: tabs,
    );
  }
}

// ── Playlists ──────────────────────────────────────────────────────────────────

