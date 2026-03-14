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
    return Consumer<PlayerProvider>(builder: (ctx, player, _) {
      final song = player.currentSong;
      if (song == null) return const SizedBox.shrink();

      return GestureDetector(
        onTap: () => Navigator.push(ctx, PageRouteBuilder(
          pageBuilder: (_, a, __) => const PlayerScreen(),
          transitionsBuilder: (_, a, __, child) => SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        )),
        child: Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          height: 64,
          decoration: BoxDecoration(
            color: Sp.card,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4),
                blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Stack(children: [
            // Progress bar en bas
            Positioned(bottom: 0, left: 0, right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                child: SizedBox(height: 2,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: player.progress.clamp(0.0, 1.0),
                    child: Container(decoration: const BoxDecoration(gradient: kGrad)),
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                // Artwork
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: ArtworkWidget(
                    key: ValueKey(song.hash),
                    hash: song.image ?? song.hash,
                    size: 46,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 10),

                // Title/Artist
                Expanded(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title,
                      style: const TextStyle(color: Sp.white,
                          fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(song.artist,
                      style: const TextStyle(color: Sp.white70, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                )),

                // Controls: prev + play + next
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded, color: Sp.white, size: 24),
                  onPressed: player.previous,
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: player.playPause,
                  child: Container(
                    width: 32, height: 32,
                    decoration: const BoxDecoration(gradient: kGrad, shape: BoxShape.circle),
                    child: player.isLoading
                        ? const Padding(padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded, color: Sp.white, size: 24),
                  onPressed: player.next,
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
              ]),
            ),
          ]),
        ),
      );
    });
  }
}
