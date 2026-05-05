import 'package:flutter/material.dart';
import '../../../providers/player_provider.dart';
import '../../../widgets/artwork_widget.dart';

class QueueView extends StatelessWidget {
  final PlayerProvider player;
  final Color accent;

  const QueueView({super.key, required this.player, required this.accent});

  @override
  Widget build(BuildContext ctx) {
    final q = player.queue;
    if (q.isEmpty) return const Center(
      child: Text('File vide', style: TextStyle(color: Colors.white54)));
    
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text("File d'attente", style: TextStyle(
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
              color: cur ? accent : Colors.white,
              fontWeight: cur ? FontWeight.bold : FontWeight.w500, fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(s.artist,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: cur
                ? Icon(Icons.equalizer_rounded, size: 20, color: accent)
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
