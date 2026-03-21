import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/playlist.dart';
import '../models/album.dart';
import '../models/song.dart';
import '../widgets/artwork_widget.dart';
import '../services/api_service.dart';
import '../providers/player_provider.dart';
import 'artist_screen.dart';

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});
  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
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
        title: const Text('Nouvelle playlist',
          style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Container(
          decoration: BoxDecoration(color: Sp.bg,
              borderRadius: BorderRadius.circular(8)),
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
              style: TextStyle(color: Sp.g2, fontWeight: FontWeight.bold))),
        ],
      ));
    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;
    final pl = await SwingApiService()
        .createPlaylist(nameCtrl.text.trim());
    if (pl != null && mounted) {
      context.read<PlayerProvider>().invalidatePlaylistsCache();
      setState(() => _playlists.insert(0, pl));
      // Ouvrir directement la playlist créée
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
    } catch (e) { _error = e.toString(); }
    if (mounted) setState(() => _loading = false);
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
          ? FloatingActionButton(
              onPressed: _createPlaylist,
              backgroundColor: Sp.g2,
              child: const Icon(Icons.add_rounded, color: Colors.white))
          : null,
      body: NestedScrollView(
      headerSliverBuilder: (_, __) => [
        SliverAppBar(
          floating: true,
          backgroundColor: Sp.bg,
          titleSpacing: 16,
          title: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(gradient: kGrad, shape: BoxShape.circle),
              child: const Icon(Icons.person_rounded, size: 18, color: Colors.white)),
            const SizedBox(width: 10),
            const Text('Bibliothèque',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                  color: Colors.white)),
          ]),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort_rounded, color: Colors.white),
              color: const Color(0xFF282828),
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
              ]),
            const SizedBox(width: 4),
          ],
          bottom: TabBar(
            controller: _tabCtrl,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            indicatorColor: Sp.g2,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 2,
            tabs: [
              Tab(text: 'Playlists ${_playlists.isNotEmpty ? "(${_playlists.length})" : ""}'),
              Tab(text: 'Albums ${_albums.isNotEmpty ? "(${_albums.length})" : ""}'),
              Tab(text: 'Artistes ${_artists.isNotEmpty ? "(${_artists.length})" : ""}'),
              Tab(text: 'Favoris'),   // ← cette ligne manque
            ],
          ),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _PlaylistsList(
                      playlists: _playlists,
                      onDeleted: (id) => setState(
                          () => _playlists.removeWhere((p) => p.id == id))),
                    _AlbumsList(albums: _albums),
                    _ArtistsList(artists: _artists),
                    const _FavouritesList(),
                  ],
                ),         // TabBarView
      ),           // body: NestedScrollView
    );             // Scaffold
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
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: playlists.length,
      itemBuilder: (ctx, i) => _PlaylistTile(
        playlist: playlists[i],
        onDeleted: onDeleted),
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: NetImage(url: '${api.baseUrl}/img/playlist/${playlist.id}.webp', width: 56, height: 56,
              headers: api.authHeaders,
              borderRadius: BorderRadius.circular(4),
              placeholder: Container(width: 56, height: 56, color: Sp.card,
                child: const Icon(Icons.queue_music_rounded, color: Colors.white38, size: 28)))),
      title: Text(playlist.name, style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        'Playlist · ${playlist.trackCount} titre${playlist.trackCount != 1 ? "s" : ""}',
        style: const TextStyle(color: Colors.white54, fontSize: 13)),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: Colors.white38, size: 20),
      onTap: () async {
        final result = await Navigator.push(ctx, MaterialPageRoute(
          builder: (_) => PlaylistScreen(playlist: playlist)));
        if (result == 'deleted' && ctx.mounted) {
          // Remonter l'info au parent (_PlaylistsList → _LibraryTabState)
          // via le callback onDeleted
          onDeleted?.call(playlist.id);
        }
      },
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
      padding: const EdgeInsets.only(bottom: 100),
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: NetImage(url: '${api.baseUrl}/img/thumbnail/${album.image}', width: 56, height: 56,
              headers: api.authHeaders,
              borderRadius: BorderRadius.circular(4),
              placeholder: Container(width: 56, height: 56, color: Sp.card,
                child: const Icon(Icons.album, color: Colors.white38, size: 28)))),
      title: Text(album.title, style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${album.artist}${album.year != null ? " · ${album.year}" : ""}',
        style: const TextStyle(color: Colors.white54, fontSize: 13),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: Colors.white38, size: 20),
      onTap: () => Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => AlbumScreen(album: album))),
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
      padding: const EdgeInsets.only(bottom: 100),
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: ClipOval(child: NetImage(url: '${api.baseUrl}/img/artist/small/${artist.image}', width: 56, height: 56,
              headers: api.authHeaders,
              borderRadius: BorderRadius.circular(4),
              placeholder: Container(width: 56, height: 56, color: Sp.card,
                child: const Icon(Icons.person, color: Colors.white38, size: 28)))),
      title: Text(artist.name, style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${artist.trackCount} titre${artist.trackCount != 1 ? "s" : ""}'
        '${artist.albumCount > 0 ? " · ${artist.albumCount} album${artist.albumCount != 1 ? "s" : ""}" : ""}',
        style: const TextStyle(color: Colors.white54, fontSize: 13)),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: Colors.white38, size: 20),
      onTap: () => Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => ArtistScreen(artist: artist))),
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
      Icon(icon, color: Colors.white24, size: 64),
      const SizedBox(height: 16),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 16)),
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
      const Icon(Icons.error_outline, color: Colors.white38, size: 48),
      const SizedBox(height: 12),
      Text(error, style: const TextStyle(color: Colors.white54, fontSize: 12),
          textAlign: TextAlign.center),
      const SizedBox(height: 16),
      TextButton(onPressed: onRetry,
        child: const Text('Réessayer', style: TextStyle(color: Sp.g2))),
    ],
  ));
}

// ── Favoris ────────────────────────────────────────────────────────────────────
class _FavouritesList extends StatelessWidget {
  const _FavouritesList();
  @override
  Widget build(BuildContext ctx) {
    return Consumer<PlayerProvider>(builder: (ctx, player, _) {
      // Charger les favoris depuis l'API à la demande
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
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext ctx) {
    if (_loading) return const Center(
      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
    if (_songs.isEmpty) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.favorite_border_rounded, color: Colors.white24, size: 64),
        SizedBox(height: 16),
        Text('Aucun favori', style: TextStyle(color: Colors.white54, fontSize: 16)),
        SizedBox(height: 8),
        Text('Likez des titres depuis le lecteur',
          style: TextStyle(color: Colors.white30, fontSize: 13)),
      ],
    ));
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: _songs.length,
      itemBuilder: (ctx, i) {
        final song = _songs[i];
        final isCurrent = ctx.watch<PlayerProvider>().currentSong?.hash == song.hash;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: ArtworkWidget(
              key: ValueKey(song.hash),
              hash: song.image ?? song.hash,
              size: 50, borderRadius: BorderRadius.circular(4))),
          title: Text(song.title, style: TextStyle(
            color: isCurrent ? Sp.g2 : Colors.white,
            fontWeight: FontWeight.w500, fontSize: 15),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(song.artist,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: GestureDetector(
            onTap: () {
              ctx.read<PlayerProvider>().toggleFavourite(song.hash);
              setState(() => _songs.removeAt(i));
            },
            child: const Icon(Icons.favorite_rounded,
                color: Colors.redAccent, size: 22)),
          onTap: () => ctx.read<PlayerProvider>()
              .playSong(song, queue: _songs, index: i),
        );
      },
    );
  }
}
