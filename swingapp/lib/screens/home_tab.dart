import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/song.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../services/api_service.dart';
import '../providers/player_provider.dart';
import '../widgets/artwork_widget.dart';
import 'player_screen.dart';
import 'settings_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<Song> _songs = [];
  List<Album> _albums = [];
  List<Artist> _artists = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        SwingApiService().getSongs(limit: 50),
        SwingApiService().getAlbums(limit: 20),
        SwingApiService().getArtists(limit: 20),
      ]);
      _songs   = results[0] as List<Song>;
      _albums  = results[1] as List<Album>;
      _artists = results[2] as List<Artist>;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: [
      // ── AppBar Spotify ─────────────────────────────────────────────
      SliverAppBar(
        floating: true,
        backgroundColor: Sp.bg,
        title: Text(_greeting(),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Sp.white)),
        actions: [
          _avatar(),
          const SizedBox(width: 8),
        ],
      ),

      if (_loading)
        const SliverFillRemaining(child: Center(
          child: CircularProgressIndicator(color: Sp.g2, strokeWidth: 2)))
      else ...[
        // ── Recently played 2×3 grid ────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8,
              childAspectRatio: 4.5,
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                if (i >= _songs.length) return null;
                return _RecentTile(song: _songs[i], allSongs: _songs, idx: i);
              },
              childCount: (_songs.length).clamp(0, 6),
            ),
          ),
        ),

        // ── New Albums ──────────────────────────────────────────────
        if (_albums.isNotEmpty) ...[
          _SectionHeader('Nouveaux albums', onMore: null),
          SliverToBoxAdapter(child: SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _albums.length,
              itemBuilder: (ctx, i) => _AlbumCard(album: _albums[i]),
            ),
          )),
        ],

        // ── Your Artists ────────────────────────────────────────────
        if (_artists.isNotEmpty) ...[
          _SectionHeader('Vos artistes', onMore: null),
          SliverToBoxAdapter(child: SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _artists.length,
              itemBuilder: (ctx, i) => _ArtistCard(artist: _artists[i]),
            ),
          )),
        ],

        // ── All Songs ───────────────────────────────────────────────
        if (_songs.isNotEmpty) ...[
          _SectionHeader('Tous les titres', onMore: null),
          SliverList(delegate: SliverChildBuilderDelegate(
            (ctx, i) => _SongRow(song: _songs[i], all: _songs, idx: i),
            childCount: _songs.length,
          )),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    ]);
  }

  Widget _avatar() => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
    child: Container(
      width: 32, height: 32,
      decoration: const BoxDecoration(gradient: kGrad, shape: BoxShape.circle),
      child: const Icon(Icons.person_rounded, size: 18, color: Colors.white),
    ),
  );
}

// ── Recently played pill ────────────────────────────────────────────────────
class _RecentTile extends StatelessWidget {
  final Song song; final List<Song> allSongs; final int idx;
  const _RecentTile({required this.song, required this.allSongs, required this.idx});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: () => ctx.read<PlayerProvider>().playSong(song, queue: allSongs, index: idx),
    child: Container(
      decoration: BoxDecoration(color: Sp.card, borderRadius: BorderRadius.circular(4)),
      child: Row(children: [
        ClipRRect(
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
          child: ArtworkWidget(
            key: ValueKey(song.hash), hash: song.image ?? song.hash,
            size: 48, borderRadius: BorderRadius.zero,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(song.title,
          style: const TextStyle(color: Sp.white, fontSize: 12, fontWeight: FontWeight.w600),
          maxLines: 2, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 4),
      ]),
    ),
  );
}

// ── Section header ──────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title; final VoidCallback? onMore;
  const _SectionHeader(this.title, {this.onMore});
  @override
  Widget build(BuildContext ctx) => SliverToBoxAdapter(child: Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: const TextStyle(
          color: Sp.white, fontSize: 22, fontWeight: FontWeight.bold)),
      if (onMore != null)
        GestureDetector(onTap: onMore,
          child: const Text('Tout voir', style: TextStyle(color: Sp.white70, fontSize: 13))),
    ]),
  ));
}

