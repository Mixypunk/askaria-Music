import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/album.dart';
import '../models/song.dart';
import '../widgets/artwork_widget.dart';
import '../services/api_service.dart';
import '../providers/player_provider.dart';
import '../providers/downloads_provider.dart';
import 'artist_screen.dart';

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
    _tabCtrl.addListener(() => setState(() {}));
    _load();
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
    } catch (_) {}
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
class _PlaylistsList extends StatelessWidget {
  final List<Playlist> playlists;
  final void Function(String id)? onDeleted;
  const _PlaylistsList({required this.playlists, this.onDeleted});
  @override
  Widget build(BuildContext ctx) {
    if (playlists.isEmpty) return const _EmptyView(
      icon: Icons.queue_music_rounded, label: 'Aucune playlist');
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120, top: 8),
      itemCount: playlists.length,
      itemBuilder: (ctx, i) => _PlaylistTile(
        playlist: playlists[i], onDeleted: onDeleted),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final void Function(String id)? onDeleted;
  const _PlaylistTile({required this.playlist, this.onDeleted});
  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.push(ctx, MaterialPageRoute(
            builder: (_) => PlaylistScreen(playlist: playlist)));
          if (result == 'deleted' && ctx.mounted) {
            onDeleted?.call(playlist.id);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: kCardDecoration(radius: 14),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: NetImage(
                url: '${api.baseUrl}/img/playlist/${playlist.id}.webp',
                width: 56, height: 56,
                headers: api.authHeaders,
                borderRadius: BorderRadius.circular(10),
                placeholder: Container(width: 56, height: 56, color: Sp.cardHi,
                  child: const Icon(Icons.queue_music_rounded,
                      color: Colors.white38, size: 28)))),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(playlist.name, style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  'Playlist · ${playlist.trackCount} titre${playlist.trackCount != 1 ? "s" : ""}',
                  style: const TextStyle(color: Sp.white70, fontSize: 12)),
              ])),
            const Icon(Icons.chevron_right_rounded, color: Sp.white40, size: 20),
          ]),
        ),
      ),
    );
  }
}

// ── Albums ─────────────────────────────────────────────────────────────────────
class _AlbumsList extends StatelessWidget {
  final List<Album> albums;
  const _AlbumsList({required this.albums});
  @override
  Widget build(BuildContext ctx) {
    if (albums.isEmpty) return const _EmptyView(
      icon: Icons.album_rounded, label: 'Aucun album');
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120, top: 8),
      itemCount: albums.length,
      itemBuilder: (ctx, i) => _AlbumTile(album: albums[i]),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  final Album album;
  const _AlbumTile({required this.album});
  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();
    final url = api.getThumbnailUrl(album.image);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: GestureDetector(
        onTap: () => Navigator.push(ctx, MaterialPageRoute(
          builder: (_) => AlbumScreen(album: album))),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: kCardDecoration(radius: 14),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: NetImage(
                url: url,
                width: 56, height: 56,
                headers: url.startsWith(api.baseUrl) ? api.authHeaders : {},
                borderRadius: BorderRadius.circular(10),
                placeholder: Container(width: 56, height: 56, color: Sp.cardHi,
                  child: const Icon(Icons.album, color: Colors.white38, size: 28)))),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(album.title, style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  '${album.artist}${album.year != null ? " · ${album.year}" : ""}',
                  style: const TextStyle(color: Sp.white70, fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
            const Icon(Icons.chevron_right_rounded, color: Sp.white40, size: 20),
          ]),
        ),
      ),
    );
  }
}

// ── Artistes ───────────────────────────────────────────────────────────────────
class _ArtistsList extends StatelessWidget {
  final List<Artist> artists;
  const _ArtistsList({required this.artists});
  @override
  Widget build(BuildContext ctx) {
    if (artists.isEmpty) return const _EmptyView(
      icon: Icons.person_rounded, label: 'Aucun artiste');
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120, top: 8),
      itemCount: artists.length,
      itemBuilder: (ctx, i) => _ArtistTile(artist: artists[i]),
    );
  }
}

