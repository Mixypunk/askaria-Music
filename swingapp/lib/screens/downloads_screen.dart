import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/album.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/downloads_provider.dart';
import '../widgets/artwork_widget.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});
  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  @override
  void initState() {
    super.initState();
    // Actualiser les données hors-ligne au chargement
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DownloadsProvider>().refresh();
    });
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} Ko';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} Go';
  }

  int _calcTotalSize(List<Song> songs) {
    int total = 0;
    for (final s in songs) {
      if (s.filepath != null) {
        final f = File(s.filepath!);
        if (f.existsSync()) total += f.lengthSync();
      }
    }
    return total;
  }

  Future<void> _deleteSong(BuildContext ctx, Song song) async {
    await ctx.read<DownloadsProvider>().deleteSong(song.hash, song.filepath);
  }

  Future<void> _deletePlaylist(BuildContext ctx, Playlist pl) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Sp.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Retirer la playlist', style: TextStyle(color: Sp.white, fontWeight: FontWeight.bold)),
        content: Text('Supprimer "${pl.name}" du mode hors-ligne ?',
            style: const TextStyle(color: Sp.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler', style: TextStyle(color: Sp.white70))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok == true && ctx.mounted) {
      await ctx.read<DownloadsProvider>().unsyncPlaylist(pl.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadsProvider>(
      builder: (ctx, dl, _) {
        final songs = dl.downloadedSongs;
        final playlists = dl.downloadedPlaylists;
        final isEmpty = songs.isEmpty && playlists.isEmpty;
        final totalSize = _calcTotalSize(songs);

        return Scaffold(
          backgroundColor: Sp.bg,
          appBar: AppBar(
            backgroundColor: Sp.bg,
            title: const Text('Hors-ligne',
                style: TextStyle(color: Sp.white, fontSize: 18,
                    fontWeight: FontWeight.bold)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Sp.white, size: 20),
              onPressed: () => Navigator.pop(context)),
            actions: [
              if (songs.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded,
                      color: Sp.white70, size: 22),
                  tooltip: 'Tout supprimer',
                  onPressed: () => _confirmDeleteAll(ctx, dl, songs),
                ),
            ],
          ),
          body: isEmpty
              ? const _EmptyState()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  children: [
                    // ── Résumé stockage ─────────────────────────────────
                    _StorageSummary(
                      songCount: songs.length,
                      playlistCount: playlists.length,
                      totalSize: _fmtSize(totalSize),
                    ),
                    const SizedBox(height: 20),

                    // ── Section Playlists ────────────────────────────────
                    if (playlists.isNotEmpty) ...[
                      _SectionHeader(
                        icon: Icons.queue_music_rounded,
                        label: 'Playlists',
                        count: playlists.length,
                      ),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: playlists.length,
                        itemBuilder: (ctx, i) => _PlaylistCard(
                          playlist: playlists[i],
                          onDelete: () => _deletePlaylist(ctx, playlists[i]),
                          onPlay: (tracks) {
                            if (tracks.isNotEmpty) {
                              ctx.read<PlayerProvider>().playSong(
                                tracks.first, queue: tracks);
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ── Section Titres ───────────────────────────────────
                    if (songs.isNotEmpty) ...[
                      _SectionHeader(
                        icon: Icons.music_note_rounded,
                        label: 'Titres',
                        count: songs.length,
                        trailing: songs.length > 1
                            ? _PlayAllButton(onTap: () {
                                ctx.read<PlayerProvider>().playSong(
                                  songs.first, queue: songs);
                                Navigator.pop(context);
                              })
                            : null,
                      ),
                      const SizedBox(height: 10),
                      ...songs.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _SongTileOffline(
                          song: e.value,
                          onPlay: () {
                            ctx.read<PlayerProvider>().playSong(
                              e.value, queue: songs, index: e.key);
                            Navigator.pop(context);
                          },
                          onDelete: () => _deleteSong(ctx, e.value),
                        ),
                      )),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Future<void> _confirmDeleteAll(
      BuildContext ctx, DownloadsProvider dl, List<Song> songs) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Sp.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tout supprimer',
            style: TextStyle(color: Sp.white, fontWeight: FontWeight.bold)),
        content: Text('Supprimer ${songs.length} titre(s) hors-ligne ?',
            style: const TextStyle(color: Sp.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler', style: TextStyle(color: Sp.white70))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok == true) {
      for (final s in [...songs]) {
        await dl.deleteSong(s.hash, s.filepath);
      }
    }
  }
}

// ── Résumé stockage ────────────────────────────────────────────────────────────
class _StorageSummary extends StatelessWidget {
  final int songCount;
  final int playlistCount;
  final String totalSize;
  const _StorageSummary({
    required this.songCount,
    required this.playlistCount,
    required this.totalSize,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Sp.g1.withOpacity(0.12), Sp.g2.withOpacity(0.12)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Sp.g2.withOpacity(0.2)),
    ),
    child: Row(children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: Sp.g2.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.wifi_off_rounded, color: Sp.g2, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Disponible hors-ligne',
            style: TextStyle(color: Sp.white, fontSize: 14,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          [
            if (songCount > 0) '$songCount titre${songCount > 1 ? 's' : ''}',
            if (playlistCount > 0) '$playlistCount playlist${playlistCount > 1 ? 's' : ''}',
          ].join(' · '),
          style: const TextStyle(color: Sp.white70, fontSize: 12),
        ),
      ])),
      Text(totalSize,
          style: const TextStyle(color: Sp.white40, fontSize: 12)),
    ]),
  );
}

// ── En-tête de section ────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Widget? trailing;
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.count,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: Sp.white40, size: 14),
    const SizedBox(width: 6),
    Text('$label ($count)'.toUpperCase(),
        style: const TextStyle(
          color: Sp.white40, fontSize: 11,
          letterSpacing: 1.4, fontWeight: FontWeight.w700)),
    const Spacer(),
    if (trailing != null) trailing!,
  ]);
}