// ── Album card horizontal scroll ────────────────────────────────────────────
class _AlbumCard extends StatelessWidget {
  final Album album;
  const _AlbumCard({required this.album});
  @override
  Widget build(BuildContext ctx) {
    final url = '${SwingApiService().baseUrl}/img/thumbnail/${album.image}';
    return GestureDetector(
      onTap: () => _openAlbum(ctx, album),
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: SizedBox(width: 140, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(url, width: 140, height: 140, fit: BoxFit.cover,
                headers: SwingApiService().authHeaders,
                errorBuilder: (_, __, ___) => Container(
                  width: 140, height: 140, color: Sp.card,
                  child: const Icon(Icons.album, color: Sp.white40, size: 48))),
            ),
            const SizedBox(height: 8),
            Text(album.title,
              style: const TextStyle(color: Sp.white, fontSize: 13, fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(album.artist,
              style: const TextStyle(color: Sp.white70, fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        )),
      ),
    );
  }

  void _openAlbum(BuildContext ctx, Album album) async {
    final tracks = await SwingApiService().getAlbumTracks(album.hash);
    if (ctx.mounted && tracks.isNotEmpty) {
      ctx.read<PlayerProvider>().playSong(tracks.first, queue: tracks, index: 0);
    }
  }
}

// ── Artist card ─────────────────────────────────────────────────────────────
class _ArtistCard extends StatelessWidget {
  final Artist artist;
  const _ArtistCard({required this.artist});
  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();
    final url = '${api.baseUrl}/img/artist/small/${artist.image}';
    return GestureDetector(
      onTap: () => _openArtist(ctx, artist),
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: SizedBox(width: 120, child: Column(
          children: [
            ClipOval(child: Image.network(url, width: 120, height: 120, fit: BoxFit.cover,
              headers: api.authHeaders,
              errorBuilder: (_, __, ___) => Container(
                width: 120, height: 120, color: Sp.card,
                child: const Icon(Icons.person, color: Sp.white40, size: 48)))),
            const SizedBox(height: 8),
            Text(artist.name,
              style: const TextStyle(color: Sp.white, fontSize: 13, fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            const Text('Artiste', style: TextStyle(color: Sp.white70, fontSize: 12)),
          ],
        )),
      ),
    );
  }

  void _openArtist(BuildContext ctx, Artist artist) async {
    final tracks = await SwingApiService().getArtistTracks(artist.hash);
    if (ctx.mounted && tracks.isNotEmpty) {
      ctx.read<PlayerProvider>().playSong(tracks.first, queue: tracks, index: 0);
    }
  }
}

// ── Song row (liste) ─────────────────────────────────────────────────────────
class _SongRow extends StatelessWidget {
  final Song song; final List<Song> all; final int idx;
  const _SongRow({required this.song, required this.all, required this.idx});
  @override
  Widget build(BuildContext ctx) {
    final player = ctx.watch<PlayerProvider>();
    final isCurrent = player.currentSong == song;
    return GestureDetector(
      onTap: () => ctx.read<PlayerProvider>().playSong(song, queue: all, index: idx),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          ArtworkWidget(
            key: ValueKey(song.hash), hash: song.image ?? song.hash,
            size: 48, borderRadius: BorderRadius.circular(4)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(song.title, style: TextStyle(
              color: isCurrent ? Sp.g2 : Sp.white,
              fontSize: 15, fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(song.artist,
              style: const TextStyle(color: Sp.white70, fontSize: 13),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          if (isCurrent) const GIcon(Icons.equalizer_rounded, size: 20)
          else const Icon(Icons.more_horiz, color: Sp.white40, size: 20),
        ]),
      ),
    );
  }
}
