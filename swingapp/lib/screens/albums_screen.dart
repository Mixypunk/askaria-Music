import 'package:flutter/material.dart';
import '../main.dart';
import 'package:provider/provider.dart';
import '../models/album.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../providers/player_provider.dart';
import '../widgets/song_tile.dart';

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});
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
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Sp.bg,
          title: GText('Albums', s: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const GIcon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    GestureDetector(onTap: _load, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(gradient: kGrad, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Réessayer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )),
                  ]),
                ))
              : _albums.isEmpty
                  ? const Center(child: Text('Aucun album', style: TextStyle(color: Sp.white70)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
  const _AlbumCard({required this.album});

  @override
  Widget build(BuildContext context) {
    final api = SwingApiService();
    final thumb = '${api.baseUrl}/img/thumbnail/${album.image}';
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
              headers: api.authHeaders,
              errorBuilder: (_, __, ___) => Container(
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: const Icon(Icons.album, size: 48),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
        Text(album.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
      ]),
    );
  }
}

class AlbumDetailScreen extends StatefulWidget {
  final Album album;
  const AlbumDetailScreen({super.key, required this.album});
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
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final api = SwingApiService();
    final artwork = '${api.baseUrl}/img/thumbnail/${widget.album.image}';
    return Scaffold(
      appBar: AppBar(title: Text(widget.album.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          artwork, width: 100, height: 100, fit: BoxFit.cover,
                          headers: api.authHeaders,
                          errorBuilder: (_, __, ___) => Container(
                            width: 100, height: 100,
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            child: const Icon(Icons.album, size: 48),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.album.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(widget.album.artist, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
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
