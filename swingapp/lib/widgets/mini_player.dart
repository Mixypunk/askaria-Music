import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../screens/player_screen.dart';
import '../main.dart';
import 'artwork_widget.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(builder: (context, player, _) {
      final song = player.currentSong;
      if (song == null) return const SizedBox.shrink();

      return GestureDetector(
        onTap: () => Navigator.push(context,
          PageRouteBuilder(
            pageBuilder: (_, a, __) => const PlayerScreen(),
            transitionsBuilder: (_, a, __, child) => SlideTransition(
              position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                  .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(color: AppColors.grad2.withOpacity(0.15),
                  blurRadius: 20, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Gradient progress bar
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 2.5,
                child: LayoutBuilder(builder: (ctx, constraints) {
                  return Stack(children: [
                    Container(color: Colors.white12),
                    FractionallySizedBox(
                      widthFactor: player.progress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: const BoxDecoration(gradient: kGradient),
                      ),
                    ),
                  ]);
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(children: [
                // Artwork
                ArtworkWidget(
                  key: ValueKey(song.hash),
                  hash: song.image ?? song.hash,
                  size: 42,
                  borderRadius: BorderRadius.circular(10),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(song.artist,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                )),
                // Controls
                _ctrl(Icons.skip_previous_rounded, player.previous, 22),
                _playBtn(player),
                _ctrl(Icons.skip_next_rounded, player.next, 22),
              ]),
            ),
          ]),
        ),
      );
    });
  }

  Widget _ctrl(IconData icon, VoidCallback cb, double size) =>
    IconButton(icon: Icon(icon, size: size, color: AppColors.textSecondary), onPressed: cb);

  Widget _playBtn(PlayerProvider player) => Container(
    width: 38, height: 38,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    decoration: const BoxDecoration(gradient: kGradient, shape: BoxShape.circle),
    child: player.isLoading
        ? const Padding(padding: EdgeInsets.all(10),
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white, size: 20),
            onPressed: player.playPause),
  );
}
