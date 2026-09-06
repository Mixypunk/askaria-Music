part of '../library_tab.dart';

class _FavouritesList extends StatelessWidget {
  const _FavouritesList();
  @override
  Widget build(BuildContext ctx) {
    return Consumer<PlayerProvider>(builder: (ctx, player, _) {
      return _FavouritesContent(player: player);
    });
  }
}

class _FavouritesContent extends StatefulWidget {
  final PlayerProvider player;
  const _FavouritesContent({required this.player});
  @override
  State<_FavouritesContent> createState() => _FavouritesContentState();
}

class _FavouritesContentState extends State<_FavouritesContent> {
  List<Song> _songs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      _songs = await SwingApiService().getFavourites();
    } catch (_) {
      try {
        final dlSongs = context.read<DownloadsProvider>().downloadedSongs;
        final player = context.read<PlayerProvider>();
        _songs = dlSongs.where((s) => player.isFavourite(s.hash)).toList();
      } catch (e) { LoggerService.warning('Silent error caught in library_favs.dart', e); }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext ctx) {
    if (_loading) return const Center(
      child: CircularProgressIndicator(color: Sp.g2, strokeWidth: 2));
    if (_songs.isEmpty) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: Sp.card, borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.favorite_border_rounded,
              color: Sp.white40, size: 36),
        ),
        const SizedBox(height: 16),
        const Text('Aucun favori',
            style: TextStyle(color: Sp.white70, fontSize: 16)),
        const SizedBox(height: 8),
        const Text('Likez des titres depuis le lecteur',
          style: TextStyle(color: Sp.white40, fontSize: 13)),
      ],
    ));
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120, top: 8),
      itemCount: _songs.length,
      itemBuilder: (ctx, i) {
        final song = _songs[i];
        // Selector ciblé : ne rebuild que si CE titre devient/cesse d'être courant
        final isCurrent = ctx.select<PlayerProvider, bool>(
            (p) => p.currentSong?.hash == song.hash);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: GestureDetector(
            onTap: () => ctx.read<PlayerProvider>()
                .playSong(song, queue: _songs, index: i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: kCardDecoration(radius: 14),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ArtworkWidget(
                    key: ValueKey(song.hash),
                    hash: song.image ?? song.hash,
                    size: 50, borderRadius: BorderRadius.circular(10))),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title, style: TextStyle(
                      color: isCurrent ? Sp.g2 : Colors.white,
                      fontWeight: FontWeight.w600, fontSize: 15),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(song.artist,
                      style: const TextStyle(
                          color: Sp.white70, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                GestureDetector(
                  onTap: () {
                    ctx.read<PlayerProvider>().toggleFavourite(song.hash);
                    setState(() => _songs.removeAt(i));
                  },
                  child: const Icon(Icons.favorite_rounded,
                      color: Colors.redAccent, size: 22)),
              ]),
            ),
          ),
        );
      },
    );
  }
}
