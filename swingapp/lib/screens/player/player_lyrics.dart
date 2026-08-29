part of '../player_screen.dart';

class _LyricsPage extends StatefulWidget {
  final PlayerProvider player;
  final Color accent;
  const _LyricsPage({required this.player, required this.accent});
  @override
  State<_LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends State<_LyricsPage> {
  final _scroll = ScrollController();
  int _line = 0;
  // Une clé par ligne pour mesurer la position réelle dans la liste
  final Map<int, GlobalKey> _keys = {};

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

  /// Calcule la ligne active — appelé uniquement par le listener, PAS dans build().
  void _sync() {
    if (!mounted) return;
    final lines = widget.player.syncedLines;
    if (lines == null || lines.isEmpty) return;
    final pos = widget.player.position.inMilliseconds;
    int idx = 0;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i]['time'] <= pos) idx = i;
    }
    if (idx != _line) {
      setState(() => _line = idx);
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerLine(idx));
    }
  }

  void _onPlayerUpdate() => _sync();

  @override
  void initState() {
    super.initState();
    // Listener — déclenché par le provider (déjà throttled à 500ms dans positionStream)
    widget.player.addListener(_onPlayerUpdate);
  }

  @override
  void didUpdateWidget(_LyricsPage old) {
    super.didUpdateWidget(old);
    if (old.player != widget.player) {
      old.player.removeListener(_onPlayerUpdate);
      widget.player.addListener(_onPlayerUpdate);
    }
    if (old.player.currentSong?.hash != widget.player.currentSong?.hash) {
      _line = 0;
    }
  }

  @override
  Widget build(BuildContext ctx) {
    final p = widget.player;
    final accent = widget.accent;

    if (p.lyricsLoading) return Center(
      child: CircularProgressIndicator(color: accent, strokeWidth: 2));

    if (p.lyricsSynced && p.syncedLines != null && p.syncedLines!.isNotEmpty) {
      // _sync() N'EST PLUS appelé ici — listener dans initState gère ça
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
                  : TextStyle(color: Colors.white.withValues(alpha: 0.22),
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
      Icon(Icons.lyrics_outlined, color: accent.withValues(alpha: 0.4), size: 56),
      const SizedBox(height: 16),
      const Text('Aucune parole disponible',
          style: TextStyle(color: Colors.white54)),
    ]));
  }

  @override
  void dispose() {
    widget.player.removeListener(_onPlayerUpdate);
    _scroll.dispose();
    super.dispose();
  }
}

// ── Share button helper ───────────────────────────────────────────────────────
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
              .withValues(alpha: 0.97),
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
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
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
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
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
