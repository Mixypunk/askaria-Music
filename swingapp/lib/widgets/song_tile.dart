import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/downloads_provider.dart';
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
    final downloads = context.watch<DownloadsProvider>();
    final isCurrent = player.currentSong == song;
    final isDownloaded = downloads.isDownloaded(song.hash);

    return InkWell(
      onTap: onTap ?? () => context.read<PlayerProvider>().playSong(
        song, queue: queue ?? [song], index: index ?? 0),
      borderRadius: BorderRadius.circular(12),
      splashColor: Colors.white10,
      highlightColor: const Color(0x0DFFFFFF),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          // Artwork ou numéro
          if (showNumber)
            SizedBox(width: 40, child: Center(
              child: isCurrent
                  ? const GIcon(Icons.equalizer_rounded, size: 18)
                  : Text('${(index ?? 0) + 1}',
                      style: const TextStyle(
                          color: Sp.white40, fontSize: 13)),
            ))
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ArtworkWidget(
                key: ValueKey(song.hash),
                hash: song.image ?? song.hash,
                size: 50,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          const SizedBox(width: 12),
          // Texte
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
              const SizedBox(height: 3),
              Row(children: [
                if (isDownloaded) ...[
                  const Icon(Icons.download_done_rounded,
                      size: 11, color: Color(0xFF148A08)),
                  const SizedBox(width: 4),
                ],
                Expanded(child: Text(song.artist,
                  style: const TextStyle(color: Sp.white70, fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ],
          )),
          // Durée
          Text(song.formattedDuration,
            style: const TextStyle(color: Sp.white40, fontSize: 12)),
          const SizedBox(width: 4),
          // Menu contextuel
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18, color: Sp.white40),
            color: Sp.card,
            elevation: 12,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            itemBuilder: (_) => [
              _menuItem('next', Icons.queue_play_next_rounded, 'Lire ensuite'),
              _menuItem('queue', Icons.playlist_add_rounded, 'Ajouter à la file'),
              if (isDownloaded)
                _menuItemRed('delete_dl', Icons.delete_outline_rounded,
                    'Supprimer le téléchargement')
              else
                _menuItem('download', Icons.download_rounded, 'Télécharger'),
              if (onRemove != null)
                _menuItemRed('remove', Icons.remove_circle_outline_rounded,
                    'Retirer de la liste'),
            ],
            onSelected: (v) {
              if (v == 'remove') { onRemove?.call(); return; }
              if (v == 'download') {
                context.read<DownloadsProvider>().downloadSong(song, context);
                return;
              }
              if (v == 'delete_dl') {
                context.read<DownloadsProvider>().deleteSong(song.hash, song.filepath);
                return;
              }
              final p = context.read<PlayerProvider>();
              if (v == 'next') {
                p.addNextInQueue(song);
                _snack(context, '${song.title} → lire ensuite');
              } else if (v == 'queue') {
                p.addToQueue(song);
                _snack(context, '${song.title} ajouté à la file');
              }
            },
          ),
        ]),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String val, IconData icon, String label) =>
    PopupMenuItem(
      value: val,
      child: Row(children: [
        Icon(icon, size: 18, color: Sp.white70),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ]),
    );

  PopupMenuItem<String> _menuItemRed(String val, IconData icon, String label) =>
    PopupMenuItem(
      value: val,
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.redAccent),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(
            color: Colors.redAccent, fontSize: 14)),
      ]),
    );

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Sp.card,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }
}
