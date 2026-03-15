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
import 'artist_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<Song>   _songs   = [];
  List<Album>  _albums  = [];
  List<Artist> _artists = [];
  bool _loading = true;
  bool _offline = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _offline = false; });
    try {
      final results = await Future.wait([
        SwingApiService().getSongs(limit: 500),   // Plus de limite à 50
        SwingApiService().getAlbums(limit: 20),
        SwingApiService().getArtists(limit: 20),
      ]).timeout(const Duration(seconds: 15));
      _songs   = results[0] as List<Song>;
      _albums  = results[1] as List<Album>;
      _artists = results[2] as List<Artist>;
    } catch (_) {
      _offline = _songs.isEmpty; // offline seulement si pas de données en cache
    }
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
    return RefreshIndicator(
      color: Sp.g2,
      backgroundColor: Sp.card,
      onRefresh: _load,
      child: CustomScrollView(slivers: [
        SliverAppBar(
          floating: true,
          backgroundColor: Sp.bg,
          title: Text(_greeting(),
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Sp.white)),
          actions: [
            _avatar(),
            const SizedBox(width: 8),
          ],
        ),

        if (_loading)
          const SliverFillRemaining(child: Center(
            child: CircularProgressIndicator(color: Sp.g2, strokeWidth: 2)))

        else if (_offline)
          SliverFillRemaining(child: Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, color: Sp.white40, size: 64),
              const SizedBox(height: 16),
              const Text('Serveur inaccessible',
                style: TextStyle(color: Sp.white, fontSize: 18,
                    fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Vérifiez votre connexion ou l\'URL du serveur',
                style: TextStyle(color: Sp.white70, fontSize: 13),
                textAlign: TextAlign.center),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _load,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: kGrad,
                    borderRadius: BorderRadius.circular(24)),
                  child: const Text('Réessayer',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold)))),
            ],
          )))

        else ...[
          // ── Grille récents ────────────────────────────────────────
          if (_songs.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8,
                  childAspectRatio: 4.5),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _RecentTile(
                      song: _songs[i], allSongs: _songs, idx: i),
                  childCount: _songs.length.clamp(0, 6),
                ),
              ),
            ),

          // ── Albums ────────────────────────────────────────────────
          if (_albums.isNotEmpty) ...[
            _SectionHeader('Nouveaux albums'),
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

          // ── Artistes ──────────────────────────────────────────────
          if (_artists.isNotEmpty) ...[
            _SectionHeader('Vos artistes'),
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

          // ── Tous les titres avec "Tout voir" ──────────────────────
          if (_songs.isNotEmpty) ...[
            _SectionHeader('Tous les titres',
                count: _songs.length,
                onMore: () => _showAllSongs(context)),
            SliverList(delegate: SliverChildBuilderDelegate(
              (ctx, i) => _SongRow(song: _songs[i], all: _songs, idx: i),
              childCount: _songs.length.clamp(0, 10), // 10 en preview
            )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: GestureDetector(
                onTap: () => _showAllSongs(context),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(4)),
                  child: const Center(child: Text('Voir tous les titres',
                    style: TextStyle(color: Sp.white70,
                        fontSize: 14, fontWeight: FontWeight.w500)))),
              ),
            )),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ]),
    );
  }

  void _showAllSongs(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _AllSongsScreen(songs: _songs)));
  }

  Widget _avatar() => GestureDetector(
    onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => const SettingsScreen())),
    child: Container(
      width: 32, height: 32,
      decoration: const BoxDecoration(gradient: kGrad, shape: BoxShape.circle),
      child: const Icon(Icons.person_rounded, size: 18, color: Colors.white),
    ),
  );
}

