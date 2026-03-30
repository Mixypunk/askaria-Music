import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../widgets/artwork_widget.dart';
import '../widgets/waveform_seekbar.dart';
import '../main.dart';
import '../services/api_service.dart';
import 'downloads_screen.dart';
import '../models/album.dart';
import 'artist_screen.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {

  // PageView controller — swipe horizontal entre Player / Paroles / Queue
  late PageController _pageController;
  int _page = 0;

  // Animation couleur
  late AnimationController _colorAnim;
  Color _prevAccent = const Color(0xFF4776E6);
  Color _currAccent = const Color(0xFF4776E6);

  // Fond flouté
  Uint8List? _bgImage;
  String? _bgHash;


  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _colorAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _colorAnim.dispose();
    super.dispose();
  }

  Future<void> _loadBg(String imageField) async {
    if (_bgHash == imageField) return;
    _bgHash = imageField;
    try {
      final api = SwingApiService();
      final r = await http.get(
        Uri.parse('${api.baseUrl}/img/thumbnail/$imageField'),
        headers: api.authHeaders,
      ).timeout(const Duration(seconds: 6));
      if (r.statusCode == 200 && mounted) setState(() => _bgImage = r.bodyBytes);
    } catch (_) {}
  }

  void _animateTo(Color newAccent) {
    if (newAccent == _currAccent) return;
    _prevAccent = _currAccent;
    _currAccent = newAccent;
    _colorAnim.forward(from: 0);
  }

  void _openLyricsSheet() {
    final player = context.read<PlayerProvider>();
    final song   = player.currentSong;
    if (song == null) return;
    Navigator.push(context, PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black54,
      pageBuilder: (_, a, __) => _LyricsOverlay(
        player: player,
        song: song,
        accent: player.dynamicColors.accent,
      ),
      transitionsBuilder: (_, a, __, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ));
  }

  void _closeLyricsSheet() => Navigator.maybePop(context);

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(builder: (ctx, player, _) {
      final song = player.currentSong;
      if (song == null) return const Scaffold(
        backgroundColor: Sp.bg,
        body: Center(child: Text('Aucune musique',
            style: TextStyle(color: Colors.white))));

      final dc = player.dynamicColors;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadBg(song.image ?? song.hash);
        _animateTo(dc.accent);
      });

      return AnimatedBuilder(
        animation: _colorAnim,
        builder: (ctx, _) {
          final t = CurvedAnimation(parent: _colorAnim, curve: Curves.easeOut).value;
          final accent = Color.lerp(_prevAccent, _currAccent, t) ?? _currAccent;
          final dark = Color.lerp(
            HSLColor.fromColor(_prevAccent).withLightness(0.15).toColor(),
            dc.accentDark, t) ?? dc.accentDark;

          return Scaffold(
            backgroundColor: Sp.bg,
            body: Stack(children: [
              // ── Fond flouté ─────────────────────────────────────────
              if (_bgImage != null)
                Positioned.fill(child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Image.memory(_bgImage!, fit: BoxFit.cover,
                    color: Colors.black.withOpacity(0.58),
                    colorBlendMode: BlendMode.darken)))
              else
                Positioned.fill(child: Container(
                  decoration: BoxDecoration(gradient: LinearGradient(
                    colors: [dark, Sp.bg], begin: Alignment.topCenter,
                    end: Alignment.bottomCenter, stops: const [0.0, 0.65])))),
              Positioned.fill(child: Container(
                decoration: BoxDecoration(gradient: LinearGradient(
                  colors: [dark.withOpacity(0.5), Colors.transparent, Sp.bg.withOpacity(0.65)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4, 1.0])))),

              // ── Contenu principal ────────────────────────────────────
              GestureDetector(
                onVerticalDragEnd: (d) {
                  // Swipe bas rapide = fermer le player
                  if ((d.primaryVelocity ?? 0) > 400) {
                    Navigator.of(context).pop();
                  }
                },
                child: SafeArea(child: Column(children: [

                // Top bar : flèche bas + titre album + indicateurs de page
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 32, color: Colors.white),
                    ),
                    Expanded(child: Column(children: [
                      Text(
                        _page == 0 ? 'EN LECTURE'
                        : (player.hasLyrics || player.lyricsLoading) && _page == 1
                            ? 'PAROLES'
                            : 'FILE D\'ATTENTE',
                        style: const TextStyle(color: Colors.white70, fontSize: 10,
                            letterSpacing: 1.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(song.album, style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ])),
                    // Indicateur de page (3 petits points)
                    _PageDots(
                      current: _page,
                      accent: accent,
                      count: (player.hasLyrics || player.lyricsLoading) ? 3 : 2),
                  ]),
                ),

                // PageView dynamique : Paroles masquée si absentes
                Expanded(child: PageView(
                  controller: _pageController,
                  onPageChanged: (p) => setState(() => _page = p),
                  children: [
                    // ── Page 0 : Player ────────────────────────────────
                    _PlayerPage(
                      player: player,
                      song: song,
                      accent: accent,
                      onLyricsTap: _openLyricsSheet,
                    ),
                    // ── Page 1 : Paroles (seulement si dispo) ──────────
                    if (player.hasLyrics || player.lyricsLoading)
                      _LyricsPage(player: player, accent: accent),
                    // ── Page 2 : File d'attente ────────────────────────
                    _QueuePage(player: player, accent: accent),
                  ],
                )),
              ]),     // Column children
              ),      // SafeArea(child: Column)
              ),      // GestureDetector(child: SafeArea)
            ]),       // Stack children
          );          // Scaffold
        },            // AnimatedBuilder builder
      );              // AnimatedBuilder
    });               // Consumer
  }                   // build()
}                     // class

