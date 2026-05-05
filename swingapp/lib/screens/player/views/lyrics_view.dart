import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/player_provider.dart';

class LyricsView extends StatefulWidget {
  final PlayerProvider player;
  final Color accent;
  final ScrollController? scrollController;
  
  const LyricsView({
    super.key,
    required this.player, 
    required this.accent,
    this.scrollController
  });

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final _internalScroll = ScrollController();
  int _line = 0;
  final Map<int, GlobalKey> _keys = {};

  ScrollController get _scroll =>
      widget.scrollController ?? _internalScroll;

  GlobalKey _keyFor(int i) {
    _keys[i] ??= GlobalKey();
    return _keys[i]!;
  }

  void _centerLine(int idx) {
    final key = _keys[idx];
    if (key == null) return;
    final ctx = key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final itemOffset = box.localToGlobal(Offset.zero).dy;
    final itemHeight = box.size.height;
    final scrollBox = _scroll.position.context.notificationContext
        ?.findRenderObject() as RenderBox?;
    final viewHeight = scrollBox?.size.height
        ?? MediaQuery.of(ctx).size.height;
    final currentScroll = _scroll.offset;

    final target = currentScroll + itemOffset - (viewHeight / 2) + (itemHeight / 2);

    _scroll.animateTo(
      target.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

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
    widget.player.addListener(_onPlayerUpdate);
  }

  @override
  void didUpdateWidget(LyricsView old) {
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
      return ListView.builder(
        controller: _scroll,
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
    if (widget.scrollController == null) _internalScroll.dispose();
    super.dispose();
  }
}
