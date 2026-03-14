import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/artist.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../providers/player_provider.dart';
import '../widgets/song_tile.dart';

class ArtistsScreen extends StatefulWidget {
  const ArtistsScreen({super.key});
  @override
  State<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends State<ArtistsScreen> {
  List<Artist> _artists = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _artists = await SwingApiService().getArtists(limit: 500);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Artistes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 12)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                  ]),
                ))
              : _artists.isEmpty
                  ? const Center(child: Text('Aucun artiste'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _artists.length,
                        itemBuilder: (ctx, i) {
                          final a = _artists[i];
                          final api = SwingApiService();
                          // Artist image: /img/artist/small/{artisthash}.webp
                          final imgUrl = '${api.baseUrl}/img/artist/small/${a.image}';
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                              child: ClipOval(child: Image.network(
                                imgUrl,
                                width: 48, height: 48, fit: BoxFit.cover,
                                headers: api.authHeaders,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.person_rounded,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              )),
                            ),
                            title: Text(a.name,
                                style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text(
                              a.helpText.isNotEmpty ? a.helpText : 'Artiste',
                            ),
                            onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => ArtistDetailScreen(artist: a),
                            )),
                          );
                        },
                      ),
                    ),
    );
  }
}

class ArtistDetailScreen extends StatefulWidget {
  final Artist artist;
  const ArtistDetailScreen({super.key, required this.artist});
  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  List<Song> _tracks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _tracks = await SwingApiService().getArtistTracks(widget.artist.hash);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final api = SwingApiService();
    final imgUrl = '${api.baseUrl}/img/artist/${widget.artist.image}';
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(widget.artist.name),
            background: Image.network(
              imgUrl,
              fit: BoxFit.cover,
              headers: api.authHeaders,
              errorBuilder: (_, __, ___) => Container(
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: const Icon(Icons.person_rounded, size: 80),
              ),
            ),
          ),
        ),
        if (_loading)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          SliverFillRemaining(child: Center(child: Text(_error!,
              style: const TextStyle(color: Colors.red))))
        else if (_tracks.isEmpty)
          const SliverFillRemaining(child: Center(child: Text('Aucun titre')))
        else
          SliverList(delegate: SliverChildBuilderDelegate(
            (ctx, i) => SongTile(
              song: _tracks[i],
              onTap: () => context.read<PlayerProvider>().playSong(
                _tracks[i], queue: _tracks, index: i,
              ),
            ),
            childCount: _tracks.length,
          )),
      ]),
    );
  }
}