// ── Indicateur de page (3 points) ─────────────────────────────────────────────
class _PageDots extends StatelessWidget {
  final int current;
  final Color accent;
  final int count; // 2 si pas de paroles, 3 sinon
  const _PageDots({required this.current, required this.accent,
      this.count = 3});
  @override
  Widget build(BuildContext ctx) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(count, (i) => AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: i == current ? 16 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: i == current ? accent : Colors.white24,
        borderRadius: BorderRadius.circular(3)),
    )),
  );
}

// ── Page Player ────────────────────────────────────────────────────────────────
class _PlayerPage extends StatelessWidget {
  final PlayerProvider player;
  final song;
  final Color accent;
  final VoidCallback onLyricsTap;
  const _PlayerPage({
    required this.player, required this.song,
    required this.accent, required this.onLyricsTap});

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  String _fmtRemaining(Duration? d) {
    if (d == null) return '';
    if (d.inHours > 0) return '${d.inHours}h${d.inMinutes.remainder(60)}min';
    return '${d.inMinutes}min';
  }

  Future<void> _showAddToPlaylist(BuildContext ctx, song) async {
    // Utiliser le cache du provider
    final player = ctx.read<PlayerProvider>();
    final playlists = await player.getCachedPlaylists();
    if (!ctx.mounted) return;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF282828),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              Container(width: 36, height: 4, margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
              const Text('Ajouter à une playlist',
                style: TextStyle(color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.bold)),
            ])),
          const Divider(color: Colors.white12, height: 1),
          if (playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Aucune playlist disponible',
                style: TextStyle(color: Colors.white54)))
          else
            SizedBox(
              height: playlists.length > 4 ? 250 : null,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (_, i) {
                  final pl = playlists[i];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: NetImage(
                        url: '${SwingApiService().baseUrl}/img/playlist/${pl.id}.webp',
                        width: 44, height: 44,
                        headers: SwingApiService().authHeaders,
                        borderRadius: BorderRadius.circular(4),
                        placeholder: Container(width: 44, height: 44,
                          color: Sp.card, child: const Icon(
                              Icons.queue_music_rounded,
                              color: Colors.white38, size: 20)))),
                    title: Text(pl.name,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${pl.trackCount} titre${pl.trackCount != 1 ? "s" : ""}',
                      style: const TextStyle(color: Colors.white54,
                          fontSize: 12)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final ok = await SwingApiService()
                          .addTracksToPlaylist(pl.id, [song.hash]);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(ok
                            ? 'Ajouté à « ${pl.name} »'
                            : 'Erreur lors de l\'ajout'),
                          behavior: SnackBarBehavior.floating));
                      }
                    });
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _downloadSong(BuildContext ctx, dynamic song) async {
    final api = SwingApiService();
    final messenger = ScaffoldMessenger.of(ctx);
    messenger.showSnackBar(SnackBar(
      content: Text('Téléchargement de \${song.title}…'),
      duration: const Duration(seconds: 60),
      behavior: SnackBarBehavior.floating));
    final path = await api.downloadTrack(song);
    messenger.hideCurrentSnackBar();
    if (path != null) {
      messenger.showSnackBar(SnackBar(
        content: Text('\${song.title} téléchargé !'),
        backgroundColor: Sp.card,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Voir',
          textColor: Sp.g2,
          onPressed: () => Navigator.push(ctx,
              MaterialPageRoute(builder: (_) => const DownloadsScreen())))));
    } else {
      messenger.showSnackBar(const SnackBar(
        content: Text('Échec du téléchargement'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating));
    }
  }

  void _showSleepTimer(BuildContext ctx, PlayerProvider player) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF282828),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          const Row(children: [
            Icon(Icons.bedtime_rounded, color: Colors.blueAccent, size: 22),
            SizedBox(width: 10),
            Text('Timer de sommeil', style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 20),
          // Options de durée
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final min in [15, 30, 45, 60, 90])
              GestureDetector(
                onTap: () { player.setSleepTimer(min); Navigator.pop(ctx); },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A3A),
                    borderRadius: BorderRadius.circular(24)),
                  child: Text('${min}min',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)))),
          ]),
          if (player.hasSleepTimer) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () { player.cancelSleepTimer(); Navigator.pop(ctx); },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.redAccent.withOpacity(0.6)),
                  borderRadius: BorderRadius.circular(8)),
                child: const Center(child: Text('Annuler le timer',
                  style: TextStyle(color: Colors.redAccent,
                      fontWeight: FontWeight.bold))))),
          ],
        ]),
      ),
    );
  }

  void _showShareSheet(BuildContext ctx, song, Color accent) {
    final api   = SwingApiService();
    final url   = api.getStreamUrl(song.hash, filepath: song.filepath);
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF282828),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          Text(song.title, style: const TextStyle(color: Colors.white,
              fontSize: 16, fontWeight: FontWeight.bold)),
          Text(song.artist,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
          const SizedBox(height: 8),
          // URL de stream (copiable)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(6)),
            child: Text(url,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              maxLines: 2, overflow: TextOverflow.ellipsis)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _ShareBtn(Icons.copy_rounded, 'Copier le lien', () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                content: const Text('Lien copié dans le presse-papier !'),
                backgroundColor: accent,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2)));
            }),
            _ShareBtn(Icons.share_rounded, 'Partager', () {
              Navigator.pop(ctx);
              Share.share(
                '\${song.title} — \${song.artist}\n\$url',
                subject: song.title,
              );
            }),
            _ShareBtn(Icons.info_outline_rounded, 'Infos', () {
              Navigator.pop(ctx);
              showDialog(context: ctx, builder: (_) => AlertDialog(
                backgroundColor: const Color(0xFF282828),
                title: Text(song.title,
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
                content: Column(mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _InfoRow('Artiste', song.artist),
                  _InfoRow('Album',   song.album),
                  _InfoRow('Durée',
                    '${song.duration ~/ 60}:${(song.duration % 60).toString().padLeft(2,"0")}'),
                ]),
                actions: [TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Fermer', style: TextStyle(color: accent)))],
              ));
            }),
          ]),
        ]),
      ),
    );
  }

  void _showDevicesSheet(BuildContext ctx, Color accent) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF282828),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          const Text('Lecture sur', style: TextStyle(color: Colors.white,
              fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(contentPadding: EdgeInsets.zero,
            leading: Container(width: 44, height: 44,
              decoration: BoxDecoration(color: accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.phone_android_rounded, color: accent, size: 24)),
            title: const Text('Cet appareil',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text('Connecté', style: TextStyle(color: accent, fontSize: 12)),
            trailing: Icon(Icons.check_circle_rounded, color: accent, size: 20)),
        ]),
      ),
    );
  }

  void _showMoreSheet(BuildContext ctx, PlayerProvider player, song, Color accent) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF282828),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.download_rounded, color: Colors.white70),
            title: const Text('Télécharger',
                style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(ctx); _downloadSong(ctx, song); }),
          ListTile(
            leading: const Icon(Icons.queue_music_rounded, color: Colors.white70),
            title: const Text('Ajouter à la file',
                style: TextStyle(color: Colors.white)),
            onTap: () { player.addNextInQueue(song); Navigator.pop(ctx); }),
          ListTile(
            leading: Icon(
              player.isFavourite(song.hash)
                  ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: player.isFavourite(song.hash) ? accent : Colors.white70),
            title: Text(
              player.isFavourite(song.hash)
                  ? 'Retirer des favoris' : 'Ajouter aux favoris',
              style: const TextStyle(color: Colors.white)),
            onTap: () { player.toggleFavourite(song.hash); Navigator.pop(ctx); }),
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded,
                color: Colors.white70),
            title: const Text('Ajouter à une playlist',
              style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(ctx);
              _showAddToPlaylist(ctx, song);
            }),
          ListTile(
            leading: Icon(Icons.bedtime_rounded,
              color: player.hasSleepTimer ? Colors.blueAccent : Colors.white70),
            title: Text(
              player.hasSleepTimer
                ? 'Timer sommeil : ${_fmtRemaining(player.sleepRemaining)}'
                : 'Timer de sommeil',
              style: TextStyle(
                color: player.hasSleepTimer ? Colors.blueAccent : Colors.white)),
            onTap: () {
              Navigator.pop(ctx);
              _showSleepTimer(ctx, player);
            }),
          ListTile(
            leading: const Icon(Icons.album_rounded, color: Colors.white70),
            title: const Text("Aller à l'album",
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(ctx); // fermer le sheet
              // Fermer le player et naviguer vers l'album
              final album = Album(
                hash: song.albumHash,
                title: song.album,
                artist: song.artist,
                artistHash: song.artistHash,
                image: song.image ?? '',
              );
              Navigator.of(ctx).push(MaterialPageRoute(
                builder: (_) => AlbumScreen(album: album)));
            }),
          ListTile(
            leading: const Icon(Icons.person_rounded, color: Colors.white70),
            title: const Text("Aller à l'artiste",
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(ctx);
              final artist = Artist(
                hash: song.artistHash,
                name: song.artist,
                image: '${song.artistHash}.webp',
              );
              Navigator.of(ctx).push(MaterialPageRoute(
                builder: (_) => ArtistScreen(artist: artist)));
            }),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        const SizedBox(height: 8),

        // Artwork avec halo + swipe up → paroles
        Expanded(flex: 5, child: GestureDetector(
          onVerticalDragEnd: (d) {
            if (d.primaryVelocity != null && d.primaryVelocity! < -300) {
              onLyricsTap();
            }
          },
          child: Center(child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(
                color: accent.withOpacity(0.4), blurRadius: 50,
                offset: const Offset(0, 16), spreadRadius: 4)],
            ),
            child: AspectRatio(aspectRatio: 1, child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ArtworkWidget(
                key: ValueKey(song.hash),
                hash: song.image ?? song.hash,
                size: double.infinity,
                borderRadius: BorderRadius.circular(8)),
            )),
          )),
        )),
        const SizedBox(height: 6),

        // Hint "Voir les paroles" — visible seulement si paroles disponibles
        if (player.hasLyrics)
          GestureDetector(
            onTap: onLyricsTap,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.lyrics_rounded, size: 14, color: accent.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text('Voir les paroles', style: TextStyle(
                  color: accent.withOpacity(0.7), fontSize: 12)),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_up_rounded, size: 14,
                  color: accent.withOpacity(0.7)),
            ]),
          )
        else
          const SizedBox(height: 2),
        const SizedBox(height: 14),

        // Titre + like
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(song.title, style: const TextStyle(
                color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.bold, letterSpacing: -0.3),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
              // Badge lossless
              if (song.isLossless) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: accent.withOpacity(0.8), width: 1),
                    borderRadius: BorderRadius.circular(4)),
                  child: Text(song.audioFormat,
                    style: TextStyle(
                      color: accent, fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
                ),
              ],
            ]),
            const SizedBox(height: 4),
            Text(song.artist, style: TextStyle(
              color: Colors.white.withOpacity(0.7), fontSize: 15),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => player.toggleFavourite(song.hash),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                player.isFavourite(song.hash)
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                key: ValueKey(player.isFavourite(song.hash)),
                color: player.isFavourite(song.hash) ? accent : Colors.white70,
                size: 28,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 20),

        // Progress bar dynamique
        _ProgressBar(player: player, accent: accent),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_fmt(player.position),
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
          Text(_fmt(player.duration),
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
        ]),
        const SizedBox(height: 20),

        // Contrôles
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center, children: [
          GestureDetector(
            onTap: player.toggleShuffle,
            child: Stack(alignment: Alignment.bottomCenter, children: [
              Icon(Icons.shuffle_rounded, size: 26,
                color: player.shuffle ? accent : Colors.white.withOpacity(0.6)),
              if (player.shuffle) Positioned(bottom: -4,
                child: Container(width: 4, height: 4,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle))),
            ]),
          ),
          GestureDetector(
            onTap: player.previous,
            child: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 46)),
          GestureDetector(
            onTap: player.playPause,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 68, height: 68,
              decoration: BoxDecoration(
                color: accent, shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: accent.withOpacity(0.5), blurRadius: 22, spreadRadius: 2)]),
              child: Center(child: player.isLoading
                  ? const SizedBox(width: 26, height: 26,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Icon(player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white, size: 42)),
            ),
          ),
          GestureDetector(
            onTap: player.next,
            child: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 46)),
          GestureDetector(
            onTap: player.toggleRepeat,
            child: Stack(alignment: Alignment.bottomCenter, children: [
              Icon(
                player.repeatMode == RepeatMode.one
                    ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                size: 26,
                color: player.repeatMode != RepeatMode.off
                    ? accent : Colors.white.withOpacity(0.6)),
              if (player.repeatMode != RepeatMode.off) Positioned(bottom: -4,
                child: Container(width: 4, height: 4,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle))),
            ]),
          ),
        ]),
        const SizedBox(height: 20),

        // ── Slider volume ─────────────────────────────────────────
        Row(children: [
          Icon(
            player.volume == 0
                ? Icons.volume_off_rounded
                : player.volume < 0.5
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded,
            size: 18, color: Colors.white38),
          Expanded(child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: accent,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: accent.withOpacity(0.2)),
            child: Slider(
              value: player.volume,
              onChanged: (v) => player.setVolume(v)),
          )),
          Icon(Icons.volume_up_rounded, size: 18, color: Colors.white38),
        ]),
        const SizedBox(height: 6),

        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          GestureDetector(
            onTap: () => _showDevicesSheet(ctx, accent),
            child: Icon(Icons.devices_rounded, size: 20,
                color: Colors.white.withOpacity(0.6))),
          Row(children: [
            GestureDetector(
              onTap: () => _showShareSheet(ctx, song, accent),
              child: Icon(Icons.share_rounded, size: 20,
                  color: Colors.white.withOpacity(0.6))),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: () => _showMoreSheet(ctx, player, song, accent),
              child: Icon(Icons.more_horiz_rounded, size: 24,
                  color: Colors.white.withOpacity(0.6))),
          ]),
        ]),
        const SizedBox(height: 12),
      ]),
    );
  }
}

