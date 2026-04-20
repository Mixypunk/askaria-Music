import 'package:flutter/material.dart';
import '../main.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../providers/player_provider.dart';
import '../widgets/song_tile.dart';
import '../widgets/artwork_widget.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});
  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  List<Playlist> _playlists = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _playlists = await SwingApiService().getPlaylists();
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
          title: GText('Playlists', s: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ),
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
              : _playlists.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.queue_music_rounded, size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: 16),
                      const Text('Aucune playlist', style: TextStyle(color: Sp.white70)),
                      const SizedBox(height: 8),
                      Text('Crée des playlists dans Askaria',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _playlists.length,
                        itemBuilder: (ctx, i) {
                          final p = _playlists[i];
                          return ListTile(
                            leading: Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: p.imageHash != null && p.imageHash!.isNotEmpty
                                  ? ArtworkWidget(hash: p.imageHash!, size: 48,
                                      borderRadius: BorderRadius.circular(6))
                                  : const Icon(Icons.queue_music_rounded),
                            ),
                            title: Text(p.name),
                            subtitle: Text('${p.trackCount} titres'),
                            onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => PlaylistDetailScreen(playlist: p),
                            )),
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
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _tracks = await SwingApiService().getPlaylistTracks(widget.playlist.id);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.name),
        actions: [
          if (_tracks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.play_circle_rounded),
              onPressed: () => context.read<PlayerProvider>().playSong(
                _tracks.first, queue: _tracks, index: 0,
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _tracks.isEmpty
                  ? const Center(child: Text('Playlist vide'))
                  : ReorderableListView.builder(
                      itemCount: _tracks.length,
                      onReorder: (oldIndex, newIndex) async {
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }
                        if (oldIndex == newIndex) return;

                        setState(() {
                          final song = _tracks.removeAt(oldIndex);
                          _tracks.insert(newIndex, song);
                        });
                        
                        final success = await SwingApiService().reorderPlaylist(
                          widget.playlist.id, oldIndex, newIndex,
                        );
                        if (!success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Erreur lors de la modification de l\'ordre')),
                          );
                          _load(); // recharge en cas d'erreur
                        }
                      },
                      proxyDecorator: (c, _, __) => Material(color: Colors.transparent, child: c),
                      itemBuilder: (ctx, i) {
                        final song = _tracks[i];
                        return SongTile(
                          key: ValueKey('${song.hash}_${i}'),
                          song: song,
                          onTap: () => context.read<PlayerProvider>().playSong(
                            song, queue: _tracks, index: i,
                          ),
                          onRemove: () async {
                            setState(() {
                              _tracks.removeAt(i);
                            });
                            final success = await SwingApiService().removeTrackFromPlaylist(
                              widget.playlist.id, song.hash, i,
                            );
                            if (!success && mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(
                                 const SnackBar(content: Text('Erreur lors de la suppression')),
                               );
                               _load(); // recharge en cas d'erreur
                            }
                          },
                        );
                      },
                    ),
    );
  }
}


class _PlaylistArtwork extends StatelessWidget {
  final String playlistId;
  final double size;
  const _PlaylistArtwork({required this.playlistId, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final api = SwingApiService();
    final url = '${api.baseUrl}/img/playlist/$playlistId.webp';
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url,
        width: size, height: size, fit: BoxFit.cover,
        headers: api.authHeaders,
        errorBuilder: (_, __, ___) => Container(
          width: size, height: size,
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: const Icon(Icons.queue_music_rounded),
        ),
      ),
    );
  }
}
