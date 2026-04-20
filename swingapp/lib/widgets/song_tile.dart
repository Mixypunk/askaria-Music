import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../main.dart';
import 'artwork_widget.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final List<Song>? queue;
  final int? index;
  final bool showNumber;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const SongTile({
    super.key, required this.song,
    this.queue, this.index, this.showNumber = false, this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final isCurrent = player.currentSong == song;

    return InkWell(
      onTap: onTap ?? () => context.read<PlayerProvider>().playSong(
        song, queue: queue ?? [song], index: index ?? 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          // Artwork / number
          if (showNumber)
            SizedBox(width: 40, child: Center(
              child: isCurrent
                  ? const GIcon(Icons.equalizer_rounded, size: 18)
                  : Text('${(index ?? 0) + 1}',
                      style: const TextStyle(color: Sp.white70, fontSize: 13)),
            ))
          else
            ArtworkWidget(
              key: ValueKey(song.hash),
              hash: song.image ?? song.hash,
              size: 46,
              borderRadius: BorderRadius.circular(8),
            ),
          const SizedBox(width: 12),
          // Text
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(song.title,
                style: TextStyle(
                  color: isCurrent ? Sp.g2 : Colors.white,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(song.artist,
                style: const TextStyle(color: Sp.white70, fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          )),
          // Duration + menu
          Text(song.formattedDuration,
            style: const TextStyle(color: Sp.white40, fontSize: 12)),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18, color: Sp.white40),
            color: Sp.cardHi,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'next',  child: Text('Lire ensuite')),
              const PopupMenuItem(value: 'queue', child: Text('Ajouter à la file')),
              if (onRemove != null)
                const PopupMenuItem(value: 'remove', child: Text('Retirer', style: TextStyle(color: Colors.redAccent))),
            ],
            onSelected: (v) {
              if (v == 'remove') {
                onRemove?.call();
                return;
              }
              final p = context.read<PlayerProvider>();
              if (v == 'next') {
                p.addNextInQueue(song);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${song.title} → lire ensuite'),
                  backgroundColor: Sp.card,
                  duration: const Duration(seconds: 2),
                ));
              } else {
                p.addToQueue(song);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${song.title} ajouté'),
                  backgroundColor: Sp.card,
                  duration: const Duration(seconds: 2),
                ));
              }
            },
          ),
        ]),
      ),
    );
  }
}
