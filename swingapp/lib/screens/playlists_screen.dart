import 'package:flutter/material.dart';
import '../main.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../providers/player_provider.dart';
import '../providers/downloads_provider.dart';
import '../widgets/song_tile.dart';
import '../widgets/artwork_widget.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});
  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Playlist> _mine = [];
  List<Playlist> _public = [];
  bool _loadingMine = true;
  bool _loadingPublic = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (_tab.index == 1 && _public.isEmpty && !_loadingPublic) {
        _loadPublic();
      }
    });
    _loadMine();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadMine() async {
    setState(() { _loadingMine = true; _error = null; });
    try {
      _mine = await SwingApiService().getPlaylists();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loadingMine = false);
  }

  Future<void> _loadPublic() async {
    setState(() => _loadingPublic = true);
    try {
      final pls = await SwingApiService().getPublicPlaylists();
      if (mounted) setState(() { _public = pls; _loadingPublic = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingPublic = false);
    }
  }

  Future<void> _createPlaylist() async {
    final nameCtrl = TextEditingController();
    bool isPublic = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: Sp.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Nouvelle playlist',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Nom de la playlist',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true, fillColor: Colors.white10,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Checkbox(
                value: isPublic,
                activeColor: Sp.g1,
                onChanged: (v) => setSt(() => isPublic = v ?? false),
              ),
              const Text('Rendre publique', style: TextStyle(color: Colors.white70)),
            ]),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Sp.g1),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      await SwingApiService().createPlaylist(
        nameCtrl.text.trim(),
        isPublic: isPublic,
      );
      await _loadMine();
    }
    nameCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Sp.bg,
      appBar: AppBar(
        backgroundColor: Sp.bg,
        title: GText('Playlists', s: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Nouvelle playlist',
            onPressed: _createPlaylist,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Sp.g1,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'Mes playlists'),
            Tab(text: 'Partagées'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ── Mes playlists ────────────────────────────────────────
          _loadingMine
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
                        ElevatedButton(onPressed: _loadMine, child: const Text('Réessayer')),
                      ]),
                    ))
                  : _mine.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.queue_music_rounded, size: 64, color: Colors.white24),
                          const SizedBox(height: 16),
                          const Text('Aucune playlist', style: TextStyle(color: Sp.white70)),
                          const SizedBox(height: 8),
                          const Text('Appuie sur + pour en créer une',
                              style: TextStyle(color: Colors.white38, fontSize: 13)),
                        ]))
                      : RefreshIndicator(
                          onRefresh: _loadMine,
                          child: ListView.builder(
                            itemCount: _mine.length,
                            itemBuilder: (ctx, i) => _PlaylistTile(
                              playlist: _mine[i],
                              showPublicBadge: true,
                              onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => PlaylistDetailScreen(playlist: _mine[i]),
                              )).then((_) => _loadMine()),
                            ),
                          ),
                        ),

          // ── Playlists partagées ──────────────────────────────────
          _loadingPublic
              ? const Center(child: CircularProgressIndicator())
              : _public.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.public_off_rounded, size: 64, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text('Aucune playlist partagée', style: TextStyle(color: Sp.white70)),
                      const SizedBox(height: 8),
                      const Text('Les playlists publiques des autres utilisateurs\napparaîtront ici',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38, fontSize: 13)),
                      const SizedBox(height: 20),
                      TextButton.icon(
                        onPressed: _loadPublic,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualiser'),
                        style: TextButton.styleFrom(foregroundColor: Sp.g2),
                      ),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _loadPublic,
                      child: ListView.builder(
                        itemCount: _public.length,
                        itemBuilder: (ctx, i) => _PlaylistTile(
                          playlist: _public[i],
                          showPublicBadge: false,
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => PlaylistDetailScreen(
                              playlist: _public[i],
                              readOnly: true,
                            ),
                          )),
                        ),
                      ),
                    ),
        ],
      ),
    );
  }
}

// ── Tuile playlist ──────────────────────────────────────────────────────────
class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  final bool showPublicBadge;
  const _PlaylistTile({required this.playlist, required this.onTap, this.showPublicBadge = false});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(6),
        ),
        child: playlist.imageHash != null && playlist.imageHash!.isNotEmpty
            ? ArtworkWidget(hash: playlist.imageHash!, size: 48,
                borderRadius: BorderRadius.circular(6))
            : const Icon(Icons.queue_music_rounded, color: Colors.white38),
      ),
      title: Text(playlist.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
      subtitle: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('${playlist.trackCount} titre${playlist.trackCount != 1 ? 's' : ''}',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        if (showPublicBadge && playlist.isPublic) ...[ 
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
            ),
            child: const Text('Public',
                style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ],
      ]),
      onTap: onTap,
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
    );
  }
}

