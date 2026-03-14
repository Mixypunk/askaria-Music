import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../widgets/artwork_widget.dart';
import '../main.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  int _tab = 0; // 0=player 1=lyrics 2=queue

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Consumer<PlayerProvider>(builder: (context, player, _) {
        final song = player.currentSong;
        if (song == null) return const Center(child: Text('Aucune musique'));

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.grad1.withOpacity(0.25), AppColors.bg, AppColors.bg],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30,
                        color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(child: Column(children: [
                    const Text('EN COURS DE LECTURE',
                      style: TextStyle(color: AppColors.textSecondary,
                          fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(song.album,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 13, fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  // Tab icons
                  _tabIcon(Icons.music_note_rounded, 0),
                  _tabIcon(Icons.lyrics_rounded, 1),
                  _tabIcon(Icons.queue_music_rounded, 2),
                ]),
              ),

              // Content
              Expanded(child: IndexedStack(index: _tab, children: [
                _PlayerTab(player: player, song: song),
                _LyricsTab(player: player),
                _QueueTab(player: player),
              ])),
            ]),
          ),
        );
      }),
    );
  }

  Widget _tabIcon(IconData icon, int idx) {
    final active = _tab == idx;
    return IconButton(
      icon: active ? GradientIcon(icon, size: 22) : Icon(icon, size: 22, color: AppColors.textDisabled),
      onPressed: () => setState(() => _tab = idx),
    );
  }
}

// ── PLAYER TAB ────────────────────────────────────────────────────────────────
class _PlayerTab extends StatelessWidget {
  final PlayerProvider player;
  final song;
  const _PlayerTab({required this.player, required this.song});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(children: [
        const SizedBox(height: 16),
        // Big artwork with glow
        Expanded(child: Center(child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(
              color: AppColors.grad2.withOpacity(0.35),
              blurRadius: 50, spreadRadius: 5,
            )],
          ),
          child: AspectRatio(
            aspectRatio: 1,
            child: ArtworkWidget(
              key: ValueKey(song.hash),
              hash: song.image ?? song.hash,
              size: double.infinity,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ))),
        const SizedBox(height: 28),
        // Title & Artist
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(song.title,
              style: const TextStyle(color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.bold, letterSpacing: -0.5),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(song.artist,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
        const SizedBox(height: 20),
        // Progress bar
        _GradientSlider(player: player),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_fmt(player.position),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          Text(_fmt(player.duration),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ]),
        const SizedBox(height: 20),
        // Controls
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _ctrlBtn(
            player.shuffle ? const GradientIcon(Icons.shuffle_rounded, size: 22)
                           : const Icon(Icons.shuffle_rounded, size: 22, color: AppColors.textDisabled),
            player.toggleShuffle,
          ),
          _ctrlBtn(const Icon(Icons.skip_previous_rounded, size: 38, color: Colors.white),
              player.previous),
          // Play/Pause big button
          GestureDetector(
            onTap: player.playPause,
            child: Container(
              width: 68, height: 68,
              decoration: const BoxDecoration(gradient: kGradient, shape: BoxShape.circle),
              child: Center(
                child: player.isLoading
                    ? const SizedBox(width: 26, height: 26,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Icon(player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white, size: 36),
              ),
            ),
          ),
          _ctrlBtn(const Icon(Icons.skip_next_rounded, size: 38, color: Colors.white),
              player.next),
          _ctrlBtn(
            player.repeatMode == RepeatMode.one
                ? const GradientIcon(Icons.repeat_one_rounded, size: 22)
                : player.repeatMode == RepeatMode.all
                    ? const GradientIcon(Icons.repeat_rounded, size: 22)
                    : const Icon(Icons.repeat_rounded, size: 22, color: AppColors.textDisabled),
            player.toggleRepeat,
          ),
        ]),
        const SizedBox(height: 28),
      ]),
    );
  }

  Widget _ctrlBtn(Widget icon, VoidCallback cb) =>
    GestureDetector(onTap: cb, child: Padding(padding: const EdgeInsets.all(8), child: icon));

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _GradientSlider extends StatelessWidget {
  final PlayerProvider player;
  const _GradientSlider({required this.player});

  @override
  Widget build(BuildContext context) {
    final progress = player.progress.clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final frac = ((d.localPosition.dx) / box.size.width).clamp(0.0, 1.0);
        player.seek(Duration(milliseconds: (frac * player.duration.inMilliseconds).round()));
      },
      child: SizedBox(
        height: 28,
        child: Stack(alignment: Alignment.centerLeft, children: [
          // Track
          Container(height: 3, decoration: BoxDecoration(
            color: Colors.white12, borderRadius: BorderRadius.circular(3))),
          // Filled
          FractionallySizedBox(
            widthFactor: progress,
            child: Container(height: 3, decoration: BoxDecoration(
              gradient: kGradient, borderRadius: BorderRadius.circular(3))),
          ),
          // Thumb
          Positioned(
            left: (MediaQuery.of(context).size.width - 56) * progress - 7,
            child: Container(width: 14, height: 14, decoration: const BoxDecoration(
              color: Colors.white, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 4)])),
          ),
        ]),
      ),
    );
  }
}

