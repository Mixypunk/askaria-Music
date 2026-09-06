part of '../artist_screen.dart';

class _AllTracksScreen extends StatelessWidget {
  final String title;
  final List<Song> songs;
  const _AllTracksScreen({required this.title, required this.songs});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Sp.bg,
    appBar: AppBar(
      backgroundColor: Sp.bg,
      title: Text(title,
        style: const TextStyle(color: Sp.white,
            fontSize: 18, fontWeight: FontWeight.bold)),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Sp.white, size: 20),
        onPressed: () => Navigator.pop(context))),
    body: ListView.builder(
      itemCount: songs.length,
      itemBuilder: (ctx, i) => _TrackRow(
        song: songs[i], index: i + 1,
        all: songs, idx: i,
        onTap: () => Navigator.pop(context)),
    ),
  );
}

// ── Widgets communs ────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String title;
  const _Header(this.title);
  @override
  Widget build(BuildContext ctx) => SliverToBoxAdapter(child: Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
    child: Text(title, style: const TextStyle(
        color: Sp.white, fontSize: 20, fontWeight: FontWeight.bold)),
  ));
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label,
      required this.filled, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 46,
      decoration: BoxDecoration(
        gradient: filled ? kGrad : null,
        border: filled ? null : Border.all(color: Colors.white30),
        borderRadius: BorderRadius.circular(23)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ]),
    ),
  );
}

class _SeeAllBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SeeAllBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(4)),
        child: Center(child: Text(label,
          style: const TextStyle(
              color: Sp.white70, fontSize: 14, fontWeight: FontWeight.w500)))),
    ),
  );
}

class _TrackRow extends StatelessWidget {
  final Song song;
  final int index;
  final List<Song> all;
  final int idx;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const _TrackRow({required this.song, required this.index,
      required this.all, required this.idx, this.onTap, this.onLongPress});

