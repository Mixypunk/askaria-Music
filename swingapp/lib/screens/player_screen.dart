import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/player_provider.dart';
import '../widgets/artwork_widget.dart';
import '../main.dart';
import '../services/api_service.dart';
import 'player/views/player_view.dart';
import 'player/views/lyrics_view.dart';
import 'player/views/queue_view.dart';

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

  // Guard pour ne déclencher _loadBg/_animateTo qu'au vrai changement de chanson
  String? _lastSongHash;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _colorAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Lire une seule fois — pas de rebuild déclenché par ce read
    final player = context.read<PlayerProvider>();
    final song = player.currentSong;
    if (song == null) return;
    final hash = song.image ?? song.hash;
    // Ne déclencher que si la chanson a vraiment changé
    if (hash == _lastSongHash) return;
    _lastSongHash = hash;
    _loadBg(hash);
    _animateTo(player.dynamicColors.accent);
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
    // Réutiliser le cache artCache (déjà téléchargé par ArtworkWidget ou _fetchColors)
    final api = SwingApiService();
    final url = '${api.baseUrl}/img/thumbnail/$imageField';
    final cached = artCache.get(url);
    if (cached != null) {
      if (mounted) setState(() => _bgImage = cached);
      return;
    }
    // Fallback : télécharger seulement si pas en cache
    try {
      final r = await http.get(
        Uri.parse(url),
        headers: api.authHeaders,
      ).timeout(const Duration(seconds: 6));
      if (r.statusCode == 200 && mounted) {
        artCache.put(url, r.bodyBytes);
        setState(() => _bgImage = r.bodyBytes);
      }
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
    // Selector minimal : ne rebuild que si la chanson change (hash)
    // Les sous-widgets dynamiques (position, isPlaying) ont leurs propres Selectors
    return Selector<PlayerProvider, String?>(
      selector: (_, p) => p.currentSong?.hash,
      builder: (ctx, hash, _) {
        if (hash == null) return const Scaffold(
          backgroundColor: Sp.bg,
          body: Center(child: Text('Aucune musique',
              style: TextStyle(color: Colors.white))));

        // Lecture non-réactive (ne déclenche pas de rebuild)
        final player = context.read<PlayerProvider>();
        final song = player.currentSong!;
        final dc = player.dynamicColors;

        // Déclencher _loadBg/_animateTo si la chanson vient de changer
        // (didChangeDependencies ne suffit pas si le provider notifie après build)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final newHash = song.image ?? song.hash;
          if (newHash != _lastSongHash) {
            _lastSongHash = newHash;
            _loadBg(newHash);
            _animateTo(dc.accent);
          }
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
                    if ((d.primaryVelocity ?? 0) > 400) {
                      Navigator.of(context).pop();
                    }
                  },
                  onHorizontalDragEnd: (d) {
                    if (_page != 0) return;
                    final v = d.primaryVelocity ?? 0;
                    final p = context.read<PlayerProvider>();
                    if (v < -600) p.next();
                    else if (v > 600) p.previous();
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
                        // Selector ciblé sur page + hasLyrics + lyricsLoading
                        Selector<PlayerProvider, (bool, bool)>(
                          selector: (_, p) => (p.hasLyrics, p.lyricsLoading),
                          builder: (_, data, __) {
                            final hasL = data.$1;
                            final loadL = data.$2;
                            return Column(children: [
                              Text(
                                _page == 0 ? 'EN LECTURE'
                                : (hasL || loadL) && _page == 1
                                    ? 'PAROLES'
                                    : 'FILE D\'ATTENTE',
                                style: const TextStyle(color: Colors.white70, fontSize: 10,
                                    letterSpacing: 1.5, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(song.album, style: const TextStyle(
                                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            ]);
                          },
                        ),
                      ])),
                      // Indicateur de page
                      Selector<PlayerProvider, (bool, bool)>(
                        selector: (_, p) => (p.hasLyrics, p.lyricsLoading),
                        builder: (_, data, __) => _PageDots(
                          current: _page,
                          accent: accent,
                          count: (data.$1 || data.$2) ? 3 : 2),
                      ),
                    ]),
                  ),

                  // PageView dynamique
                  Expanded(child: Selector<PlayerProvider, (bool, bool)>(
                    selector: (_, p) => (p.hasLyrics, p.lyricsLoading),
                    builder: (_, data, __) => PageView(
                      controller: _pageController,
                      onPageChanged: (p) => setState(() => _page = p),
                      children: [
                        // ── Page 0 : Player ────────────────────────────────
                        PlayerView(
                          player: player,
                          song: song,
                          accent: accent,
                          onLyricsTap: _openLyricsSheet,
                        ),
                        // ── Page 1 : Paroles (seulement si dispo) ──────────
                        if (data.$1 || data.$2)
                          LyricsView(player: player, accent: accent),
                        // ── Page 2 : File d'attente ────────────────────────
                        QueueView(player: player, accent: accent),
                      ],
                    ),
                  )),
                ])),     // Column + SafeArea
                ),        // GestureDetector
              ]),         // Stack children
            );            // Scaffold
          },              // AnimatedBuilder builder
        );                // AnimatedBuilder
      },                  // Selector builder
    );                    // Selector
  }                       // build()
}                         // class

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
              builder: (ctx, p, _) => LyricsView(player: p, accent: accent)),
          )),
        ]),
      ),
    );
  }
}
