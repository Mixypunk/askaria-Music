import 'package:flutter/material.dart';
import '../main.dart';
import 'package:provider/provider.dart';
import '../models/album.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../providers/player_provider.dart';
import '../providers/downloads_provider.dart';
import '../widgets/song_tile.dart';

class AlbumsScreen extends StatefulWidget {
  AlbumsScreen({super.key});
  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  List<Album> _albums = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _albums = await SwingApiService().getAlbums(limit: 200);
    } catch (e) {
      if (mounted) {
        final dlSongs = context.read<DownloadsProvider>().downloadedSongs;
        if (dlSongs.isNotEmpty) {
          final Map<String, List<Song>> albumsMap = {};
          for (final song in dlSongs) {
            final albumTitle = song.album.isNotEmpty ? song.album : 'Unknown Album';
            albumsMap.putIfAbsent(albumTitle, () => []).add(song);
          }
          _albums = albumsMap.entries.map((entry) {
            final albumTitle = entry.key;
            final songs = entry.value;
            final firstSong = songs.first;
            return Album(
              hash: firstSong.albumHash.isNotEmpty ? firstSong.albumHash : albumTitle,
              title: albumTitle,
              artist: firstSong.artist,
              artistHash: firstSong.artistHash,
              trackCount: songs.length,
              image: firstSong.image ?? '',
            );
          }).toList();
        } else {
          _error = e.toString();
        }
      } else {
        _error = e.toString();
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Sp.bg,
          title: GText('Albums', s: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    GIcon(Icons.error_outline, size: 48),
                    SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red)),
                    SizedBox(height: 16),
                    GestureDetector(onTap: _load, child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(gradient: kGrad, borderRadius: BorderRadius.circular(20)),
                    child: Text('Réessayer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )),
                  ]),
                ))
              : _albums.isEmpty
                  ? Center(child: Text('Aucun album', style: TextStyle(color: Sp.white70)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: GridView.builder(
                        padding: EdgeInsets.all(12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, childAspectRatio: 0.75,
                          crossAxisSpacing: 12, mainAxisSpacing: 12,
                        ),
                        itemCount: _albums.length,
                        itemBuilder: (ctx, i) => _AlbumCard(album: _albums[i]),
                      ),
                    ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final Album album;
  _AlbumCard({required this.album});

  @override
  Widget build(BuildContext context) {
    final api = SwingApiService();
    final thumb = api.getThumbnailUrl(album.image);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => AlbumDetailScreen(album: album),
      )),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              thumb,
              fit: BoxFit.cover,
              headers: thumb.startsWith(api.baseUrl) ? api.authHeaders : {},
              errorBuilder: (_, __, ___) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(Icons.album, size: 48),
              ),
            ),
          ),
        ),
        SizedBox(height: 6),
        Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
        Text(album.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
      ]),
    );
  }
}

class AlbumDetailScreen extends StatefulWidget {
  final Album album;
  AlbumDetailScreen({super.key, required this.album});
  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  List<Song> _tracks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _tracks = await SwingApiService().getAlbumTracks(widget.album.hash);
    } catch (e) {
      if (mounted) {
        final dlSongs = context.read<DownloadsProvider>().downloadedSongs;
        _tracks = dlSongs.where((s) => s.album == widget.album.title || (s.albumHash.isNotEmpty && s.albumHash == widget.album.hash)).toList();
        if (_tracks.isEmpty) {
          _error = e.toString();
        }
      } else {
        _error = e.toString();
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final api = SwingApiService();
    final artwork = api.getThumbnailUrl(widget.album.image);
    return Scaffold(
      appBar: AppBar(title: Text(widget.album.title)),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: Colors.red)))
              : ListView(children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          artwork, width: 100, height: 100, fit: BoxFit.cover,
                          headers: artwork.startsWith(api.baseUrl) ? api.authHeaders : {},
                          errorBuilder: (_, __, ___) => Container(
                            width: 100, height: 100,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Icon(Icons.album, size: 48),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.album.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(widget.album.artist, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                        if (widget.album.year != null) Text('${widget.album.year}'),
                      ])),
                    ]),
                  ),
                  ..._tracks.asMap().entries.map((e) => SongTile(
                    song: e.value,
                    onTap: () => context.read<PlayerProvider>().playSong(
                      e.value, queue: _tracks, index: e.key,
                    ),
                  )),
                ]),
    );
  }
}