  String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext ctx) {
    final player = ctx.watch<PlayerProvider>();
    final downloads = ctx.watch<DownloadsProvider>();
    final isCurrent = player.currentSong?.hash == song.hash;
    final isDownloaded = downloads.isDownloaded(song.hash);

    return GestureDetector(
      onTap: () {
        ctx.read<PlayerProvider>().playSong(song, queue: all, index: idx);
        onTap?.call();
      },
      onLongPress: onLongPress ?? () => _showSongMenu(ctx, song),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          // Numéro ou égaliseur
          SizedBox(width: 32, child: Center(
            child: isCurrent
                ? const GIcon(Icons.equalizer_rounded, size: 18)
                : Text('$index', style: TextStyle(
                    color: isCurrent ? Sp.g2 : Sp.white70, fontSize: 14)),
          )),
          const SizedBox(width: 8),
          // Artwork
          ArtworkWidget(
            key: ValueKey(song.hash),
            hash: song.image ?? song.hash,
            size: 46, borderRadius: BorderRadius.circular(4)),
          const SizedBox(width: 12),
          // Titre + artiste
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(song.title, style: TextStyle(
                color: isCurrent ? Sp.g2 : Sp.white,
                fontSize: 15, fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(song.artist,
                style: const TextStyle(color: Sp.white70, fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
          // Durée
          Row(children: [
            if (isDownloaded) ...[
              const Icon(Icons.download_done_rounded, size: 14, color: Colors.green),
              const SizedBox(width: 4),
            ],
            Text(_fmt(song.duration),
              style: const TextStyle(color: Sp.white40, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final Album album;
  const _AlbumCard({required this.album});
  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();
    final url = api.getThumbnailUrl(album.image);
    return GestureDetector(
      onTap: () async {
        final tracks = await SwingApiService().getAlbumTracks(album.hash);
        if (ctx.mounted && tracks.isNotEmpty) {
          Navigator.push(ctx, MaterialPageRoute(
            builder: (_) => _AllTracksScreen(
                title: album.title, songs: tracks)));
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: SizedBox(width: 130, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: NetImage(url: url, width: 130, height: 130,
              headers: url.startsWith(api.baseUrl) ? api.authHeaders : {},
              borderRadius: BorderRadius.circular(6),
              placeholder: Container(width: 130, height: 130, color: Sp.card,
                child: const Icon(Icons.album, color: Sp.white40, size: 40)))),
            const SizedBox(height: 8),
            Text(album.title,
              style: const TextStyle(color: Sp.white,
                  fontSize: 13, fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(album.year?.toString() ?? '',
              style: const TextStyle(color: Sp.white70, fontSize: 11)),
          ],
        )),
      ),
    );
  }
}

// ── Page Album détail ──────────────────────────────────────────────────────────
class _AddTracksScreen extends StatefulWidget {
  final String playlistId;
  final Set<String> existingHashes;
  const _AddTracksScreen({required this.playlistId,
      required this.existingHashes});
  @override
  State<_AddTracksScreen> createState() => _AddTracksScreenState();
}

class _AddTracksScreenState extends State<_AddTracksScreen> {
  final _ctrl = TextEditingController();
  List<Song> _results  = [];
  Set<String> _selected = {};
  bool _loading  = false;
  bool _saving   = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    if (v.trim().isEmpty) {
      setState(() { _results = []; _loading = false; });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(v));
  }

  Future<void> _search(String q) async {
    try {
      final r = await SwingApiService().searchSongs(q);
      if (mounted) setState(() { _results = r; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _results = []; _loading = false; });
    }
  }

  Future<void> _save() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);
    final ok = await SwingApiService()
        .addTracksToPlaylist(widget.playlistId, _selected.toList());
    if (!mounted) return;
    if (ok) {
      final added = _results.where((s) => _selected.contains(s.hash)).toList();
      Navigator.pop(context, added);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Erreur lors de l\'ajout'),
        behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Sp.bg,
      appBar: AppBar(
        backgroundColor: Sp.bg,
        title: const Text('Ajouter des titres',
          style: TextStyle(color: Colors.white,
              fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
        actions: [
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('Ajouter (${_selected.length})',
                        style: TextStyle(
                          color: Sp.g2, fontWeight: FontWeight.bold,
                          fontSize: 15)),
              ),
            ),
        ],
      ),
      body: Column(children: [
        // ── Barre de recherche ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(4)),
            child: Row(children: [
              const SizedBox(width: 12),
              const Icon(Icons.search, color: Colors.black, size: 22),
              const SizedBox(width: 8),
              Expanded(child: TextField(
                controller: _ctrl,
                autofocus: true,
                style: const TextStyle(color: Colors.black, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Rechercher un titre…',
                  hintStyle: TextStyle(color: Color(0xFF666666)),
                  border: InputBorder.none, isDense: true),
                onChanged: _onChanged,
              )),
              if (_ctrl.text.isNotEmpty)
                GestureDetector(
                  onTap: () { _ctrl.clear(); _onChanged(''); },
                  child: const Padding(padding: EdgeInsets.all(10),
                    child: Icon(Icons.clear, color: Colors.black, size: 20))),
            ]),
          ),
        ),

        // ── Chip "X sélectionné(s)" ───────────────────────────────
        if (_selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: kGrad,
                  borderRadius: BorderRadius.circular(16)),
                child: Text(
                  '${_selected.length} titre${_selected.length > 1 ? "s" : ""} sélectionné${_selected.length > 1 ? "s" : ""}',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 12, fontWeight: FontWeight.w600))),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _selected.clear()),
                child: const Text('Tout désélectionner',
                  style: TextStyle(color: Colors.white54, fontSize: 12))),
            ]),
          ),

        // ── Résultats ─────────────────────────────────────────────
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(
              color: Sp.g2, strokeWidth: 2))
          : _results.isEmpty && _ctrl.text.isNotEmpty
            ? const Center(child: Text('Aucun résultat',
                style: TextStyle(color: Colors.white54)))
            : _results.isEmpty
              ? const Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_rounded,
                        color: Colors.white24, size: 56),
                    SizedBox(height: 12),
                    Text('Tapez le nom d\'un titre',
                      style: TextStyle(color: Colors.white54)),
                  ]))
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (ctx, i) {
                    final song = _results[i];
                    final alreadyIn =
                        widget.existingHashes.contains(song.hash);
                    final selected = _selected.contains(song.hash);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      leading: Stack(children: [
                        ArtworkWidget(key: ValueKey(song.hash),
                          hash: song.image ?? song.hash, size: 48,
                          borderRadius: BorderRadius.circular(4)),
                        if (selected)
                          Positioned.fill(child: Container(
                            decoration: BoxDecoration(
                              color: Sp.g2.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4)),
                            child: const Icon(Icons.check_rounded,
                                color: Colors.white, size: 22))),
                        if (alreadyIn && !selected)
                          Positioned.fill(child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4)),
                            child: const Icon(Icons.check_rounded,
                                color: Colors.white38, size: 18))),
                      ]),
                      title: Text(song.title, style: TextStyle(
                        color: alreadyIn ? Colors.white38 : Colors.white,
                        fontSize: 14, fontWeight: FontWeight.w500),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        alreadyIn
                            ? '${song.artist} · Déjà dans la playlist'
                            : song.artist,
                        style: TextStyle(
                          color: alreadyIn
                              ? Colors.white24 : Colors.white54,
                          fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: alreadyIn
                          ? null
                          : Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.add_circle_outline_rounded,
                              color: selected ? Sp.g2 : Colors.white38,
                              size: 24),
                      onTap: alreadyIn ? null : () {
                        setState(() {
                          selected
                              ? _selected.remove(song.hash)
                              : _selected.add(song.hash);
                        });
                      },
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ── Menu rapide sur un titre (long press) ─────────────────────────────────────
void _showSongMenu(BuildContext ctx, Song song) {
  showModalBottomSheet(
    context: ctx,
    backgroundColor: const Color(0xFF282828),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _SongQuickMenu(song: song),
  );
}

class _SongQuickMenu extends StatefulWidget {
  final Song song;
  const _SongQuickMenu({required this.song});
  @override
  State<_SongQuickMenu> createState() => _SongQuickMenuState();
}

class _SongQuickMenuState extends State<_SongQuickMenu> {
  List<Playlist> _playlists = [];
  bool _loadingPl = true;

  @override
  void initState() {
    super.initState();
    // Utiliser le cache du provider au lieu d'appeler l'API directement
    context.read<PlayerProvider>().getCachedPlaylists().then((pl) {
      if (mounted) setState(() {
        _playlists = pl.cast();
        _loadingPl = false;
      });
    });
  }

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white24,
              borderRadius: BorderRadius.circular(2))),
        // Titre de la chanson
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            ArtworkWidget(key: ValueKey(widget.song.hash),
              hash: widget.song.image ?? widget.song.hash, size: 44,
              borderRadius: BorderRadius.circular(4)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.song.title, style: const TextStyle(
                  color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(widget.song.artist, style: const TextStyle(
                  color: Colors.white54, fontSize: 13),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
          ])),
        const Divider(color: Colors.white12, height: 1),
        ListTile(
          leading: const Icon(Icons.queue_music_rounded, color: Colors.white70),
          title: const Text('Ajouter à la file d\'attente',
            style: TextStyle(color: Colors.white)),
          onTap: () {
            ctx.read<PlayerProvider>().addNextInQueue(widget.song);
            Navigator.pop(context);
          }),
        // Ajouter à une playlist
        if (_loadingPl)
          const Padding(padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(
                color: Sp.g2, strokeWidth: 2)))
        else if (_playlists.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('AJOUTER À UNE PLAYLIST',
              style: TextStyle(color: Colors.white38, fontSize: 11,
                  letterSpacing: 1.2, fontWeight: FontWeight.w600))),
          ...(_playlists.take(5).map((pl) => ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 2),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: NetImage(
                url: '${SwingApiService().baseUrl}/img/playlist/${pl.id}.webp',
                width: 36, height: 36,
                headers: SwingApiService().authHeaders,
                borderRadius: BorderRadius.circular(4))),
            title: Text(pl.name, style: const TextStyle(
                color: Colors.white, fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () async {
              Navigator.pop(context);
              final ok = await SwingApiService()
                  .addTracksToPlaylist(pl.id, [widget.song.hash]);
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                  content: Text(ok
                    ? 'Ajouté à « ${pl.name} »'
                    : 'Erreur lors de l\'ajout'),
                  behavior: SnackBarBehavior.floating));
              }
            }))),
        ],
      ]),
    );
  }
}

