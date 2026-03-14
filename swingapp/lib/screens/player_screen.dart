import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../widgets/artwork_widget.dart';
import '../main.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  int _tab = 0; // 0=player 1=lyrics 2=queue
  Uint8List? _bgImage;
  String? _bgHash;

  Future<void> _loadBg(String hash, String imageField) async {
    if (_bgHash == imageField) return;
    _bgHash = imageField;
    try {
      final api = SwingApiService();
      final url = '${api.baseUrl}/img/thumbnail/$imageField';
      final r = await http.get(Uri.parse(url), headers: api.authHeaders)
          .timeout(const Duration(seconds: 6));
      if (r.statusCode == 200 && mounted) {
        setState(() => _bgImage = r.bodyBytes);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(builder: (ctx, player, _) {
      final song = player.currentSong;
      if (song == null) return const Scaffold(
        backgroundColor: Sp.bg,
        body: Center(child: Text('Aucune musique', style: TextStyle(color: Colors.white))));

      // Load background image when song changes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadBg(song.hash, song.image ?? song.hash);
      });

      return Scaffold(
        backgroundColor: Sp.bg,
        body: Stack(children: [
          // ── Fond flouté (artwork en bg comme Spotify) ──────────────
          if (_bgImage != null)
            Positioned.fill(child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Image.memory(_bgImage!, fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.55),
                colorBlendMode: BlendMode.darken),
            ))
          else
            Positioned.fill(child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Sp.g1.withOpacity(0.4), Sp.bg],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
              ),
            )),

          // ── Contenu ────────────────────────────────────────────────
          SafeArea(child: Column(children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.keyboard_arrow_down_rounded, size: 32, color: Colors.white),
                ),
                Expanded(child: Column(children: [
                  Text('PLAYING FROM YOUR LIBRARY'.toUpperCase(),
                    style: const TextStyle(color: Colors.white70, fontSize: 10,
                        letterSpacing: 1.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(song.album,
                    style: const TextStyle(color: Colors.white,
                        fontSize: 13, fontWeight: FontWeight.bold),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                // Tab icons
                _tabIcon(Icons.music_note_rounded, 0),
                _tabIcon(Icons.lyrics_rounded, 1),
                _tabIcon(Icons.queue_music_rounded, 2),
              ]),
            ),

            Expanded(child: IndexedStack(index: _tab, children: [
              _PlayerTab(player: player, song: song),
              _LyricsTab(player: player),
              _QueueTab(player: player),
            ])),
          ])),
        ]),
      );
    });
  }

  Widget _tabIcon(IconData icon, int idx) {
    final active = _tab == idx;
    return IconButton(
      icon: active
          ? GIcon(icon, size: 22)
          : Icon(icon, size: 22, color: Colors.white54),
      onPressed: () => setState(() => _tab = idx),
    );
  }
}

// ── Player tab ─────────────────────────────────────────────────────────────────
class _PlayerTab extends StatelessWidget {
  final PlayerProvider player;
  final song;
  const _PlayerTab({required this.player, required this.song});

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        const SizedBox(height: 8),

        // ── Big artwork ───────────────────────────────────────────
        Expanded(flex: 5, child: Center(child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 40, offset: const Offset(0, 12))],
          ),
          child: AspectRatio(aspectRatio: 1, child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ArtworkWidget(
              key: ValueKey(song.hash),
              hash: song.image ?? song.hash,
              size: double.infinity,
              borderRadius: BorderRadius.circular(8),
            ),
          )),
        ))),
        const SizedBox(height: 28),

        // ── Title + like ──────────────────────────────────────────
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(song.title, style: const TextStyle(
              color: Colors.white, fontSize: 22,
              fontWeight: FontWeight.bold, letterSpacing: -0.3),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(song.artist, style: TextStyle(
              color: Colors.white.withOpacity(0.7), fontSize: 15),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 16),
          ShaderMask(
            shaderCallback: (b) => kGrad.createShader(b),
            child: const Icon(Icons.favorite_border_rounded, color: Colors.white, size: 28),
          ),
        ]),
        const SizedBox(height: 20),

        // ── Progress bar ──────────────────────────────────────────
        _ProgressBar(player: player),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_fmt(player.position),
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
          Text(_fmt(player.duration),
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
        ]),
        const SizedBox(height: 20),

        // ── Controls — exact Spotify layout ──────────────────────
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Shuffle
          GestureDetector(
            onTap: player.toggleShuffle,
            child: Stack(alignment: Alignment.bottomCenter, children: [
              player.shuffle
                  ? const GIcon(Icons.shuffle_rounded, size: 26)
                  : Icon(Icons.shuffle_rounded, size: 26,
                      color: Colors.white.withOpacity(0.6)),
              if (player.shuffle) Positioned(bottom: -4,
                child: Container(width: 4, height: 4,
                  decoration: BoxDecoration(gradient: kGrad, shape: BoxShape.circle))),
            ]),
          ),

          // Prev
          GestureDetector(
            onTap: player.previous,
            child: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 46)),

          // Play/Pause — grand cercle blanc Spotify
          GestureDetector(
            onTap: player.playPause,
            child: Container(
              width: 68, height: 68,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Center(child: player.isLoading
                  ? const SizedBox(width: 26, height: 26,
                      child: CircularProgressIndicator(color: Sp.bg, strokeWidth: 2.5))
                  : Icon(
                      player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Sp.bg, size: 42)),
            ),
          ),

          // Next
          GestureDetector(
            onTap: player.next,
            child: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 46)),

          // Repeat
          GestureDetector(
            onTap: player.toggleRepeat,
            child: Stack(alignment: Alignment.bottomCenter, children: [
              player.repeatMode == RepeatMode.off
                  ? Icon(Icons.repeat_rounded, size: 26,
                      color: Colors.white.withOpacity(0.6))
                  : player.repeatMode == RepeatMode.one
                      ? const GIcon(Icons.repeat_one_rounded, size: 26)
                      : const GIcon(Icons.repeat_rounded, size: 26),
              if (player.repeatMode != RepeatMode.off) Positioned(bottom: -4,
                child: Container(width: 4, height: 4,
                  decoration: BoxDecoration(gradient: kGrad, shape: BoxShape.circle))),
            ]),
          ),
        ]),

        const SizedBox(height: 24),

        // ── Share + device row (Spotify style) ────────────────────
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(Icons.devices_rounded, size: 20, color: Colors.white.withOpacity(0.6)),
          Row(children: [
            Icon(Icons.share_rounded, size: 20, color: Colors.white.withOpacity(0.6)),
            const SizedBox(width: 20),
            Icon(Icons.more_horiz_rounded, size: 24, color: Colors.white.withOpacity(0.6)),
          ]),
        ]),

        const SizedBox(height: 16),
      ]),
    );
  }
}

