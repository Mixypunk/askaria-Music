import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../screens/player_screen.dart';
import 'artwork_widget.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        if (song == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PlayerScreen()),
          ),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar
                LinearProgressIndicator(
                  value: player.progress,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(
                    Theme.of(context).colorScheme.primary,
                  ),
                  minHeight: 2,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      // Artwork
                      ArtworkWidget(
                        key: ValueKey(song.hash),
                        hash: song.image ?? song.hash,
                        size: 44,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(width: 12),
                      // Title & Artist
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              song.artist,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Controls
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded),
                        onPressed: player.previous,
                        iconSize: 24,
                      ),
                      IconButton(
                        icon: player.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                player.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                        onPressed: player.playPause,
                        iconSize: 32,
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded),
                        onPressed: player.next,
                        iconSize: 24,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