// ── Écran "Tous les titres" ────────────────────────────────────────────────────
class _AllSongsScreen extends StatelessWidget {
  final List<Song> songs;
  const _AllSongsScreen({required this.songs});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Sp.bg,
      appBar: AppBar(
        backgroundColor: Sp.bg,
        title: Text('${songs.length} titres',
          style: const TextStyle(color: Sp.white,
              fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 30, color: Sp.white),
          onPressed: () => Navigator.pop(context)),
      ),
      body: ListView.builder(
        itemCount: songs.length,
        itemBuilder: (ctx, i) =>
            _SongRow(song: songs[i], all: songs, idx: i),
      ),
    );
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────────
class _RecentTile extends StatelessWidget {
  final Song song; final List<Song> allSongs; final int idx;
  const _RecentTile({required this.song, required this.allSongs, required this.idx});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: () => ctx.read<PlayerProvider>()
        .playSong(song, queue: allSongs, index: idx),
    child: Container(
      decoration: BoxDecoration(
          color: Sp.card, borderRadius: BorderRadius.circular(4)),
      child: Row(children: [
        ClipRRect(
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
          child: ArtworkWidget(
            key: ValueKey(song.hash), hash: song.image ?? song.hash,
            size: 48, borderRadius: BorderRadius.zero),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(song.title,
          style: const TextStyle(color: Sp.white,
              fontSize: 12, fontWeight: FontWeight.w600),
          maxLines: 2, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 4),
      ]),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMore;
  final int? count;
  const _SectionHeader(this.title, {this.onMore, this.count});
  @override
  Widget build(BuildContext ctx) => SliverToBoxAdapter(child: Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: const TextStyle(
          color: Sp.white, fontSize: 22, fontWeight: FontWeight.bold)),
      if (onMore != null)
        GestureDetector(
          onTap: onMore,
          child: Text(
            count != null ? 'Tout voir ($count)' : 'Tout voir',
            style: const TextStyle(color: Sp.white70, fontSize: 13))),
    ]),
  ));
}

class _AlbumCard extends StatelessWidget {
  final Album album;
  const _AlbumCard({required this.album});
  @override
  Widget build(BuildContext ctx) {
    final url = '${SwingApiService().baseUrl}/img/thumbnail/${album.image}';
    return GestureDetector(
      onTap: () => _openAlbum(ctx),
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: SizedBox(width: 140, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(url, width: 140, height: 140,
                fit: BoxFit.cover,
                headers: SwingApiService().authHeaders,
                errorBuilder: (_, __, ___) => Container(
                  width: 140, height: 140, color: Sp.card,
                  child: const Icon(Icons.album,
                      color: Sp.white40, size: 48)))),
            const SizedBox(height: 8),
            Text(album.title,
              style: const TextStyle(color: Sp.white,
                  fontSize: 13, fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(album.artist,
              style: const TextStyle(color: Sp.white70, fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        )),
      ),
    );
  }

  void _openAlbum(BuildContext ctx) {
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => AlbumScreen(album: album)));
  }
}

class _ArtistCard extends StatelessWidget {
  final Artist artist;
  const _ArtistCard({required this.artist});
  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();
    final url = '${api.baseUrl}/img/artist/small/${artist.image}';
    return GestureDetector(
      onTap: () => _openArtist(ctx),
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: SizedBox(width: 120, child: Column(children: [
          ClipOval(child: Image.network(url, width: 120, height: 120,
            fit: BoxFit.cover,
            headers: api.authHeaders,
            errorBuilder: (_, __, ___) => Container(
              width: 120, height: 120, color: Sp.card,
              child: const Icon(Icons.person,
                  color: Sp.white40, size: 48)))),
          const SizedBox(height: 8),
          Text(artist.name,
            style: const TextStyle(color: Sp.white,
                fontSize: 13, fontWeight: FontWeight.w500),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center),
          const Text('Artiste',
            style: TextStyle(color: Sp.white70, fontSize: 12)),
        ])),
      ),
    );
  }

  void _openArtist(BuildContext ctx) {
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => ArtistScreen(artist: artist)));
  }
}

class _SongRow extends StatelessWidget {
  final Song song; final List<Song> all; final int idx;
  const _SongRow({required this.song, required this.all, required this.idx});
  @override
  Widget build(BuildContext ctx) {
    final isCurrent = ctx.watch<PlayerProvider>().currentSong == song;
    return GestureDetector(
      onTap: () => ctx.read<PlayerProvider>()
          .playSong(song, queue: all, index: idx),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          ArtworkWidget(
            key: ValueKey(song.hash), hash: song.image ?? song.hash,
            size: 48, borderRadius: BorderRadius.circular(4)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(song.title, style: TextStyle(
                color: isCurrent ? Sp.g2 : Sp.white,
                fontSize: 15, fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(song.artist,
                style: const TextStyle(color: Sp.white70, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
          if (isCurrent)
            const GIcon(Icons.equalizer_rounded, size: 20)
          else
            const Icon(Icons.more_horiz, color: Sp.white40, size: 20),
        ]),
      ),
    );
  }
}
