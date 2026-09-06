part of '../artist_screen.dart';

class AlbumScreen extends StatefulWidget {
  final Album album;
  const AlbumScreen({super.key, required this.album});
  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  List<Song> _tracks = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      _tracks = await SwingApiService().getAlbumTracks(widget.album.hash);
    } catch (e) { LoggerService.warning('Silent error caught in album_view.dart', e); }
    if (mounted) setState(() => _loading = false);
  }

  Duration get _totalDuration => Duration(
      seconds: _tracks.fold(0, (s, t) => s + t.duration));

  String _fmtDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}min';
    return '${d.inMinutes}min';
  }

  @override
  Widget build(BuildContext context) {
    final api = SwingApiService();
    final imgUrl = api.getThumbnailUrl(widget.album.image);

    return Scaffold(
      backgroundColor: Sp.bg,
      body: CustomScrollView(slivers: [

        // ── Header ──────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 320,
          pinned: true,
          backgroundColor: Sp.bg,
          leading: IconButton(
            icon: Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(
                  color: Colors.black45, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18)),
            onPressed: () => Navigator.pop(context)),
          flexibleSpace: FlexibleSpaceBar(
            background: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                // Pochette
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 30, offset: const Offset(0, 10))]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: NetImage(url: imgUrl, width: 160, height: 160,
                  headers: imgUrl.startsWith(api.baseUrl) ? api.authHeaders : {},
                  borderRadius: BorderRadius.circular(8),
                  placeholder: Container(width: 160, height: 160, color: Sp.card,
                    child: const Icon(Icons.album, color: Sp.white40, size: 64))))),
                const SizedBox(height: 16),
                // Titre
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(widget.album.title,
                    style: const TextStyle(color: Sp.white,
                        fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
                const SizedBox(height: 4),
                // Artiste + année
                Text(
                  widget.album.artist +
                  (widget.album.year != null
                      ? ' · ${widget.album.year}' : ''),
                  style: const TextStyle(color: Sp.white70, fontSize: 14)),
              ],
            ),
          ),
        ),

        // ── Infos + boutons ──────────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(children: [
            Text(
              '${_tracks.length} titre${_tracks.length != 1 ? 's' : ''}'
              '${_tracks.isNotEmpty ? ' · ${_fmtDuration(_totalDuration)}' : ''}',
              style: const TextStyle(color: Sp.white70, fontSize: 13)),
            const SizedBox(height: 16),
            if (!_loading) Row(children: [
              Expanded(child: _ActionBtn(
                icon: Icons.play_arrow_rounded,
                label: 'Lecture',
                filled: true,
                onTap: () => _play(shuffle: false))),
              const SizedBox(width: 12),
              Expanded(child: _ActionBtn(
                icon: Icons.shuffle_rounded,
                label: 'Aléatoire',
                filled: false,
                onTap: () => _play(shuffle: true))),
            ]),
          ]),
        )),

        if (_loading)
          const SliverFillRemaining(child: Center(
            child: CircularProgressIndicator(color: Sp.g2, strokeWidth: 2)))
        else if (_tracks.isEmpty)
          const SliverFillRemaining(child: Center(
            child: Text('Album vide',
                style: TextStyle(color: Sp.white70))))
        else
          SliverList(delegate: SliverChildBuilderDelegate(
            (ctx, i) => _TrackRow(
              song: _tracks[i],
              index: i + 1,
              all: _tracks,
              idx: i,
              onTap: () => Navigator.pop(context)),
            childCount: _tracks.length,
          )),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ]),
    );
  }

  void _play({required bool shuffle}) {
    if (_tracks.isEmpty) return;
    final p = context.read<PlayerProvider>();
    if (shuffle) p.toggleShuffle();
    p.playSong(_tracks.first, queue: _tracks, index: 0);
    Navigator.pop(context);
  }
}

// ── Écran ajout de titres à une playlist ──────────────────────────────────────