class _ArtistTile extends StatelessWidget {
  final Artist artist;
  const _ArtistTile({required this.artist});
  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: GestureDetector(
        onTap: () => Navigator.push(ctx, MaterialPageRoute(
          builder: (_) => ArtistScreen(artist: artist))),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: kCardDecoration(radius: 14),
          child: Row(children: [
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle, gradient: kGrad),
              padding: const EdgeInsets.all(2),
              child: ClipOval(child: NetImage(
                url: '${api.baseUrl}/img/artist/small/${artist.image}',
                width: 52, height: 52,
                headers: api.authHeaders,
                borderRadius: BorderRadius.circular(26),
                placeholder: Container(width: 52, height: 52, color: Sp.cardHi,
                  child: const Icon(Icons.person, color: Colors.white38, size: 28))))),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(artist.name, style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  '${artist.trackCount} titre${artist.trackCount != 1 ? "s" : ""}'
                  '${artist.albumCount > 0 ? " · ${artist.albumCount} album${artist.albumCount != 1 ? "s" : ""}" : ""}',
                  style: const TextStyle(color: Sp.white70, fontSize: 12)),
              ])),
            const Icon(Icons.chevron_right_rounded, color: Sp.white40, size: 20),
          ]),
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyView({required this.icon, required this.label});
  @override
  Widget build(BuildContext ctx) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: Sp.card, borderRadius: BorderRadius.circular(18)),
        child: Icon(icon, color: Sp.white40, size: 36),
      ),
      const SizedBox(height: 16),
      Text(label, style: const TextStyle(
          color: Sp.white70, fontSize: 16)),
    ],
  ));
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext ctx) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: Sp.card, borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.error_outline, color: Sp.white40, size: 36),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(error, style: const TextStyle(
            color: Sp.white70, fontSize: 12),
          textAlign: TextAlign.center)),
      const SizedBox(height: 16),
      TextButton(onPressed: onRetry,
        child: const Text('Réessayer',
            style: TextStyle(color: Sp.g2, fontWeight: FontWeight.w600))),
    ],
  ));
}

// ── Favoris ────────────────────────────────────────────────────────────────────
class _FavouritesList extends StatelessWidget {
  const _FavouritesList();
  @override
  Widget build(BuildContext ctx) {
    return Consumer<PlayerProvider>(builder: (ctx, player, _) {
      return _FavouritesContent(player: player);
    });
  }
}

class _FavouritesContent extends StatefulWidget {
  final PlayerProvider player;
  const _FavouritesContent({required this.player});
  @override
  State<_FavouritesContent> createState() => _FavouritesContentState();
}

class _FavouritesContentState extends State<_FavouritesContent> {
  List<Song> _songs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      _songs = await SwingApiService().getFavourites();
    } catch (_) {
      try {
        final dlSongs = context.read<DownloadsProvider>().downloadedSongs;
        final player = context.read<PlayerProvider>();
        _songs = dlSongs.where((s) => player.isFavourite(s.hash)).toList();
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext ctx) {
    if (_loading) return const Center(
      child: CircularProgressIndicator(color: Sp.g2, strokeWidth: 2));
    if (_songs.isEmpty) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: Sp.card, borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.favorite_border_rounded,
              color: Sp.white40, size: 36),
        ),
        const SizedBox(height: 16),
        const Text('Aucun favori',
            style: TextStyle(color: Sp.white70, fontSize: 16)),
        const SizedBox(height: 8),
        const Text('Likez des titres depuis le lecteur',
          style: TextStyle(color: Sp.white40, fontSize: 13)),
      ],
    ));
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120, top: 8),
      itemCount: _songs.length,
      itemBuilder: (ctx, i) {
        final song = _songs[i];
        final isCurrent = ctx.watch<PlayerProvider>().currentSong?.hash == song.hash;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: GestureDetector(
            onTap: () => ctx.read<PlayerProvider>()
                .playSong(song, queue: _songs, index: i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: kCardDecoration(radius: 14),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ArtworkWidget(
                    key: ValueKey(song.hash),
                    hash: song.image ?? song.hash,
                    size: 50, borderRadius: BorderRadius.circular(10))),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title, style: TextStyle(
                      color: isCurrent ? Sp.g2 : Colors.white,
                      fontWeight: FontWeight.w600, fontSize: 15),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(song.artist,
                      style: const TextStyle(
                          color: Sp.white70, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                GestureDetector(
                  onTap: () {
                    ctx.read<PlayerProvider>().toggleFavourite(song.hash);
                    setState(() => _songs.removeAt(i));
                  },
                  child: const Icon(Icons.favorite_rounded,
                      color: Colors.redAccent, size: 22)),
              ]),
            ),
          ),
        );
      },
    );
  }
}
