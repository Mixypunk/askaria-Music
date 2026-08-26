import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/song.dart';
import '../models/album.dart';
import '../services/api_service.dart';
import '../providers/player_provider.dart';
import '../providers/downloads_provider.dart';
import '../widgets/artwork_widget.dart';
import 'settings_screen.dart';
import 'artist_screen.dart';
import 'playlists_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with AutomaticKeepAliveClientMixin {
  List<Song>   _songs   = [];
  List<Album>  _albums  = [];
  List<Artist> _artists = [];
  bool _loading = true;
  bool _offline = false;

  String? _username;
  String? _avatarUrl;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final api  = SwingApiService();
    final prof = await api.getMyProfile();
    final uid  = prof['id'] as int?;
    if (uid != null && mounted) {
      setState(() {
        _username  = prof['username'] as String?;
        _avatarUrl = api.getAvatarUrl(uid);
      });
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _offline = false; });
    try {
      final results = await Future.wait([
        SwingApiService().getSongs(limit: 50),
        SwingApiService().getAlbums(limit: 20),
        SwingApiService().getArtists(limit: 20),
      ]).timeout(const Duration(seconds: 15));
      _songs   = results[0] as List<Song>;
      _albums  = results[1] as List<Album>;
      _artists = results[2] as List<Artist>;
    } catch (_) {
      _offline = _songs.isEmpty;
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
    super.build(context);
    return RefreshIndicator(
      color: Sp.g2,
      backgroundColor: Sp.card,
      displacement: 80,
      onRefresh: _load,
      child: CustomScrollView(slivers: [

        // ── App Bar ───────────────────────────────────────────────
        SliverAppBar(
          floating: true,
          snap: true,
          backgroundColor: Sp.bg,
          expandedHeight: 0,
          title: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_greeting(),
                style: const TextStyle(
                  fontSize: 13, color: Sp.white70,
                  fontWeight: FontWeight.w400)),
              const SizedBox(height: 1),
              if (_username != null)
                Text(_username!,
                  style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold,
                    color: Sp.white)),
            ]),
          ]),
          actions: [
            _AvatarButton(
              avatarUrl: _avatarUrl,
              username: _username ?? '',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
            const SizedBox(width: 12),
          ],
        ),

        if (_loading)
          const SliverFillRemaining(child: Center(
            child: CircularProgressIndicator(color: Sp.g2, strokeWidth: 2)))

        else if (_offline)
          _buildOfflineView(context)

        else ...[ // ── Contenu principal ──────────────────────────

          // Récemment joués
          Consumer<PlayerProvider>(builder: (ctx, player, _) {
            final recent = player.history;
            if (recent.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
            return SliverToBoxAdapter(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SectionHeader(
                  title: 'Récemment joués',
                  icon: Icons.history_rounded,
                ),
                SizedBox(
                  height: 70,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: recent.length.clamp(0, 8),
                    itemBuilder: (ctx, i) => _RecentTile(
                      song: recent[i], allSongs: recent, idx: i),
                  ),
                ),
              ]),
            );
          }),

          // Albums
          if (_albums.isNotEmpty) ...[ 
            _SectionHeader(
              title: 'Nouveaux albums',
              icon: Icons.album_rounded,
            ),
            SliverToBoxAdapter(child: SizedBox(
              height: 210,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _albums.length,
                itemBuilder: (ctx, i) => _AlbumCard(album: _albums[i]),
              ),
            )),
          ],

          // Artistes
          if (_artists.isNotEmpty) ...[
            _SectionHeader(
              title: 'Vos artistes',
              icon: Icons.people_rounded,
            ),
            SliverToBoxAdapter(child: SizedBox(
              height: 148,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _artists.length,
                itemBuilder: (ctx, i) => _ArtistCard(artist: _artists[i]),
              ),
            )),
          ],

          // Tous les titres
          if (_songs.isNotEmpty) ...[
            _SectionHeader(
              title: 'Tous les titres',
              icon: Icons.music_note_rounded,
              trailing: GestureDetector(
                onTap: () => _showAllSongs(context),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Voir tout (${_songs.length})',
                    style: const TextStyle(
                      color: Sp.white70, fontSize: 13)),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded,
                    color: Sp.white40, size: 18),
                ]),
              ),
            ),
            SliverList(delegate: SliverChildBuilderDelegate(
              (ctx, i) => _SongRow(song: _songs[i], all: _songs, idx: i, index: i),
              childCount: _songs.length.clamp(0, 10),
            )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: GestureDetector(
                onTap: () => _showAllSongs(context),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border.all(color: Sp.white12),
                    borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text('Voir tous les titres',
                    style: TextStyle(color: Sp.white70,
                        fontSize: 14, fontWeight: FontWeight.w500)))),
              ),
            )),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ]),
    );
  }

  void _showAllSongs(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _AllSongsScreen(songs: _songs)));
  }

  Widget _buildOfflineView(BuildContext context) {
    return Consumer<DownloadsProvider>(
      builder: (context, dlProvider, _) {
        final offlineSongs = dlProvider.downloadedSongs;
        final offlinePlaylists = dlProvider.downloadedPlaylists;

        if (offlineSongs.isEmpty && offlinePlaylists.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: Sp.card,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.wifi_off_rounded,
                        color: Sp.white40, size: 40),
                  ),
                  const SizedBox(height: 20),
                  const Text('Serveur inaccessible',
                    style: TextStyle(color: Sp.white, fontSize: 18,
                        fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 48),
                    child: Text('Aucune musique téléchargée pour le mode hors connexion.',
                      style: TextStyle(color: Sp.white70, fontSize: 14),
                      textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: _load,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: kGrad,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(
                          color: Sp.g2.withValues(alpha: 0.3),
                          blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: const Text('Réessayer',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold)))),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildListDelegate([
            // Banner hors connexion
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Sp.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Sp.white12),
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Sp.g2.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cloud_off_rounded, color: Sp.g2, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mode hors connexion',
                      style: TextStyle(color: Sp.white, fontSize: 14,
                          fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('Titres et playlists disponibles hors ligne.',
                      style: TextStyle(color: Sp.white70, fontSize: 12)),
                  ],
                )),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Sp.white70, size: 20),
                  onPressed: _load,
                ),
              ]),
            ),

            if (offlinePlaylists.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(children: const [
                  Icon(Icons.queue_music_rounded, color: Sp.white70, size: 16),
                  SizedBox(width: 8),
                  Text('Playlists hors connexion',
                    style: TextStyle(color: Sp.white, fontSize: 18,
                        fontWeight: FontWeight.bold)),
                ]),
              ),
              SizedBox(
                height: 168,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: offlinePlaylists.length,
                  itemBuilder: (ctx, i) {
                    final pl = offlinePlaylists[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => PlaylistDetailScreen(playlist: pl, readOnly: true))),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: SizedBox(
                          width: 120,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 120, height: 120,
                                decoration: BoxDecoration(
                                  color: Sp.card,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.queue_music_rounded,
                                    color: Sp.white40, size: 48),
                              ),
                              const SizedBox(height: 8),
                              Text(pl.name,
                                style: const TextStyle(color: Sp.white,
                                    fontSize: 13, fontWeight: FontWeight.w500),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('${pl.trackCount} titres',
                                style: const TextStyle(color: Sp.white70, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            if (offlineSongs.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(children: const [
                  Icon(Icons.download_done_rounded, color: Sp.white70, size: 16),
                  SizedBox(width: 8),
                  Text('Titres téléchargés',
                    style: TextStyle(color: Sp.white, fontSize: 18,
                        fontWeight: FontWeight.bold)),
                ]),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: offlineSongs.length,
                itemBuilder: (ctx, i) =>
                    _SongRow(song: offlineSongs[i], all: offlineSongs, idx: i, index: i),
              ),
            ],

            const SizedBox(height: 100),
          ]),
        );
      },
    );
  }
}