// ── Progress bar avec waveform ───────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final PlayerProvider player;
  final Color accent;
  const _ProgressBar({required this.player, required this.accent});

  @override
  Widget build(BuildContext ctx) {
    if (player.currentSong == null) return const SizedBox.shrink();
    return WaveformSeekbar(
      songHash: player.currentSong!.hash,
      progress: player.progress.clamp(0.0, 1.0),
      position: player.position,
      duration: player.duration,
      onSeek: (v) => player.seek(
          Duration(milliseconds: (v * player.duration.inMilliseconds).round())),
    );
  }
}

// ── Page Paroles ───────────────────────────────────────────────────────────────
class _LyricsPage extends StatefulWidget {
  final PlayerProvider player;
  final Color accent;
  final ScrollController? scrollController;
  const _LyricsPage({required this.player, required this.accent,
      this.scrollController});
  @override
  State<_LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends State<_LyricsPage> {
  final _internalScroll = ScrollController();
  int _line = 0;
  // Une clé par ligne pour mesurer la position réelle dans la liste
  final Map<int, GlobalKey> _keys = {};

  ScrollController get _scroll =>
      widget.scrollController ?? _internalScroll;

  GlobalKey _keyFor(int i) {
    _keys[i] ??= GlobalKey();
    return _keys[i]!;
  }

  /// Scrolle pour que la ligne active soit centrée verticalement dans la vue
  void _centerLine(int idx) {
    final key = _keys[idx];
    if (key == null) return;
    final ctx = key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    // Position absolue de la ligne dans le scroll
    final itemOffset = box.localToGlobal(Offset.zero).dy;
    final itemHeight = box.size.height;

    // Hauteur visible de la zone de scroll
    final scrollBox = _scroll.position.context.notificationContext
        ?.findRenderObject() as RenderBox?;
    final viewHeight = scrollBox?.size.height
        ?? MediaQuery.of(ctx).size.height;

    // Décalage actuel du scroll
    final currentScroll = _scroll.offset;

    // On veut que le centre de l'item soit au centre de la vue
    final target = currentScroll + itemOffset - (viewHeight / 2) + (itemHeight / 2);

    _scroll.animateTo(
      target.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _sync() {
    final lines = widget.player.syncedLines;
    if (lines == null || lines.isEmpty) return;
    final pos = widget.player.position.inMilliseconds;
    int idx = 0;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i]['time'] <= pos) idx = i;
    }
    if (idx != _line) {
      setState(() => _line = idx);
      // Centrer après le rebuild
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerLine(idx));
    }
  }

  @override
  Widget build(BuildContext ctx) {
    final p = widget.player;
    final accent = widget.accent;

    if (p.lyricsLoading) return Center(
      child: CircularProgressIndicator(color: accent, strokeWidth: 2));

    if (p.lyricsSynced && p.syncedLines != null && p.syncedLines!.isNotEmpty) {
      _sync();
      return ListView.builder(
        controller: _scroll,
        // Padding haut/bas = moitié écran pour que la 1ère et dernière ligne
        // puissent aussi être centrées
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 300),
        itemCount: p.syncedLines!.length,
        itemBuilder: (ctx, i) {
          final active = i == _line;
          final text = p.syncedLines![i]['text'] as String;
          if (text.trim().isEmpty) return const SizedBox(height: 20);
          return Padding(
            key: _keyFor(i),
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 350),
              style: active
                  ? TextStyle(color: accent, fontSize: 26,
                      fontWeight: FontWeight.bold, height: 1.4)
                  : TextStyle(color: Colors.white.withOpacity(0.22),
                      fontSize: 18, height: 1.4, fontWeight: FontWeight.w600),
              child: Text(text, textAlign: TextAlign.left),
            ),
          );
        },
      );
    }
    if (p.unsyncedLines != null && p.unsyncedLines!.isNotEmpty) {
      return SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(28, 60, 28, 28),
        child: Text(p.unsyncedLines!.join('\n'),
          style: const TextStyle(color: Colors.white70, fontSize: 16, height: 2.0),
          textAlign: TextAlign.left));
    }
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.lyrics_outlined, color: accent.withOpacity(0.4), size: 56),
      const SizedBox(height: 16),
      const Text('Aucune parole disponible',
          style: TextStyle(color: Colors.white54)),
    ]));
  }

  @override
  void dispose() {
    if (widget.scrollController == null) _internalScroll.dispose();
    super.dispose();
  }
}

