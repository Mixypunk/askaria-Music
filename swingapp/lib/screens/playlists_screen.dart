import 'package:flutter/material.dart';
import '../models/album.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../widgets/artwork_widget.dart';
import '../widgets/song_tile.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  List<Playlist> _playlists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _playlists = await SwingApiService().getPlaylists();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Playlists')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _playlists.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.queue_music_rounded, size: 64,
                              color: Theme.of(context).colorScheme.onSurfaceVariant),
                          const SizedBox(height: 16),
                          const Text('Aucune playlist trouvée'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _playlists.length,
                      itemBuilder: (ctx, i) {
                        final p = _playlists[i];
                        return ListTile(
                          leading: ArtworkWidget(
                            hash: p.imageHash,
                            size: 52,
                            type: 'track',
                          ),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text('${p.trackCount} titres'),
                          onTap: () => Navigator.push(
                            ctx,
                            MaterialPageRoute(
                              builder: (_) => PlaylistDetailScreen(playlist: p),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  List<Song> _tracks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    SwingApiService().getPlaylistTracks(widget.playlist.id).then((tracks) {
      if (mounted) setState(() { _tracks = tracks; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.playlist.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _tracks.length,
              itemBuilder: (ctx, i) => SongTile(
                song: _tracks[i],
                queue: _tracks,
                index: i,
              ),
            ),
    );
  }
}