// ── Bouton Tout lire ──────────────────────────────────────────────────────────
class _PlayAllButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PlayAllButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: kGrad,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
        SizedBox(width: 4),
        Text('Tout lire', style: TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

// ── Card playlist offline ─────────────────────────────────────────────────────
class _PlaylistCard extends StatefulWidget {
  final Playlist playlist;
  final VoidCallback onDelete;
  final void Function(List<Song>) onPlay;
  const _PlaylistCard({
    required this.playlist,
    required this.onDelete,
    required this.onPlay,
  });
  @override
  State<_PlaylistCard> createState() => _PlaylistCardState();
}

class _PlaylistCardState extends State<_PlaylistCard> {
  List<Song> _tracks = [];

  @override
  void initState() {
    super.initState();
    context.read<DownloadsProvider>()
        .getOfflinePlaylistTracks(widget.playlist.id)
        .then((t) { if (mounted) setState(() => _tracks = t); });
  }

  @override
  Widget build(BuildContext context) {
    final pl = widget.playlist;
    return GestureDetector(
      onTap: () => widget.onPlay(_tracks),
      child: Container(
        decoration: BoxDecoration(
          color: Sp.card,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Artwork
          Stack(children: [
            AspectRatio(
              aspectRatio: 1,
              child: pl.imageHash != null
                  ? ArtworkWidget(
                      hash: pl.imageHash!, size: double.infinity,
                      borderRadius: BorderRadius.zero)
                  : Container(
                      color: Sp.surface,
                      child: const Icon(Icons.queue_music_rounded,
                          color: Sp.white40, size: 40)),
            ),
            // Bouton play overlay
            Positioned.fill(child: Center(
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white30)),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 26),
              ),
            )),
            // Bouton supprimer
            Positioned(top: 6, right: 6,
              child: GestureDetector(
                onTap: widget.onDelete,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent, size: 16),
                ),
              ),
            ),
          ]),
          // Infos
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pl.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Sp.white,
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${_tracks.isNotEmpty ? _tracks.length : pl.trackCount} titres',
                  style: const TextStyle(color: Sp.white40, fontSize: 11)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Tile titre offline (avec swipe-to-delete) ────────────────────────────────
class _SongTileOffline extends StatelessWidget {
  final Song song;
  final VoidCallback onPlay;
  final VoidCallback onDelete;
  const _SongTileOffline({
    required this.song,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Dismissible(
    key: ValueKey(song.hash),
    direction: DismissDirection.endToStart,
    background: Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.delete_outline_rounded,
          color: Colors.redAccent, size: 24),
    ),
    onDismissed: (_) => onDelete(),
    child: GestureDetector(
      onTap: onPlay,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Sp.card,
          borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          ArtworkWidget(
            key: ValueKey(song.image ?? song.hash),
            hash: song.image ?? song.hash,
            size: 46,
            borderRadius: BorderRadius.circular(6)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(song.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Sp.white,
                      fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(
                [
                  if (song.artist.isNotEmpty) song.artist,
                  if (song.duration > 0) _fmtDuration(song.duration),
                ].join(' · '),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Sp.white40, fontSize: 11)),
            ])),
          const Icon(Icons.play_circle_outline_rounded,
              color: Sp.g2, size: 28),
        ]),
      ),
    ),
  );

  String _fmtDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

// ── État vide ─────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext ctx) => const Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.wifi_off_rounded, color: Colors.white12, size: 64),
      SizedBox(height: 14),
      Text('Aucun contenu hors-ligne',
          style: TextStyle(color: Colors.white54, fontSize: 16,
              fontWeight: FontWeight.w500)),
      SizedBox(height: 6),
      Text('Appuyez sur ⬇ sur un titre ou une playlist\npour le rendre disponible hors-ligne',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white30, fontSize: 12)),
    ]));
}
