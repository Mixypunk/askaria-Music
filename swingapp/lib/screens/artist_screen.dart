import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/song.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../services/api_service.dart';
import '../providers/player_provider.dart';
import '../widgets/artwork_widget.dart';

class ArtistScreen extends StatefulWidget {
  final Artist artist;
  const ArtistScreen({super.key, required this.artist});
  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  List<Song>  _tracks = [];
  List<Album> _albums = [];
  bool _loading = true;
  final _scroll = ScrollController();
  double _headerOpacity = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(() {
      final opacity = (_scroll.offset / 200).clamp(0.0, 1.0);
      if ((opacity - _headerOpacity).abs() > 0.01) {
        setState(() => _headerOpacity = opacity);
      }
    });
  }

  Future<void> _load() async {
    var hash = widget.artist.hash;

    // Si le hash est vide, chercher l'artiste par nom
    if (hash.isEmpty && widget.artist.name.isNotEmpty) {
      final found = await SwingApiService()
          .searchArtistByName(widget.artist.name);
      if (found != null) hash = found.hash;
    }

    if (hash.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final results = await Future.wait([
      SwingApiService().getArtistTracks(hash),
      SwingApiService().getArtistAlbums(hash),
    ]);
    if (mounted) setState(() {
      _tracks = results[0] as List<Song>;
      _albums = results[1] as List<Album>;
      _loading = false;
    });
  }

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final api = SwingApiService();
    final imgUrl = '${api.baseUrl}/img/artist/small/${widget.artist.image}';

    return Scaffold(
      backgroundColor: Sp.bg,
      body: Stack(children: [

        // ── Contenu scrollable ─────────────────────────────────────
        CustomScrollView(
          controller: _scroll,
          slivers: [

            // ── Header grand format ──────────────────────────────
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              backgroundColor: Sp.bg,
              leading: IconButton(
                icon: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18)),
                onPressed: () => Navigator.pop(context)),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                title: Opacity(
                  opacity: _headerOpacity,
                  child: Text(widget.artist.name,
                    style: const TextStyle(color: Colors.white,
                        fontSize: 16, fontWeight: FontWeight.bold))),
                background: Stack(fit: StackFit.expand, children: [
                  Image.network(imgUrl, fit: BoxFit.cover,
                    headers: api.authHeaders,
                    errorBuilder: (_, __, ___) => Container(
                      color: Sp.card,
                      child: const Icon(Icons.person_rounded,
                          color: Sp.white40, size: 80))),
                  // Dégradé bas
                  const DecoratedBox(decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Sp.bg],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.4, 1.0]))),
                ]),
              ),
            ),

            // ── Nom + stats ──────────────────────────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.artist.name,
                    style: const TextStyle(color: Sp.white,
                        fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.artist.trackCount} titre${widget.artist.trackCount != 1 ? 's' : ''}'
                    ' · ${widget.artist.albumCount} album${widget.artist.albumCount != 1 ? 's' : ''}',
                    style: const TextStyle(color: Sp.white70, fontSize: 13)),
                  const SizedBox(height: 16),

                  // Boutons Lecture / Aléatoire
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
                child: CircularProgressIndicator(
                    color: Sp.g2, strokeWidth: 2)))
            else ...[

              // ── Titres populaires ────────────────────────────
              if (_tracks.isNotEmpty) ...[
                const _Header('Titres populaires'),
                SliverList(delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _TrackRow(
                    song: _tracks[i],
                    index: i + 1,
                    all: _tracks,
                    idx: i),
                  childCount: _tracks.length.clamp(0, 5),
                )),

                // "Voir tous les titres" si > 5
                if (_tracks.length > 5)
                  SliverToBoxAdapter(child: _SeeAllBtn(
                    label: 'Voir les ${_tracks.length} titres',
                    onTap: () => _showAllTracks(context))),
              ],

              // ── Albums ───────────────────────────────────────
              if (_albums.isNotEmpty) ...[
                const _Header('Albums'),
                SliverToBoxAdapter(child: SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _albums.length,
                    itemBuilder: (ctx, i) =>
                        _AlbumCard(album: _albums[i]),
                  ),
                )),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
        ),
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

  void _showAllTracks(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _AllTracksScreen(
          title: widget.artist.name, songs: _tracks)));
  }
}

// ── Page Playlist ──────────────────────────────────────────────────────────────
class PlaylistScreen extends StatefulWidget {
  final dynamic playlist; // Playlist model
  const PlaylistScreen({super.key, required this.playlist});
  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  List<Song> _tracks = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      _tracks = await SwingApiService()
          .getPlaylistTracks(widget.playlist.id);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Duration get _totalDuration => Duration(
    seconds: _tracks.fold(0, (sum, s) => sum + s.duration));

  @override
  Widget build(BuildContext context) {
    final api = SwingApiService();
    final imgUrl =
        '${api.baseUrl}/img/playlist/${widget.playlist.id}.webp';

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
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(imgUrl,
                    width: 160, height: 160, fit: BoxFit.cover,
                    headers: api.authHeaders,
                    errorBuilder: (_, __, ___) => Container(
                      width: 160, height: 160, color: Sp.card,
                      child: const Icon(Icons.queue_music_rounded,
                          color: Sp.white40, size: 64)))),
                const SizedBox(height: 16),
                // Nom
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(widget.playlist.name,
                    style: const TextStyle(color: Sp.white,
                        fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ),

        // ── Infos + boutons ──────────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(children: [
            // Stats
            Text(
              '${_tracks.length} titre${_tracks.length != 1 ? 's' : ''}'
              ' · ${_fmtDuration(_totalDuration)}',
              style: const TextStyle(color: Sp.white70, fontSize: 13)),
            if (widget.playlist.description != null &&
                widget.playlist.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(widget.playlist.description!,
                style: const TextStyle(color: Sp.white70, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 16),

            // Boutons
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
            child: CircularProgressIndicator(
                color: Sp.g2, strokeWidth: 2)))
        else if (_tracks.isEmpty)
          const SliverFillRemaining(child: Center(
            child: Text('Playlist vide',
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

  String _fmtDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}min';
    }
    return '${d.inMinutes}min';
  }
}

// ── Écran tous les titres ──────────────────────────────────────────────────────
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
  const _TrackRow({required this.song, required this.index,
      required this.all, required this.idx, this.onTap});

  String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext ctx) {
    final player = ctx.watch<PlayerProvider>();
    final isCurrent = player.currentSong?.hash == song.hash;

    return GestureDetector(
      onTap: () {
        ctx.read<PlayerProvider>().playSong(song, queue: all, index: idx);
        onTap?.call();
      },
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
          Text(_fmt(song.duration),
            style: const TextStyle(color: Sp.white40, fontSize: 12)),
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
    final url = '${api.baseUrl}/img/thumbnail/${album.image}';
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
              child: Image.network(url, width: 130, height: 130,
                fit: BoxFit.cover,
                headers: api.authHeaders,
                errorBuilder: (_, __, ___) => Container(
                  width: 130, height: 130, color: Sp.card,
                  child: const Icon(Icons.album,
                      color: Sp.white40, size: 40)))),
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
    } catch (_) {}
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
    final imgUrl = '${api.baseUrl}/img/thumbnail/${widget.album.image}';

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
                    child: Image.network(imgUrl,
                      width: 160, height: 160, fit: BoxFit.cover,
                      headers: api.authHeaders,
                      errorBuilder: (_, __, ___) => Container(
                        width: 160, height: 160, color: Sp.card,
                        child: const Icon(Icons.album,
                            color: Sp.white40, size: 64))))),
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
