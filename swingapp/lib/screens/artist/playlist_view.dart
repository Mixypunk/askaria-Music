part of '../artist_screen.dart';

class PlaylistScreen extends StatefulWidget {
  final Playlist playlist;
  const PlaylistScreen({super.key, required this.playlist});
  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  late Playlist _playlist;
  List<Song> _tracks = [];
  bool _loading = true;
  bool _editing = false; // mode réorganisation

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _tracks = await SwingApiService().getPlaylistTracks(_playlist.id);
    } catch (e) { LoggerService.warning('Silent error caught in playlist_view.dart', e); }
    if (mounted) setState(() => _loading = false);
  }

  Duration get _totalDuration =>
      Duration(seconds: _tracks.fold(0, (s, t) => s + t.duration));

  String _fmtDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}min';
    return '${d.inMinutes}min';
  }

  // ── Actions ──────────────────────────────────────────────────────────────
  Future<void> _rename() async {
    final nameCtrl = TextEditingController(text: _playlist.name);
    final descCtrl = TextEditingController(text: _playlist.description ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Sp.card,
        title: const Text('Modifier la playlist',
          style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _DialogField(ctrl: nameCtrl, hint: 'Nom de la playlist',
              icon: Icons.title_rounded),
          const SizedBox(height: 12),
          _DialogField(ctrl: descCtrl, hint: 'Description (optionnel)',
              icon: Icons.notes_rounded),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: Text('Enregistrer',
              style: TextStyle(color: Sp.g2, fontWeight: FontWeight.bold))),
        ],
      ));
    if (confirmed != true) return;
    final ok = await SwingApiService().updatePlaylist(
      _playlist.id,
      name: nameCtrl.text.trim(),
      description: descCtrl.text.trim(),
    );
    if (ok && mounted) {
      setState(() {
        _playlist = Playlist(
          id: _playlist.id,
          name: nameCtrl.text.trim(),
          description: descCtrl.text.trim(),
          trackCount: _playlist.trackCount,
          imageHash: _playlist.imageHash,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playlist mise à jour'),
          behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Sp.card,
        title: const Text('Supprimer la playlist ?',
          style: TextStyle(color: Colors.white)),
        content: Text('« ${_playlist.name} » sera supprimée définitivement.',
          style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler',
              style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer',
              style: TextStyle(color: Colors.redAccent,
                  fontWeight: FontWeight.bold))),
        ],
      ));
    if (confirmed != true) return;
    final ok = await SwingApiService().deletePlaylist(_playlist.id);
    if (ok && mounted) {
      context.read<PlayerProvider>().invalidatePlaylistsCache();
      Navigator.pop(context, 'deleted');
    }
  }

  Future<void> _removeTrack(int index) async {
    final song = _tracks[index];
    setState(() => _tracks.removeAt(index));
    final ok = await SwingApiService()
        .removeTrackFromPlaylist(_playlist.id, song.hash, index);
    if (!ok && mounted) {
      setState(() => _tracks.insert(index, song));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la suppression'),
          behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    // Mise à jour optimiste immédiate
    final song = _tracks.removeAt(oldIndex);
    setState(() => _tracks.insert(newIndex, song));
    // Appel API — rollback si échec
    final ok = await SwingApiService()
        .reorderPlaylist(_playlist.id, oldIndex, newIndex);
    if (!ok && mounted) {
      // Rollback : remettre dans l'ordre original
      final s = _tracks.removeAt(newIndex);
      setState(() => _tracks.insert(oldIndex, s));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Erreur lors du réordonnancement'),
        behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _addTracks() async {
    final added = await Navigator.push<List<Song>>(
      context,
      MaterialPageRoute(
        builder: (_) => _AddTracksScreen(playlistId: _playlist.id,
            existingHashes: _tracks.map((s) => s.hash).toSet())));
    if (added != null && added.isNotEmpty) {
      setState(() => _tracks.addAll(added));
    }
  }

  void _play({required bool shuffle}) {
    if (_tracks.isEmpty) return;
    final p = context.read<PlayerProvider>();
    if (shuffle) p.toggleShuffle();
    p.playSong(_tracks.first, queue: _tracks, index: 0);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final api = SwingApiService();
    final imgUrl = '${api.baseUrl}/img/playlist/${_playlist.id}.webp';

    return Scaffold(
      backgroundColor: Sp.bg,
      body: CustomScrollView(slivers: [

        // ── Header ──────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          backgroundColor: Sp.bg,
          leading: IconButton(
            icon: Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(
                  color: Colors.black45, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18)),
            onPressed: () => Navigator.pop(context)),
          actions: [
            if (_tracks.isNotEmpty) ...[
              Consumer<DownloadsProvider>(
                builder: (ctx, dl, _) {
                  final toDownload = _tracks.where((s) => !dl.isDownloaded(s.hash)).length;
                  final isDone = toDownload == 0;
                  if (dl.isDownloadingPlaylist) {
                    return const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Center(child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
                      )),
                    );
                  }
                  if (isDone) {
                    return IconButton(
                      icon: const Icon(Icons.download_done_rounded, color: Colors.green, size: 22),
                      tooltip: 'Téléchargé',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Toute la playlist est hors-ligne'),
                          behavior: SnackBarBehavior.floating,
                        ));
                      },
                    );
                  }
                  return IconButton(
                    icon: const Icon(Icons.download_rounded, color: Colors.white70, size: 22),
                    tooltip: 'Télécharger',
                    onPressed: () => dl.downloadPlaylist(_tracks, context),
                  );
                },
              ),
            ],
            // Bouton réorganiser
            IconButton(
              icon: Icon(_editing
                  ? Icons.check_rounded
                  : Icons.drag_handle_rounded,
                color: _editing ? Sp.g2 : Colors.white70, size: 22),
              onPressed: () => setState(() => _editing = !_editing),
              tooltip: _editing ? 'Terminer' : 'Réorganiser',
            ),
            // Menu ⋯
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: Colors.white70, size: 22),
              color: Sp.card,
              onSelected: (v) {
                if (v == 'rename') _rename();
                if (v == 'delete') _delete();
                if (v == 'add')    _addTracks();
              },
              itemBuilder: (_) => [
                _menuItem('add',    Icons.add_rounded,          'Ajouter des titres'),
                _menuItem('rename', Icons.edit_rounded,         'Renommer / modifier'),
                _menuItem('delete', Icons.delete_outline_rounded,'Supprimer',
                    color: Colors.redAccent),
              ],
            ),
            const SizedBox(width: 4),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 56),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: NetImage(url: imgUrl, width: 150, height: 150,
                    headers: api.authHeaders,
                    borderRadius: BorderRadius.circular(8),
                    placeholder: Container(width: 150, height: 150,
                      color: Sp.card,
                      child: const Icon(Icons.queue_music_rounded,
                          color: Sp.white40, size: 60)))),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(_playlist.name,
                    style: const TextStyle(color: Sp.white, fontSize: 22,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ),

        // ── Infos + boutons ──────────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(children: [
            // Stats
            Text(
              '${_tracks.length} titre${_tracks.length != 1 ? "s" : ""}'
              '${_tracks.isNotEmpty ? " · ${_fmtDuration(_totalDuration)}" : ""}',
              style: const TextStyle(color: Sp.white70, fontSize: 13)),
            if (_playlist.description != null &&
                _playlist.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(_playlist.description!,
                style: const TextStyle(color: Sp.white70, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 16),

            if (!_loading) Row(children: [
              Expanded(child: _ActionBtn(
                icon: Icons.play_arrow_rounded,
                label: 'Lecture',
                filled: true,
                onTap: () => _play(shuffle: false))),
              const SizedBox(width: 12),
              Expanded(child: _ActionBtn(
                icon: Icons.shuffle_rounded,
                label: 'Aléatoire',
                filled: false,
                onTap: () => _play(shuffle: true))),
              const SizedBox(width: 12),
              // Bouton + rapide
              GestureDetector(
                onTap: _addTracks,
                child: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white30),
                    borderRadius: BorderRadius.circular(23)),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 22))),
            ]),
          ]),
        )),

        if (_loading)
          const SliverFillRemaining(child: Center(
            child: CircularProgressIndicator(color: Sp.g2, strokeWidth: 2)))

        else if (_tracks.isEmpty)
          SliverFillRemaining(child: Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.music_off_rounded,
                  color: Colors.white24, size: 64),
              const SizedBox(height: 16),
              const Text('Playlist vide',
                style: TextStyle(color: Colors.white54, fontSize: 16)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _addTracks,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: kGrad,
                    borderRadius: BorderRadius.circular(24)),
                  child: const Text('Ajouter des titres',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold)))),
            ],
          )))

        else if (_editing)
          // ── Mode réorganisation drag & drop ─────────────────────
          SliverToBoxAdapter(child: ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: _reorder,
            itemCount: _tracks.length,
            proxyDecorator: (child, idx, anim) => Material(
              color: Colors.transparent, child: child),
            itemBuilder: (ctx, i) => _EditableTrackRow(
              key: ValueKey(_tracks[i].hash + i.toString()),
              song: _tracks[i],
              index: i,
              onRemove: () => _removeTrack(i),
            ),
          ))

        else
          // ── Mode lecture normal ──────────────────────────────────
          SliverList(delegate: SliverChildBuilderDelegate(
            (ctx, i) => _TrackRow(
              song: _tracks[i],
              index: i + 1,
              all: _tracks,
              idx: i,
              onLongPress: () => _showTrackOptions(ctx, i),
              onTap: () => Navigator.pop(context)),
            childCount: _tracks.length,
          )),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ]),
    );
  }

  void _showTrackOptions(BuildContext ctx, int index) {
    final song = _tracks[index];
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Sp.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              ArtworkWidget(key: ValueKey(song.hash),
                hash: song.image ?? song.hash, size: 44,
                borderRadius: BorderRadius.circular(4)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title, style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(song.artist, style: const TextStyle(
                    color: Colors.white54, fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
            ]),
          ),
          const Divider(color: Colors.white12, height: 1),
          ListTile(
            leading: const Icon(Icons.play_arrow_rounded, color: Colors.white70),
            title: const Text('Lire à partir d\'ici',
              style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(ctx);
              context.read<PlayerProvider>()
                  .playSong(song, queue: _tracks, index: index);
              Navigator.pop(context);
            }),
          Consumer<DownloadsProvider>(
            builder: (ctx, dl, _) {
              final isDownloaded = dl.isDownloaded(song.hash);
              if (isDownloaded) {
                return ListTile(
                  leading: const Icon(Icons.download_done_rounded, color: Colors.green),
                  title: const Text('Supprimer le téléchargement',
                      style: TextStyle(color: Colors.redAccent)),
                  onTap: () { Navigator.pop(ctx); dl.deleteSong(song.hash, song.filepath); }
                );
              } else {
                return ListTile(
                  leading: const Icon(Icons.download_rounded, color: Colors.white70),
                  title: const Text('Télécharger',
                      style: TextStyle(color: Colors.white)),
                  onTap: () { Navigator.pop(ctx); dl.downloadSong(song, ctx); }
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.queue_music_rounded, color: Colors.white70),
            title: const Text('Ajouter à la file',
              style: TextStyle(color: Colors.white)),
            onTap: () {
              context.read<PlayerProvider>().addNextInQueue(song);
              Navigator.pop(ctx);
            }),
          ListTile(
            leading: const Icon(Icons.remove_circle_outline_rounded,
                color: Colors.redAccent),
            title: const Text('Retirer de la playlist',
              style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              Navigator.pop(ctx);
              _removeTrack(index);
            }),
        ]),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label,
      {Color? color}) =>
    PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, color: color ?? Colors.white70, size: 20),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(
            color: color ?? Colors.white, fontSize: 14)),
      ]));
}

