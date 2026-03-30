import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/api_service.dart';
import '../widgets/artwork_widget.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});
  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<File> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dir = await getApplicationDocumentsDirectory();
    final offlineDir = Directory('${dir.path}/offline');
    if (offlineDir.existsSync()) {
      _files = offlineDir.listSync().whereType<File>().toList()
        ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _delete(File file) async {
    await file.delete();
    setState(() => _files.remove(file));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Fichier supprimé'),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating));
    }
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  @override
  Widget build(BuildContext context) {
    final totalSize = _files.fold(0, (s, f) => s + f.lengthSync());

    return Scaffold(
      backgroundColor: Sp.bg,
      appBar: AppBar(
        backgroundColor: Sp.bg,
        title: const Text('Téléchargements',
            style: TextStyle(color: Sp.white, fontSize: 18,
                fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Sp.white, size: 20),
          onPressed: () => Navigator.pop(context)),
        actions: [
          if (_files.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded,
                  color: Sp.white70, size: 22),
              tooltip: 'Tout supprimer',
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: Sp.card,
                    title: const Text('Tout supprimer',
                        style: TextStyle(color: Sp.white)),
                    content: Text(
                      'Supprimer ${_files.length} fichier(s) (${_fmtSize(totalSize)}) ?',
                      style: const TextStyle(color: Sp.white70)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false),
                          child: const Text('Annuler')),
                      TextButton(onPressed: () => Navigator.pop(context, true),
                          child: const Text('Supprimer',
                              style: TextStyle(color: Colors.redAccent))),
                    ]));
                if (ok == true) {
                  for (final f in [..._files]) await f.delete();
                  setState(() => _files.clear());
                }
              }),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Sp.g2))
          : _files.isEmpty
              ? const _EmptyState()
              : Column(children: [
                  // Résumé stockage
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Sp.card,
                      borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.storage_rounded,
                          color: Sp.g2, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text('${_files.length} titre(s) — ${_fmtSize(totalSize)}',
                          style: const TextStyle(
                              color: Sp.white, fontSize: 14))),
                    ]),
                  ),
                  Expanded(child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: _files.length,
                    itemBuilder: (ctx, i) {
                      final file = _files[i];
                      final hash = file.path.split('/').last.split('.').first;
                      final size = file.lengthSync();
                      return _DownloadTile(
                        file: file,
                        hash: hash,
                        size: _fmtSize(size),
                        onDelete: () => _delete(file),
                        onPlay: (song) {
                          ctx.read<PlayerProvider>().playSong(song);
                          Navigator.pop(context);
                        },
                      );
                    },
                  )),
                ]),
    );
  }
}

class _DownloadTile extends StatefulWidget {
  final File file;
  final String hash;
  final String size;
  final VoidCallback onDelete;
  final void Function(Song) onPlay;

  const _DownloadTile({required this.file, required this.hash,
      required this.size, required this.onDelete, required this.onPlay,
      super.key});

  @override
  State<_DownloadTile> createState() => _DownloadTileState();
}

class _DownloadTileState extends State<_DownloadTile> {
  Map<String, dynamic>? _meta;

  @override
  void initState() {
    super.initState();
    SwingApiService().getOfflineMeta(widget.hash).then((m) {
      if (mounted && m != null) setState(() => _meta = m);
    });
  }

  @override
  Widget build(BuildContext context) {
    final title  = _meta?['title']  as String? ?? widget.hash;
    final artist = _meta?['artist'] as String? ?? '';
    final image  = _meta?['image']  as String? ?? widget.hash;
    final dur    = _meta?['duration'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Sp.card,
          borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          ArtworkWidget(key: ValueKey(image), hash: image, size: 44,
              borderRadius: BorderRadius.circular(4)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Sp.white, fontSize: 13,
                    fontWeight: FontWeight.w500)),
              Text(artist.isNotEmpty ? '$artist • ${widget.size}' : widget.size,
                style: const TextStyle(color: Sp.white40, fontSize: 11)),
            ])),
          IconButton(
            icon: const Icon(Icons.play_circle_outline_rounded,
                color: Sp.g2, size: 28),
            onPressed: () {
              final song = Song(
                hash:       widget.hash,
                title:      title,
                artist:     artist,
                album:      _meta?['album'] as String? ?? '',
                filepath:   widget.file.path,
                albumHash:  '',
                artistHash: '',
                duration:   dur,
                image:      image,
              );
              widget.onPlay(song);
            }),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent, size: 22),
            onPressed: widget.onDelete),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext ctx) => const Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.download_done_rounded, color: Colors.white12, size: 64),
      SizedBox(height: 14),
      Text('Aucun téléchargement',
          style: TextStyle(color: Colors.white54, fontSize: 16,
              fontWeight: FontWeight.w500)),
      SizedBox(height: 6),
      Text('Appuyez sur ⬇ sur un titre pour le télécharger',
          style: TextStyle(color: Colors.white30, fontSize: 12)),
    ]));
}
