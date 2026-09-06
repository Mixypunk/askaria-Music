part of '../player_screen.dart';

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
    final url = api.getThumbnailUrl(imageField);
    final cached = artCache.getSync(url);
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
    } catch (e) { debugPrint('player screen sheet error: $e'); }
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




  @override
  Widget build(BuildContext context) {
    // Selector sur hash ET couleur accent :
    // - rebuild si la chanson change
    // - rebuild si les couleurs dynamiques arrivent (après _fetchColors() async)
    return Selector<PlayerProvider, (String?, Color)>(
      selector: (_, p) => (p.currentSong?.hash, p.dynamicColors.accent),
      builder: (ctx, data, _) {
        final hash = data.$1;
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
          }
          // Toujours animer vers la couleur la plus récente
          // (au cas où _fetchColors() a fini après le dernier build)
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
                        _PlayerPage(
                          player: player,
                          song: song,
                          accent: accent,
                          onLyricsTap: _openLyricsSheet,
                        ),
                        // ── Page 1 : Paroles (seulement si dispo) ──────────
                        if (data.$1 || data.$2)
                          _LyricsPage(player: player, accent: accent),
                        // ── Page 2 : File d'attente ────────────────────────
                        _QueuePage(player: player, accent: accent),
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

