part of '../artist_screen.dart';

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
  final ValueNotifier<double> _headerOpacity = ValueNotifier(0.0);

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(() {
      final opacity = (_scroll.offset / 200).clamp(0.0, 1.0);
      if ((opacity - _headerOpacity.value).abs() > 0.01) {
        _headerOpacity.value = opacity;
      }
    });
  }

  Future<void> _load() async {
    var hash = widget.artist.hash;

    try {
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
    } catch (e) {
      if (mounted) {
        final dlSongs = context.read<DownloadsProvider>().downloadedSongs;
        _tracks = dlSongs
            .where((s) => s.artist == widget.artist.name || (s.artistHash.isNotEmpty && s.artistHash == widget.artist.hash))
            .toList();

        final Map<String, List<Song>> albumsMap = {};
        for (final song in _tracks) {
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

        setState(() => _loading = false);
      }
    }
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
                title: ValueListenableBuilder<double>(
                  valueListenable: _headerOpacity,
                  builder: (context, opacity, child) => Opacity(
                    opacity: opacity,
                    child: Text(widget.artist.name,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                background: Stack(fit: StackFit.expand, children: [
                  NetImage(url: imgUrl, width: double.infinity, height: double.infinity,
                    headers: api.authHeaders,
                    placeholder: Container(color: Sp.card,
                      child: const Icon(Icons.person_rounded, color: Sp.white40, size: 80))),
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