// ── Écran détail playlist ────────────────────────────────────────────────────
class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;
  final bool readOnly;
  const PlaylistDetailScreen({super.key, required this.playlist, this.readOnly = false});
  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  List<Song> _tracks = [];
  bool _loading = true;
  String? _error;
  late Playlist _playlist;

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _tracks = await SwingApiService().getPlaylistTracks(_playlist.id);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) {
      setState(() => _loading = false);
      if (_tracks.isNotEmpty) {
        context.read<DownloadsProvider>().autoSyncPlaylist(_playlist.id, _tracks);
      }
    }
  }

  Future<void> _togglePublic() async {
    final newVal = !_playlist.isPublic;
    final ok = await SwingApiService().updatePlaylist(
      _playlist.id,
      isPublic: newVal,
    );
    if (ok && mounted) {
      setState(() {
        _playlist = Playlist(
          id: _playlist.id,
          name: _playlist.name,
          description: _playlist.description,
          trackCount: _playlist.trackCount,
          imageHash: _playlist.imageHash,
          isPublic: newVal,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(newVal ? 'Playlist rendue publique' : 'Playlist rendue privée'),
        backgroundColor: Sp.card,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Sp.bg,
      appBar: AppBar(
        backgroundColor: Sp.bg,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_playlist.name),
            if (_playlist.isPublic)
              const Text('Publique', style: TextStyle(fontSize: 11, color: Colors.blueAccent)),
          ],
        ),
        actions: [
          if (_tracks.isNotEmpty) ...[
            Consumer<DownloadsProvider>(
              builder: (ctx, dl, _) {
                if (!SwingApiService().canDownload) return const SizedBox.shrink();

                final isOffline = dl.isPlaylistOffline(_playlist.id);
                
                if (dl.isDownloadingPlaylist) {
                  return const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Center(child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
                    )),
                  );
                }

                return IconButton(
                  icon: Icon(
                    isOffline ? Icons.download_done_rounded : Icons.download_rounded,
                    color: isOffline ? Colors.green : Colors.white70,
                  ),
                  tooltip: isOffline ? 'Désactiver la synchro' : 'Activer la synchro hors-ligne',
                  onPressed: () {
                    if (isOffline) {
                      dl.unsyncPlaylist(_playlist.id);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Synchronisation hors-ligne désactivée'),
                        behavior: SnackBarBehavior.floating,
                      ));
                    } else {
                      dl.syncPlaylist(_playlist.id, _tracks, context: context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Synchronisation hors-ligne activée'),
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.play_circle_rounded),
              onPressed: () => context.read<PlayerProvider>().playSong(
                _tracks.first, queue: _tracks, index: 0,
              ),
            ),
          ],
          if (!widget.readOnly)
            IconButton(
              icon: Icon(
                _playlist.isPublic ? Icons.public_rounded : Icons.public_off_rounded,
                color: _playlist.isPublic ? Colors.blueAccent : Colors.white38,
              ),
              tooltip: _playlist.isPublic ? 'Rendre privée' : 'Rendre publique',
              onPressed: _togglePublic,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _tracks.isEmpty
                  ? const Center(child: Text('Playlist vide', style: TextStyle(color: Colors.white54)))
                  : widget.readOnly
                      // Lecture seule → liste simple (playlist d'un autre user)
                      ? ListView.builder(
                          itemCount: _tracks.length,
                          itemBuilder: (ctx, i) => SongTile(
                            song: _tracks[i],
                            onTap: () => context.read<PlayerProvider>().playSong(
                              _tracks[i], queue: _tracks, index: i,
                            ),
                          ),
                        )
                      // Éditable → drag & drop + suppression
                      : ReorderableListView.builder(
                          itemCount: _tracks.length,
                          onReorder: (oldIndex, newIndex) async {
                            if (oldIndex < newIndex) newIndex -= 1;
                            if (oldIndex == newIndex) return;
                            setState(() {
                              final song = _tracks.removeAt(oldIndex);
                              _tracks.insert(newIndex, song);
                            });
                            final ok = await SwingApiService().reorderPlaylist(
                              _playlist.id, oldIndex, newIndex,
                            );
                            if (!ok && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Erreur lors du réordonnancement')),
                              );
                              _load();
                            }
                          },
                          proxyDecorator: (c, _, __) => Material(color: Colors.transparent, child: c),
                          itemBuilder: (ctx, i) {
                            final song = _tracks[i];
                            return SongTile(
                              key: ValueKey('${song.hash}_$i'),
                              song: song,
                              onTap: () => context.read<PlayerProvider>().playSong(
                                song, queue: _tracks, index: i,
                              ),
                              onRemove: () async {
                                setState(() => _tracks.removeAt(i));
                                final ok = await SwingApiService().removeTrackFromPlaylist(
                                  _playlist.id, song.hash, i,
                                );
                                if (!ok && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Erreur lors de la suppression')),
                                  );
                                  _load();
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
          color: Colors.white10,
          child: const Icon(Icons.queue_music_rounded, color: Colors.white24),
        ),
      ),
    );
  }
}
