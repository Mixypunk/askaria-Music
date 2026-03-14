import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/playlist.dart';
import '../services/api_service.dart';
import '../providers/player_provider.dart';

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});
  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  List<Playlist> _playlists = [];
  bool _loading = true;
  String? _error;
  String _sort = 'recent'; // recent | alpha

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _playlists = await SwingApiService().getPlaylists();
      _applySorting();
    } catch (e) { _error = e.toString(); }
    if (mounted) setState(() => _loading = false);
  }

  void _applySorting() {
    if (_sort == 'alpha') {
      _playlists.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    // 'recent' = ordre API par défaut
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: [

      // ── AppBar ──────────────────────────────────────────────────
      SliverAppBar(
        floating: true,
        backgroundColor: Sp.bg,
        elevation: 0,
        titleSpacing: 16,
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(
              gradient: kGrad, shape: BoxShape.circle),
            child: const Icon(Icons.person_rounded, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Text('Votre bibliothèque',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                color: Colors.white)),
        ]),
        actions: [
          // Tri
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded, color: Colors.white),
            color: const Color(0xFF282828),
            onSelected: (v) {
              setState(() { _sort = v; _applySorting(); });
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'recent',
                child: Row(children: [
                  Icon(Icons.access_time_rounded,
                    color: _sort == 'recent' ? Sp.g2 : Colors.white70, size: 18),
                  const SizedBox(width: 10),
                  Text('Récents', style: TextStyle(
                    color: _sort == 'recent' ? Sp.g2 : Colors.white)),
                ])),
              PopupMenuItem(value: 'alpha',
                child: Row(children: [
                  Icon(Icons.sort_by_alpha_rounded,
                    color: _sort == 'alpha' ? Sp.g2 : Colors.white70, size: 18),
                  const SizedBox(width: 10),
                  Text('A → Z', style: TextStyle(
                    color: _sort == 'alpha' ? Sp.g2 : Colors.white)),
                ])),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),

      // ── Compteur ────────────────────────────────────────────────
      if (!_loading && _error == null)
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text('${_playlists.length} playlist${_playlists.length != 1 ? 's' : ''}',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
        )),

      // ── États ───────────────────────────────────────────────────
      if (_loading)
        const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2)))
      else if (_error != null)
        SliverFillRemaining(child: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton(onPressed: _load,
                child: const Text('Réessayer',
                    style: TextStyle(color: Sp.g2))),
          ])))
      else if (_playlists.isEmpty)
        SliverFillRemaining(child: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.queue_music_rounded,
                color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            const Text('Aucune playlist',
                style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Créez des playlists sur votre serveur Swing Music',
                style: TextStyle(color: Colors.white30, fontSize: 12),
                textAlign: TextAlign.center),
          ])))
      else
        SliverList(delegate: SliverChildBuilderDelegate(
          (ctx, i) {
            if (i == _playlists.length) return const SizedBox(height: 100);
            return _PlaylistTile(playlist: _playlists[i]);
          },
          childCount: _playlists.length + 1,
        )),
    ]);
  }
}

// ── Playlist tile ──────────────────────────────────────────────────────────────
class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  const _PlaylistTile({required this.playlist});

  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: _art(api),
      title: Text(playlist.name,
        style: const TextStyle(color: Colors.white,
            fontWeight: FontWeight.w500, fontSize: 15),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        'Playlist · ${playlist.trackCount} titre${playlist.trackCount != 1 ? 's' : ''}',
        style: const TextStyle(color: Colors.white54, fontSize: 13)),
      trailing: GestureDetector(
        onTap: () => _showOptions(ctx, api),
        child: const Icon(Icons.more_vert, color: Colors.white38, size: 20)),
      onTap: () => _play(ctx),
    );
  }

  Widget _art(SwingApiService api) {
    final imgUrl = '${api.baseUrl}/img/playlist/${playlist.id}.webp';
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(imgUrl, width: 56, height: 56, fit: BoxFit.cover,
        headers: api.authHeaders,
        errorBuilder: (_, __, ___) => Container(
          width: 56, height: 56, color: const Color(0xFF282828),
          child: const Icon(Icons.queue_music_rounded,
              color: Colors.white38, size: 28))),
    );
  }

  Future<void> _play(BuildContext ctx) async {
    final tracks = await SwingApiService().getPlaylistTracks(playlist.id);
    if (ctx.mounted && tracks.isNotEmpty)
      ctx.read<PlayerProvider>().playSong(tracks.first, queue: tracks, index: 0);
  }

  void _showOptions(BuildContext ctx, SwingApiService api) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF282828),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          // En-tête
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  '${api.baseUrl}/img/playlist/${playlist.id}.webp',
                  width: 48, height: 48, fit: BoxFit.cover,
                  headers: api.authHeaders,
                  errorBuilder: (_, __, ___) => Container(
                    width: 48, height: 48, color: const Color(0xFF3E3E3E),
                    child: const Icon(Icons.queue_music_rounded,
                        color: Colors.white38, size: 24)))),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(playlist.name, style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold,
                      fontSize: 15),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${playlist.trackCount} titres',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ])),
            ]),
          ),
          const Divider(color: Colors.white12, height: 1),
          ListTile(
            leading: const Icon(Icons.play_circle_outline_rounded,
                color: Colors.white70),
            title: const Text('Lire', style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(ctx); _play(ctx); }),
          ListTile(
            leading: const Icon(Icons.shuffle_rounded, color: Colors.white70),
            title: const Text('Lecture aléatoire',
                style: TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(ctx);
              final tracks = await SwingApiService()
                  .getPlaylistTracks(playlist.id);
              if (ctx.mounted && tracks.isNotEmpty) {
                final p = ctx.read<PlayerProvider>();
                p.toggleShuffle();
                p.playSong(tracks.first, queue: tracks, index: 0);
              }
            }),
          ListTile(
            leading: const Icon(Icons.queue_music_rounded,
                color: Colors.white70),
            title: const Text('Ajouter à la file',
                style: TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(ctx);
              final tracks = await SwingApiService()
                  .getPlaylistTracks(playlist.id);
              if (ctx.mounted) {
                final p = ctx.read<PlayerProvider>();
                for (final t in tracks) p.addToQueue(t);
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                  content: Text('${tracks.length} titres ajoutés à la file'),
                  backgroundColor: const Color(0xFF282828),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2)));
              }
            }),
        ]),
      ),
    );
  }
}
