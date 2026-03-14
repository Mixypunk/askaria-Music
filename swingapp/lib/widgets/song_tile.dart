import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import 'artwork_widget.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final List<Song>? queue;
  final int? index;
  final bool showNumber;
  final VoidCallback? onTap;

  const SongTile({
    super.key,
    required this.song,
    this.queue,
    this.index,
    this.showNumber = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final isCurrent = player.currentSong == song;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: showNumber
          ? SizedBox(
              width: 40,
              child: Center(
                child: isCurrent
                    ? Icon(Icons.equalizer_rounded,
                        color: Theme.of(context).colorScheme.primary, size: 20)
                    : Text(
                        '${song.trackNumber > 0 ? song.trackNumber : (index ?? 0) + 1}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            )
          : ArtworkWidget(hash: song.image ?? song.hash, size: 48),
      title: Text(
        song.title,
        style: TextStyle(
          color: isCurrent ? Theme.of(context).colorScheme.primary : null,
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            song.formattedDuration,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'queue', child: Text('Add to queue')),
            ],
            onSelected: (value) {
              if (value == 'queue') {
                context.read<PlayerProvider>().addToQueue(song);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${song.title} added to queue'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      onTap: onTap ?? () => context.read<PlayerProvider>().playSong(
        song,
        queue: queue ?? [song],
        index: index ?? 0,
      ),
    );
  }
}
