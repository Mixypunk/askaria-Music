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
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await Future.wait([
        SwingApiService().getPlaylists(),
        SwingApiService().getAlbums(limit: 200),
        SwingApiService().getArtists(limit: 200),
      ]);
      _playlists = r[0] as List<Playlist>;
      _albums    = r[1] as List<Album>;
      _artists   = r[2] as List<Artist>;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: [
      // ── AppBar Spotify style ────────────────────────────────────
      SliverAppBar(
        floating: true,
        backgroundColor: Sp.bg,
        elevation: 0,
        titleSpacing: 16,
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(gradient: kGrad, shape: BoxShape.circle),
            child: const Icon(Icons.person_rounded, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Text('Votre bibliothèque',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: () {}),
        ],
      ),

      // ── Filter chips ────────────────────────────────────────────
      SliverToBoxAdapter(child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Row(children: [
          if (_filter != _Filter.all) ...[
            _Chip('Tout', () => setState(() => _filter = _Filter.all),
                isClose: true, active: false),
            const SizedBox(width: 8),
          ],
          _Chip('Playlists', () => setState(() =>
              _filter = _filter == _Filter.playlists ? _Filter.all : _Filter.playlists),
              active: _filter == _Filter.playlists),
          const SizedBox(width: 8),
          _Chip('Albums', () => setState(() =>
              _filter = _filter == _Filter.albums ? _Filter.all : _Filter.albums),
              active: _filter == _Filter.albums),
          const SizedBox(width: 8),
          _Chip('Artistes', () => setState(() =>
              _filter = _filter == _Filter.artists ? _Filter.all : _Filter.artists),
              active: _filter == _Filter.artists),
        ]),
      )),

      if (_loading)
        const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
      else if (_error != null)
        SliverFillRemaining(child: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton(onPressed: _load,
                child: const Text('Réessayer', style: TextStyle(color: Sp.g2))),
          ])))
      else
        SliverList(delegate: SliverChildListDelegate([
          ..._buildItems(),
          const SizedBox(height: 20),
        ])),
    ]);
  }

  List<Widget> _buildItems() {
    final items = <Widget>[];

    if (_filter == _Filter.all || _filter == _Filter.playlists) {
      for (final p in _playlists) {
        items.add(_PlaylistTile(playlist: p));
      }
    }
    if (_filter == _Filter.all || _filter == _Filter.albums) {
      for (final a in _albums) {
        items.add(_AlbumTile(album: a));
      }
    }
    if (_filter == _Filter.all || _filter == _Filter.artists) {
      for (final a in _artists) {
        items.add(_ArtistTile(artist: a));
      }
    }
    return items;
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool isClose;
  const _Chip(this.label, this.onTap, {this.active = false, this.isClose = false});

  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        gradient: active ? kGrad : null,
        color: active ? null : const Color(0xFF2A2A2A),
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

// ── Playlist tile (avec 4 images Spotify style) ────────────────────────────────
class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  const _PlaylistTile({required this.playlist});

  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: _playlistArt(api),
      title: Text(playlist.name,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('Playlist · ${playlist.trackCount} titres',
        style: const TextStyle(color: Colors.white54, fontSize: 13)),
      trailing: const Icon(Icons.more_vert, color: Colors.white38, size: 20),
      onTap: () => _play(ctx),
    );
  }

  Widget _playlistArt(SwingApiService api) {
    final imgUrl = '${api.baseUrl}/img/playlist/${playlist.id}.webp';
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(imgUrl, width: 56, height: 56, fit: BoxFit.cover,
        headers: api.authHeaders,
        errorBuilder: (_, __, ___) => Container(
          width: 56, height: 56, color: const Color(0xFF282828),
          child: const Icon(Icons.queue_music_rounded, color: Colors.white38, size: 28))),
    );
  }

  void _play(BuildContext ctx) async {
    final tracks = await SwingApiService().getPlaylistTracks(playlist.id);
    if (ctx.mounted && tracks.isNotEmpty)
      ctx.read<PlayerProvider>().playSong(tracks.first, queue: tracks, index: 0);
  }
}

class _AlbumTile extends StatelessWidget {
  final Album album;
  const _AlbumTile({required this.album});
  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();
    final url = '${api.baseUrl}/img/thumbnail/${album.image}';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: ClipRRect(borderRadius: BorderRadius.circular(4),
        child: Image.network(url, width: 56, height: 56, fit: BoxFit.cover,
          headers: api.authHeaders,
          errorBuilder: (_, __, ___) => Container(width: 56, height: 56,
            color: const Color(0xFF282828),
            child: const Icon(Icons.album, color: Colors.white38, size: 28)))),
      title: Text(album.title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('Album · ${album.artist}',
        style: const TextStyle(color: Colors.white54, fontSize: 13),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.more_vert, color: Colors.white38, size: 20),
      onTap: () async {
        final tracks = await SwingApiService().getAlbumTracks(album.hash);
        if (ctx.mounted && tracks.isNotEmpty)
          ctx.read<PlayerProvider>().playSong(tracks.first, queue: tracks, index: 0);
      },
    );
  }
}

class _ArtistTile extends StatelessWidget {
  final Artist artist;
  const _ArtistTile({required this.artist});
  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();
    final url = '${api.baseUrl}/img/artist/small/${artist.image}';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: ClipOval(child: Image.network(url, width: 56, height: 56, fit: BoxFit.cover,
        headers: api.authHeaders,
        errorBuilder: (_, __, ___) => Container(width: 56, height: 56,
          color: const Color(0xFF282828),
          child: const Icon(Icons.person, color: Colors.white38, size: 28)))),
      title: Text(artist.name,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: const Text('Artiste', style: TextStyle(color: Colors.white54, fontSize: 13)),
      trailing: const Icon(Icons.more_vert, color: Colors.white38, size: 20),
      onTap: () async {
        final tracks = await SwingApiService().getArtistTracks(artist.hash);
        if (ctx.mounted && tracks.isNotEmpty)
          ctx.read<PlayerProvider>().playSong(tracks.first, queue: tracks, index: 0);
      },
    );
  }
}