// ── Progress bar custom ────────────────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final PlayerProvider player;
  const _ProgressBar({required this.player});

  @override
  Widget build(BuildContext ctx) {
    final v = player.progress.clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        final box = ctx.findRenderObject() as RenderBox?;
        if (box == null) return;
        final frac = (d.localPosition.dx / box.size.width).clamp(0.0, 1.0);
        player.seek(Duration(milliseconds: (frac * player.duration.inMilliseconds).round()));
      },
      child: SizedBox(height: 28, child: Stack(alignment: Alignment.center, children: [
        Container(height: 4, decoration: BoxDecoration(
          color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Align(alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: v,
            child: Container(height: 4, decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(2))))),
        Align(alignment: Alignment(v * 2 - 1, 0),
          child: Container(width: 14, height: 14,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
      ])),
    );
  }
}

// ── Lyrics tab ─────────────────────────────────────────────────────────────────
class _LyricsTab extends StatefulWidget {
  final PlayerProvider player;
  const _LyricsTab({required this.player});
  @override
  State<_LyricsTab> createState() => _LyricsTabState();
}

class _LyricsTabState extends State<_LyricsTab> {
  final _scroll = ScrollController();
  int _line = 0;

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
      try {
        _scroll.animateTo((idx * 56.0 - 150).clamp(0.0, _scroll.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext ctx) {
    final p = widget.player;
    if (p.lyricsLoading) return const Center(
      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));

    if (p.lyricsSynced && p.syncedLines != null && p.syncedLines!.isNotEmpty) {
      _sync();
      return ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
        itemCount: p.syncedLines!.length,
        itemBuilder: (ctx, i) {
          final active = i == _line;
          final text = p.syncedLines![i]['text'] as String;
          if (text.trim().isEmpty) return const SizedBox(height: 16);
          if (active) return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ShaderMask(
              shaderCallback: (b) => kGrad.createShader(b),
              child: Text(text, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white,
                    fontSize: 22, fontWeight: FontWeight.bold, height: 1.6))),
          );
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(text, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white30, fontSize: 16, height: 1.6)));
        },
      );
    }
    if (p.unsyncedLines != null && p.unsyncedLines!.isNotEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Text(p.unsyncedLines!.join("\n"),
          style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.9),
          textAlign: TextAlign.center));
    }
    return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.lyrics_outlined, color: Colors.white38, size: 56),
      SizedBox(height: 16),
      Text('Aucune parole disponible', style: TextStyle(color: Colors.white54)),
    ]));
  }

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }
}

// ── Queue tab ──────────────────────────────────────────────────────────────────
class _QueueTab extends StatelessWidget {
  final PlayerProvider player;
  const _QueueTab({required this.player});
  @override
  Widget build(BuildContext ctx) {
    final q = player.queue;
    if (q.isEmpty) return const Center(
      child: Text('File vide', style: TextStyle(color: Colors.white54)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text('File d\'attente', style: TextStyle(
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
              color: cur ? Sp.g2 : Colors.white,
              fontWeight: cur ? FontWeight.bold : FontWeight.w500, fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(s.artist,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: cur
                ? const GIcon(Icons.equalizer_rounded, size: 20)
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