// ── Avatar button ──────────────────────────────────────────────────────────────
class _AvatarButton extends StatelessWidget {
  final String? avatarUrl;
  final String username;
  final VoidCallback onTap;
  const _AvatarButton({required this.avatarUrl, required this.username,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: const BoxDecoration(gradient: kGrad, shape: BoxShape.circle),
        padding: const EdgeInsets.all(2),
        child: ClipOval(
          child: SizedBox(
            width: 32, height: 32,
            child: avatarUrl != null
                ? NetImage(
                    url: avatarUrl!, width: 32, height: 32,
                    circular: false,
                    headers: SwingApiService().authHeaders,
                    placeholder: _InitialFallback(initial))
                : _InitialFallback(initial),
          ),
        ),
      ),
    );
  }
}

class _InitialFallback extends StatelessWidget {
  final String initial;
  const _InitialFallback(this.initial);
  @override
  Widget build(BuildContext context) => Container(
    color: Sp.card,
    child: initial.isEmpty
        ? const Icon(Icons.person_rounded, size: 18, color: Colors.white)
        : Center(child: Text(initial,
            style: const TextStyle(color: Colors.white,
                fontSize: 14, fontWeight: FontWeight.bold))),
  );
}

// ── Section header ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.icon, this.trailing});
  @override
  Widget build(BuildContext ctx) => SliverToBoxAdapter(child: Padding(
    padding: const EdgeInsets.fromLTRB(16, 28, 16, 14),
    child: Row(children: [
      if (icon != null) ...[
        Icon(icon, color: Sp.white70, size: 16),
        const SizedBox(width: 8),
      ],
      Expanded(child: Text(title, style: const TextStyle(
        color: Sp.white, fontSize: 20, fontWeight: FontWeight.bold))),
      if (trailing != null) trailing!,
    ]),
  ));
}