// ── Share button helper ───────────────────────────────────────────────────────
class _ShareBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ShareBtn(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 56, height: 56,
        decoration: BoxDecoration(color: Colors.white12, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 26)),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 60, child: Text(label,
        style: const TextStyle(color: Colors.white54, fontSize: 13))),
      Expanded(child: Text(value,
        style: const TextStyle(color: Colors.white, fontSize: 13))),
    ]),
  );
}

// ── Page File d'attente ────────────────────────────────────────────────────────
class _QueuePage extends StatelessWidget {
  final PlayerProvider player;
  final Color accent;
  const _QueuePage({required this.player, required this.accent});
  @override
  Widget build(BuildContext ctx) {
    final q = player.queue;
    if (q.isEmpty) return const Center(
      child: Text('File vide', style: TextStyle(color: Colors.white54)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text("File d'attente", style: TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
      Expanded(child: ReorderableListView.builder(
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: q.length,
        onReorder: player.reorderQueue,
        proxyDecorator: (c, _, __) => Material(color: Colors.transparent, child: c),
        itemBuilder: (ctx, i) {
          final s = q[i];
          final cur = i == player.currentIndex;
          return ListTile(
            key: ValueKey('${s.hash}$i'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            leading: ClipRRect(borderRadius: BorderRadius.circular(4),
              child: ArtworkWidget(key: ValueKey(s.hash), hash: s.image ?? s.hash,
                size: 44, borderRadius: BorderRadius.circular(4))),
            title: Text(s.title, style: TextStyle(
              color: cur ? accent : Colors.white,
              fontWeight: cur ? FontWeight.bold : FontWeight.w500, fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(s.artist,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: cur
                ? Icon(Icons.equalizer_rounded, size: 20, color: accent)
                : IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded,
                        size: 18, color: Colors.white38),
                    onPressed: () => player.removeFromQueue(i)),
            onTap: () => player.playSong(s, queue: q, index: i),
          );
        },
      )),
    ]);
  }
}

// ── Overlay paroles ─────────────────────────────────────────────────────────────
class _LyricsOverlay extends StatelessWidget {
  final PlayerProvider player;
  final song;
  final Color accent;
  const _LyricsOverlay({required this.player, required this.song, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          color: HSLColor.fromColor(accent).withLightness(0.10).toColor()
              .withOpacity(0.97),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        margin: const EdgeInsets.only(top: 60),
        child: Column(children: [
          // Handle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: ArtworkWidget(
                  key: ValueKey(song.hash),
                  hash: song.image ?? song.hash,
                  size: 40, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title, style: const TextStyle(
                    color: Colors.white, fontSize: 14,
                    fontWeight: FontWeight.bold),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(song.artist, style: TextStyle(
                    color: Colors.white.withOpacity(0.6), fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32, height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.white12, shape: BoxShape.circle),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white, size: 22))),
            ]),
          ),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
          // Paroles
          Expanded(child: ChangeNotifierProvider.value(
            value: player,
            child: Consumer<PlayerProvider>(
              builder: (ctx, p, _) => _LyricsPage(player: p, accent: accent)),
          )),
        ]),
      ),
    );
  }
}
