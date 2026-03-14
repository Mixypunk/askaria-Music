import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../providers/player_provider.dart';
import '../widgets/artwork_widget.dart';
import 'player_screen.dart';

enum _Filter { all, playlists, albums, artists }

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});
  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  _Filter _filter = _Filter.all;
  List<Playlist> _playlists = [];
  List<Album> _albums = [];
  List<Artist> _artists = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Future.wait([
        SwingApiService().getPlaylists(),
        SwingApiService().getAlbums(limit: 200),
        SwingApiService().getArtists(limit: 200),
      ]);
      _playlists = r[0] as List<Playlist>;
      _albums    = r[1] as List<Album>;
      _artists   = r[2] as List<Artist>;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: [
      // ── Header Spotify ──────────────────────────────────────────────
      SliverAppBar(
        floating: true,
        backgroundColor: Sp.bg,
        title: Row(children: [
          const GIcon(Icons.library_music_rounded, size: 28),
          const SizedBox(width: 10),
          const Text('Bibliothèque',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Sp.white)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Sp.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Sp.white),
            onPressed: () {},
          ),
        ],
      ),

      // ── Filter chips (Playlists / Albums / Artistes) ─────────────
      SliverToBoxAdapter(child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Row(children: [
          if (_filter != _Filter.all) ...[
            _chip('Tout', _Filter.all, isClose: true),
            const SizedBox(width: 8),
          ],
          _chip('Playlists', _Filter.playlists),
          const SizedBox(width: 8),
          _chip('Albums', _Filter.albums),
          const SizedBox(width: 8),
          _chip('Artistes', _Filter.artists),
        ]),
      )),

      if (_loading)
        const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator(color: Sp.g2, strokeWidth: 2)))
      else
        SliverList(delegate: SliverChildListDelegate(_buildItems())),

      const SliverToBoxAdapter(child: SizedBox(height: 20)),
    ]);
  }

  List<Widget> _buildItems() {
    final items = <Widget>[];
    if (_filter == _Filter.all || _filter == _Filter.playlists) {
      for (final p in _playlists) items.add(_PlaylistRow(playlist: p));
    }
    if (_filter == _Filter.all || _filter == _Filter.albums) {
      for (final a in _albums) items.add(_AlbumRow(album: a));
    }
    if (_filter == _Filter.all || _filter == _Filter.artists) {
      for (final a in _artists) items.add(_ArtistRow(artist: a));
    }
    return items;
  }

  Widget _chip(String label, _Filter f, {bool isClose = false}) {
    final active = _filter == f && !isClose;
    return GestureDetector(
      onTap: () => setState(() => _filter = isClose ? _Filter.all : f),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: active ? kGrad : null,
          color: active ? null : Sp.card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (isClose) ...[
            const Icon(Icons.close, size: 14, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(label, style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ── Rows ─────────────────────────────────────────────────────────────────────
class _PlaylistRow extends StatelessWidget {
  final Playlist playlist;
  const _PlaylistRow({required this.playlist});
  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();
    final imgUrl = '${api.baseUrl}/img/playlist/${playlist.id}.webp';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(imgUrl, width: 52, height: 52, fit: BoxFit.cover,
          headers: api.authHeaders,
          errorBuilder: (_, __, ___) => Container(
            width: 52, height: 52, color: Sp.card,
            child: const Icon(Icons.queue_music_rounded, color: Sp.white40))),
      ),
      title: Text(playlist.name,
        style: const TextStyle(color: Sp.white, fontWeight: FontWeight.w500, fontSize: 15),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('Playlist · ${playlist.trackCount} titres',
        style: const TextStyle(color: Sp.white70, fontSize: 13)),
      onTap: () => _open(ctx, playlist),
    );
  }
  void _open(BuildContext ctx, Playlist p) async {
    final tracks = await SwingApiService().getPlaylistTracks(p.id);
    if (ctx.mounted && tracks.isNotEmpty)
      ctx.read<PlayerProvider>().playSong(tracks.first, queue: tracks, index: 0);
  }
}

class _AlbumRow extends StatelessWidget {
  final Album album;
  const _AlbumRow({required this.album});
  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();
    final url = '${api.baseUrl}/img/thumbnail/${album.image}';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(url, width: 52, height: 52, fit: BoxFit.cover,
          headers: api.authHeaders,
          errorBuilder: (_, __, ___) => Container(
            width: 52, height: 52, color: Sp.card,
            child: const Icon(Icons.album, color: Sp.white40))),
      ),
      title: Text(album.title,
        style: const TextStyle(color: Sp.white, fontWeight: FontWeight.w500, fontSize: 15),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('Album · ${album.artist}',
        style: const TextStyle(color: Sp.white70, fontSize: 13),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => _open(ctx, album),
    );
  }
  void _open(BuildContext ctx, Album a) async {
    final tracks = await SwingApiService().getAlbumTracks(a.hash);
    if (ctx.mounted && tracks.isNotEmpty)
      ctx.read<PlayerProvider>().playSong(tracks.first, queue: tracks, index: 0);
  }
}

class _ArtistRow extends StatelessWidget {
  final Artist artist;
  const _ArtistRow({required this.artist});
  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();
    final url = '${api.baseUrl}/img/artist/small/${artist.image}';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipOval(child: Image.network(url, width: 52, height: 52, fit: BoxFit.cover,
        headers: api.authHeaders,
        errorBuilder: (_, __, ___) => Container(
          width: 52, height: 52, color: Sp.card,
          child: const Icon(Icons.person, color: Sp.white40)))),
      title: Text(artist.name,
        style: const TextStyle(color: Sp.white, fontWeight: FontWeight.w500, fontSize: 15),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: const Text('Artiste', style: TextStyle(color: Sp.white70, fontSize: 13)),
      onTap: () => _open(ctx, artist),
    );
  }
  void _open(BuildContext ctx, Artist a) async {
    final tracks = await SwingApiService().getArtistTracks(a.hash);
    if (ctx.mounted && tracks.isNotEmpty)
      ctx.read<PlayerProvider>().playSong(tracks.first, queue: tracks, index: 0);
  }
}