// ── Recent tile ────────────────────────────────────────────────────────────────
class _RecentTile extends StatelessWidget {
  final Song song; final List<Song> allSongs; final int idx;
  const _RecentTile({required this.song, required this.allSongs, required this.idx});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: () => ctx.read<PlayerProvider>()
        .playSong(song, queue: allSongs, index: idx),
    child: Container(
      width: 230,
      margin: const EdgeInsets.only(right: 10, bottom: 4),
      decoration: BoxDecoration(
        color: Sp.card, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        ClipRRect(
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
          child: ArtworkWidget(
            key: ValueKey(song.hash),
            hash: song.image ?? song.hash,
            size: 62,
            borderRadius: BorderRadius.zero),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(song.title,
          style: const TextStyle(color: Sp.white,
              fontSize: 13, fontWeight: FontWeight.w600),
          maxLines: 2, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
      ]),
    ),
  );
}

// ── Album card ─────────────────────────────────────────────────────────────────
class _AlbumCard extends StatelessWidget {
  final Album album;
  const _AlbumCard({required this.album});
  @override
  Widget build(BuildContext ctx) {
    final url = '${SwingApiService().baseUrl}/img/thumbnail/${album.image}';
    return GestureDetector(
      onTap: () => _openAlbum(ctx),
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: SizedBox(width: 148, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(children: [
                NetImage(url: url, width: 148, height: 148,
                  headers: SwingApiService().authHeaders,
                  borderRadius: BorderRadius.circular(14),
                  placeholder: Container(width: 148, height: 148, color: Sp.card,
                    child: const Icon(Icons.album, color: Sp.white40, size: 48))),
              ]),
            ),
            const SizedBox(height: 8),
            Text(album.title,
              style: const TextStyle(color: Sp.white,
                  fontSize: 13, fontWeight: FontWeight.w600),
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

// ── Artist card ────────────────────────────────────────────────────────────────
class _ArtistCard extends StatelessWidget {
  final Artist artist;
  const _ArtistCard({required this.artist});
  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();
    final url = '${api.baseUrl}/img/artist/small/${artist.image}';
    return GestureDetector(
      onTap: () => Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => ArtistScreen(artist: artist))),
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: SizedBox(width: 90, child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: kGrad,
              ),
              padding: const EdgeInsets.all(2),
              child: ClipOval(child: NetImage(
                url: url, width: 86, height: 86,
                headers: api.authHeaders,
                circular: true,
                placeholder: Container(width: 86, height: 86, color: Sp.card,
                  child: const Icon(Icons.person, color: Sp.white40, size: 40)),
              )),
            ),
            const SizedBox(height: 8),
            Text(artist.name,
              style: const TextStyle(color: Sp.white,
                  fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 2, overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
          ],
        )),
      ),
    );
  }
}

// ── Song row ───────────────────────────────────────────────────────────────────
class _SongRow extends StatelessWidget {
  final Song song; final List<Song> all; final int idx; final int index;
  const _SongRow({required this.song, required this.all,
      required this.idx, required this.index});
  @override
  Widget build(BuildContext ctx) {
    final isCurrent = ctx.select<PlayerProvider, bool>(
        (p) => p.currentSong?.hash == song.hash);
    return GestureDetector(
      onTap: () => ctx.read<PlayerProvider>()
          .playSong(song, queue: all, index: idx),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(children: [
          // Numéro de piste ou equalizer
          SizedBox(
            width: 24,
            child: isCurrent
                ? const GIcon(Icons.equalizer_rounded, size: 18)
                : Text('${index + 1}',
                    style: const TextStyle(color: Sp.white40, fontSize: 13),
                    textAlign: TextAlign.center),
          ),
          const SizedBox(width: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ArtworkWidget(
              key: ValueKey(song.hash), hash: song.image ?? song.hash,
              size: 50, borderRadius: BorderRadius.circular(8)),
          ),
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
          const Icon(Icons.more_horiz, color: Sp.white40, size: 20),
        ]),
      ),
    );
  }
}

// ── All songs screen ───────────────────────────────────────────────────────────
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
            _SongRow(song: songs[i], all: songs, idx: i, index: i),
      ),
    );
  }
}