// ── Ligne éditable (drag & drop + supprimer) ──────────────────────────────────
class _EditableTrackRow extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback onRemove;
  const _EditableTrackRow({super.key, required this.song,
      required this.index, required this.onRemove});
  @override
  Widget build(BuildContext ctx) => Container(
    color: Sp.bg,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Row(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle
        const Padding(
          padding: EdgeInsets.only(right: 8),
          child: Icon(Icons.drag_handle_rounded,
              color: Colors.white38, size: 22)),
        ArtworkWidget(key: ValueKey(song.hash),
          hash: song.image ?? song.hash, size: 44,
          borderRadius: BorderRadius.circular(4)),
      ]),
      title: Text(song.title, style: const TextStyle(
          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(song.artist, style: const TextStyle(
          color: Colors.white54, fontSize: 12),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        icon: const Icon(Icons.remove_circle_rounded,
            color: Colors.redAccent, size: 22),
        onPressed: onRemove),
    ),
  );
}

// ── Dialog field helper ──────────────────────────────────────────────────────
class _DialogField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  const _DialogField({required this.ctrl, required this.hint,
      required this.icon});
  @override
  Widget build(BuildContext ctx) => Container(
    decoration: BoxDecoration(color: Sp.bg,
        borderRadius: BorderRadius.circular(8)),
    child: TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 14)),
    ),
  );
}


// ── Écran tous les titres ──────────────────────────────────────────────────────
