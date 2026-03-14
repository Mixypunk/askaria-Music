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
          height: 62,
          decoration: BoxDecoration(
            color: const Color(0xFF282828),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(children: [
            // Progress bar — thin line at bottom
            Positioned(bottom: 0, left: 0, right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                child: SizedBox(height: 2,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: player.progress.clamp(0.0, 1.0),
                    child: Container(color: Colors.white),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              child: Row(children: [
                // Artwork
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: ArtworkWidget(
                    key: ValueKey(song.hash),
                    hash: song.image ?? song.hash,
                    size: 46,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),

                // Title/Artist
                Expanded(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(song.artist,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                )),

                // Like icon (Spotify style)
                ShaderMask(
                  shaderCallback: (b) => kGrad.createShader(b),
                  child: const Icon(Icons.favorite_border_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 8),

                // Play/Pause — blanc Spotify
                GestureDetector(
                  onTap: player.playPause,
                  child: player.isLoading
                      ? const SizedBox(width: 32, height: 32,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Icon(
                          player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white, size: 32),
                ),
                const SizedBox(width: 6),

                // Next
                GestureDetector(
                  onTap: player.next,
                  child: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
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
