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
    // Selector : ne rebuild que si currentSong change (pas à chaque position)
    return Selector<PlayerProvider, bool>(
      selector: (_, p) => p.currentSong != null,
      builder: (ctx, hasSong, _) {
        if (!hasSong) return const SizedBox.shrink();
        return RepaintBoundary(child: _MiniPlayerContent());
      },
    );
  }
}

class _MiniPlayerContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong!;
    final accent = player.dynamicColors.accent;

    return GestureDetector(
      onTap: () => Navigator.push(context, PageRouteBuilder(
        pageBuilder: (_, a, __) => const PlayerScreen(),
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      )),
      // Swipe gauche = suivant, swipe droite = précédent
      onHorizontalDragEnd: (d) {
        if (d.primaryVelocity == null) return;
        if (d.primaryVelocity! < -300) player.next();
        if (d.primaryVelocity! >  300) player.previous();
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        height: 62,
        decoration: BoxDecoration(
          color: const Color(0xFF282828),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withOpacity(0.12), width: 0.5),
        ),
        child: Stack(children: [
          // Barre de progression
          Positioned(bottom: 0, left: 0, right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              child: RepaintBoundary(
                child: SizedBox(height: 2,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: player.progress.clamp(0.0, 1.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      color: accent),
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
            child: Row(children: [
              // Artwork
              RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: ArtworkWidget(
                    key: ValueKey(song.hash),
                    hash: song.image ?? song.hash,
                    size: 46,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Titre / Artiste
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

              // Like
              GestureDetector(
                onTap: () => player.toggleFavourite(song.hash),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    player.isFavourite(song.hash)
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: player.isFavourite(song.hash) ? accent : Colors.white54,
                    size: 22),
                ),
              ),

              // Play/Pause
              GestureDetector(
                onTap: player.playPause,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: player.isLoading
                      ? SizedBox(width: 28, height: 28,
                          child: CircularProgressIndicator(
                              color: accent, strokeWidth: 2))
                      : Icon(
                          player.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white, size: 32),
                ),
              ),

              // Next
              GestureDetector(
                onTap: player.next,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.skip_next_rounded,
                      color: Colors.white, size: 28))),
              const SizedBox(width: 2),
            ]),
          ),
        ]),
      ),
    );
  }
}