// ── LYRICS TAB ────────────────────────────────────────────────────────────────
class _LyricsTab extends StatefulWidget {
  final PlayerProvider player;
  const _LyricsTab({required this.player});
  @override
  State<_LyricsTab> createState() => _LyricsTabState();
}

class _LyricsTabState extends State<_LyricsTab> {
  final ScrollController _scroll = ScrollController();
  int _currentLine = 0;

  void _updateLine() {
    final lines = widget.player.syncedLines;
    if (lines == null || lines.isEmpty) return;
    final pos = widget.player.position.inMilliseconds;
    int idx = 0;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i]['time'] <= pos) idx = i;
    }
    if (idx != _currentLine) {
      setState(() => _currentLine = idx);
      try {
        final offset = (idx * 56.0) - 150;
        _scroll.animateTo(offset.clamp(0.0, _scroll.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    if (p.lyricsLoading) return const Center(
        child: CircularProgressIndicator(color: AppColors.grad2));

    if (p.lyricsSynced && p.syncedLines != null && p.syncedLines!.isNotEmpty) {
      _updateLine();
      return ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
        itemCount: p.syncedLines!.length,
        itemBuilder: (ctx, i) {
          final active = i == _currentLine;
          final text = p.syncedLines![i]['text'] as String;
          if (text.trim().isEmpty) return const SizedBox(height: 16);
          return AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              height: 1.9,
              fontSize: active ? 22 : 16,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active ? Colors.white : Colors.white24,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: active
                  ? ShaderMask(
                      shaderCallback: (b) => kGradient.createShader(b),
                      child: Text(text, textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white)))
                  : Text(text, textAlign: TextAlign.center),
            ),
          );
        },
      );
    }

    if (p.unsyncedLines != null && p.unsyncedLines!.isNotEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Text(p.unsyncedLines!.join("\n"),
          style: const TextStyle(color: Colors.white70, height: 1.9, fontSize: 16),
          textAlign: TextAlign.center),
      );
    }

    return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      GradientIcon(Icons.lyrics_outlined, size: 56),
      SizedBox(height: 16),
      Text('Pas de paroles disponibles', style: TextStyle(color: AppColors.textSecondary)),
    ]));
  }

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }
}

// ── QUEUE TAB ─────────────────────────────────────────────────────────────────
class _QueueTab extends StatelessWidget {
  final PlayerProvider player;
  const _QueueTab({required this.player});

  @override
  Widget build(BuildContext context) {
    final queue = player.queue;
    if (queue.isEmpty) return const Center(
      child: Text('File vide', style: TextStyle(color: AppColors.textSecondary)));

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: queue.length,
      onReorder: player.reorderQueue,
      proxyDecorator: (child, _, __) => Material(color: Colors.transparent, child: child),
      itemBuilder: (ctx, i) {
        final s = queue[i];
        final isCurrent = i == player.currentIndex;
        return ListTile(
          key: ValueKey(s.hash + i.toString()),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          leading: isCurrent
              ? const GradientIcon(Icons.equalizer_rounded, size: 20)
              : Text('${i + 1}', style: const TextStyle(
                  color: AppColors.textDisabled, fontSize: 13)),
          title: Text(s.title,
            style: TextStyle(
              color: isCurrent ? AppColors.grad2 : Colors.white,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(s.artist,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: isCurrent
              ? null
              : IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded,
                      size: 18, color: AppColors.textDisabled),
                  onPressed: () => player.removeFromQueue(i)),
          onTap: () => player.playSong(s, queue: queue, index: i),
        );
      },
    );
  }
}
