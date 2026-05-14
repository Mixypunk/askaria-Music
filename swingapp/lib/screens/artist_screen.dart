import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/song.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../providers/player_provider.dart';
import '../providers/downloads_provider.dart';
import '../services/api_service.dart';
import '../widgets/artwork_widget.dart';

class ArtistScreen extends StatefulWidget {
  final Artist artist;
  const ArtistScreen({super.key, required this.artist});
  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  List<Song>  _tracks = [];
  List<Album> _albums = [];
  bool _loading = true;
  final _scroll = ScrollController();
  double _headerOpacity = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(() {
      final opacity = (_scroll.offset / 200).clamp(0.0, 1.0);
      if ((opacity - _headerOpacity).abs() > 0.01) {
        setState(() => _headerOpacity = opacity);
      }
    });
  }

  Future<void> _load() async {
    var hash = widget.artist.hash;

    // Si le hash est vide, chercher l'artiste par nom
    if (hash.isEmpty && widget.artist.name.isNotEmpty) {
      final found = await SwingApiService()
          .searchArtistByName(widget.artist.name);
      if (found != null) hash = found.hash;
    }

    if (hash.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final results = await Future.wait([
      SwingApiService().getArtistTracks(hash),
      SwingApiService().getArtistAlbums(hash),
    ]);
    if (mounted) setState(() {
      _tracks = results[0] as List<Song>;
      _albums = results[1] as List<Album>;
      _loading = false;
    });
  }

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final api = SwingApiService();
    final imgUrl = '${api.baseUrl}/img/artist/small/${widget.artist.image}';

    return Scaffold(
      backgroundColor: Sp.bg,
      body: Stack(children: [

        // ── Contenu scrollable ─────────────────────────────────────
        CustomScrollView(
          controller: _scroll,
          slivers: [

            // ── Header grand format ──────────────────────────────
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              backgroundColor: Sp.bg,
              leading: IconButton(
                icon: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18)),
                onPressed: () => Navigator.pop(context)),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                title: Opacity(
                  opacity: _headerOpacity,
                  child: Text(widget.artist.name,
                    style: const TextStyle(color: Colors.white,
                        fontSize: 16, fontWeight: FontWeight.bold))),
                background: Stack(fit: StackFit.expand, children: [
                  NetImage(url: imgUrl, width: double.infinity, height: double.infinity,
                    headers: api.authHeaders,
                    placeholder: Container(color: Sp.card,
                      child: const Icon(Icons.person_rounded, color: Sp.white40, size: 80))),
                  // Dégradé bas
                  const DecoratedBox(decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Sp.bg],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.4, 1.0]))),
                ]),
              ),
            ),

            // ── Nom + stats ──────────────────────────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.artist.name,
                    style: const TextStyle(color: Sp.white,
                        fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.artist.trackCount} titre${widget.artist.trackCount != 1 ? 's' : ''}'
                    ' · ${widget.artist.albumCount} album${widget.artist.albumCount != 1 ? 's' : ''}',
                    style: const TextStyle(color: Sp.white70, fontSize: 13)),
                  const SizedBox(height: 16),

                  // Boutons Lecture / Aléatoire
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
                  ]),
                ]),
            )),

            if (_loading)
              const SliverFillRemaining(child: Center(
                child: CircularProgressIndicator(
                    color: Sp.g2, strokeWidth: 2)))
            else ...[

              // ── Titres populaires ────────────────────────────
              if (_tracks.isNotEmpty) ...[
                const _Header('Titres populaires'),
                SliverList(delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _TrackRow(
                    song: _tracks[i],
                    index: i + 1,
                    all: _tracks,
                    idx: i),
                  childCount: _tracks.length.clamp(0, 5),
                )),

                // "Voir tous les titres" si > 5
                if (_tracks.length > 5)
                  SliverToBoxAdapter(child: _SeeAllBtn(
                    label: 'Voir les ${_tracks.length} titres',
                    onTap: () => _showAllTracks(context))),
              ],

              // ── Albums ───────────────────────────────────────
              if (_albums.isNotEmpty) ...[
                const _Header('Albums'),
                SliverToBoxAdapter(child: SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _albums.length,
                    itemBuilder: (ctx, i) =>
                        _AlbumCard(album: _albums[i]),
                  ),
                )),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
        ),
      ]),
    );
  }

  void _play({required bool shuffle}) {
    if (_tracks.isEmpty) return;
    final p = context.read<PlayerProvider>();
    if (shuffle) p.toggleShuffle();
    p.playSong(_tracks.first, queue: _tracks, index: 0);
    Navigator.pop(context);
  }

  void _showAllTracks(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _AllTracksScreen(
          title: widget.artist.name, songs: _tracks)));
  }
}


// ── Page Playlist ──────────────────────────────────────────────────────────────
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
    } catch (_) {}
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
class _AllTracksScreen extends StatelessWidget {
  final String title;
  final List<Song> songs;
  const _AllTracksScreen({required this.title, required this.songs});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Sp.bg,
    appBar: AppBar(
      backgroundColor: Sp.bg,
      title: Text(title,
        style: const TextStyle(color: Sp.white,
            fontSize: 18, fontWeight: FontWeight.bold)),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Sp.white, size: 20),
        onPressed: () => Navigator.pop(context))),
    body: ListView.builder(
      itemCount: songs.length,
      itemBuilder: (ctx, i) => _TrackRow(
        song: songs[i], index: i + 1,
        all: songs, idx: i,
        onTap: () => Navigator.pop(context)),
    ),
  );
}

// ── Widgets communs ────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String title;
  const _Header(this.title);
  @override
  Widget build(BuildContext ctx) => SliverToBoxAdapter(child: Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
    child: Text(title, style: const TextStyle(
        color: Sp.white, fontSize: 20, fontWeight: FontWeight.bold)),
  ));
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label,
      required this.filled, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 46,
      decoration: BoxDecoration(
        gradient: filled ? kGrad : null,
        border: filled ? null : Border.all(color: Colors.white30),
        borderRadius: BorderRadius.circular(23)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ]),
    ),
  );
}

class _SeeAllBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SeeAllBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(4)),
        child: Center(child: Text(label,
          style: const TextStyle(
              color: Sp.white70, fontSize: 14, fontWeight: FontWeight.w500)))),
    ),
  );
}

class _TrackRow extends StatelessWidget {
  final Song song;
  final int index;
  final List<Song> all;
  final int idx;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const _TrackRow({required this.song, required this.index,
      required this.all, required this.idx, this.onTap, this.onLongPress});

  String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext ctx) {
    final player = ctx.watch<PlayerProvider>();
    final downloads = ctx.watch<DownloadsProvider>();
    final isCurrent = player.currentSong?.hash == song.hash;
    final isDownloaded = downloads.isDownloaded(song.hash);

    return GestureDetector(
      onTap: () {
        ctx.read<PlayerProvider>().playSong(song, queue: all, index: idx);
        onTap?.call();
      },
      onLongPress: onLongPress ?? () => _showSongMenu(ctx, song),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          // Numéro ou égaliseur
          SizedBox(width: 32, child: Center(
            child: isCurrent
                ? const GIcon(Icons.equalizer_rounded, size: 18)
                : Text('$index', style: TextStyle(
                    color: isCurrent ? Sp.g2 : Sp.white70, fontSize: 14)),
          )),
          const SizedBox(width: 8),
          // Artwork
          ArtworkWidget(
            key: ValueKey(song.hash),
            hash: song.image ?? song.hash,
            size: 46, borderRadius: BorderRadius.circular(4)),
          const SizedBox(width: 12),
          // Titre + artiste
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(song.title, style: TextStyle(
                color: isCurrent ? Sp.g2 : Sp.white,
                fontSize: 15, fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(song.artist,
                style: const TextStyle(color: Sp.white70, fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
          // Durée
          Row(children: [
            if (isDownloaded) ...[
              const Icon(Icons.download_done_rounded, size: 14, color: Colors.green),
              const SizedBox(width: 4),
            ],
            Text(_fmt(song.duration),
              style: const TextStyle(color: Sp.white40, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final Album album;
  const _AlbumCard({required this.album});
  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();
    final url = '${api.baseUrl}/img/thumbnail/${album.image}';
    return GestureDetector(
      onTap: () async {
        final tracks = await SwingApiService().getAlbumTracks(album.hash);
        if (ctx.mounted && tracks.isNotEmpty) {
          Navigator.push(ctx, MaterialPageRoute(
            builder: (_) => _AllTracksScreen(
                title: album.title, songs: tracks)));
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: SizedBox(width: 130, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: NetImage(url: url, width: 130, height: 130,
              headers: api.authHeaders,
              borderRadius: BorderRadius.circular(6),
              placeholder: Container(width: 130, height: 130, color: Sp.card,
                child: const Icon(Icons.album, color: Sp.white40, size: 40)))),
            const SizedBox(height: 8),
            Text(album.title,
              style: const TextStyle(color: Sp.white,
                  fontSize: 13, fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(album.year?.toString() ?? '',
              style: const TextStyle(color: Sp.white70, fontSize: 11)),
          ],
        )),
      ),
    );
  }
}

// ── Page Album détail ──────────────────────────────────────────────────────────
class AlbumScreen extends StatefulWidget {
  final Album album;
  const AlbumScreen({super.key, required this.album});
  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  List<Song> _tracks = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      _tracks = await SwingApiService().getAlbumTracks(widget.album.hash);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Duration get _totalDuration => Duration(
      seconds: _tracks.fold(0, (s, t) => s + t.duration));

  String _fmtDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}min';
    return '${d.inMinutes}min';
  }

  @override
  Widget build(BuildContext context) {
    final api = SwingApiService();
    final imgUrl = '${api.baseUrl}/img/thumbnail/${widget.album.image}';

    return Scaffold(
      backgroundColor: Sp.bg,
      body: CustomScrollView(slivers: [

        // ── Header ──────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 320,
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
          flexibleSpace: FlexibleSpaceBar(
            background: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                // Pochette
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 30, offset: const Offset(0, 10))]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: NetImage(url: imgUrl, width: 160, height: 160,
                  headers: api.authHeaders,
                  borderRadius: BorderRadius.circular(8),
                  placeholder: Container(width: 160, height: 160, color: Sp.card,
                    child: const Icon(Icons.album, color: Sp.white40, size: 64))))),
                const SizedBox(height: 16),
                // Titre
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(widget.album.title,
                    style: const TextStyle(color: Sp.white,
                        fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
                const SizedBox(height: 4),
                // Artiste + année
                Text(
                  widget.album.artist +
                  (widget.album.year != null
                      ? ' · ${widget.album.year}' : ''),
                  style: const TextStyle(color: Sp.white70, fontSize: 14)),
              ],
            ),
          ),
        ),

        // ── Infos + boutons ──────────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(children: [
            Text(
              '${_tracks.length} titre${_tracks.length != 1 ? 's' : ''}'
              '${_tracks.isNotEmpty ? ' · ${_fmtDuration(_totalDuration)}' : ''}',
              style: const TextStyle(color: Sp.white70, fontSize: 13)),
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
            ]),
          ]),
        )),

        if (_loading)
          const SliverFillRemaining(child: Center(
            child: CircularProgressIndicator(color: Sp.g2, strokeWidth: 2)))
        else if (_tracks.isEmpty)
          const SliverFillRemaining(child: Center(
            child: Text('Album vide',
                style: TextStyle(color: Sp.white70))))
        else
          SliverList(delegate: SliverChildBuilderDelegate(
            (ctx, i) => _TrackRow(
              song: _tracks[i],
              index: i + 1,
              all: _tracks,
              idx: i,
              onTap: () => Navigator.pop(context)),
            childCount: _tracks.length,
          )),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ]),
    );
  }

  void _play({required bool shuffle}) {
    if (_tracks.isEmpty) return;
    final p = context.read<PlayerProvider>();
    if (shuffle) p.toggleShuffle();
    p.playSong(_tracks.first, queue: _tracks, index: 0);
    Navigator.pop(context);
  }
}

// ── Écran ajout de titres à une playlist ──────────────────────────────────────
class _AddTracksScreen extends StatefulWidget {
  final String playlistId;
  final Set<String> existingHashes;
  const _AddTracksScreen({required this.playlistId,
      required this.existingHashes});
  @override
  State<_AddTracksScreen> createState() => _AddTracksScreenState();
}

class _AddTracksScreenState extends State<_AddTracksScreen> {
  final _ctrl = TextEditingController();
  List<Song> _results  = [];
  Set<String> _selected = {};
  bool _loading  = false;
  bool _saving   = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    if (v.trim().isEmpty) {
      setState(() { _results = []; _loading = false; });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(v));
  }

  Future<void> _search(String q) async {
    try {
      final r = await SwingApiService().searchSongs(q);
      if (mounted) setState(() { _results = r; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _results = []; _loading = false; });
    }
  }

  Future<void> _save() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);
    final ok = await SwingApiService()
        .addTracksToPlaylist(widget.playlistId, _selected.toList());
    if (!mounted) return;
    if (ok) {
      final added = _results.where((s) => _selected.contains(s.hash)).toList();
      Navigator.pop(context, added);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Erreur lors de l\'ajout'),
        behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Sp.bg,
      appBar: AppBar(
        backgroundColor: Sp.bg,
        title: const Text('Ajouter des titres',
          style: TextStyle(color: Colors.white,
              fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
        actions: [
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('Ajouter (${_selected.length})',
                        style: TextStyle(
                          color: Sp.g2, fontWeight: FontWeight.bold,
                          fontSize: 15)),
              ),
            ),
        ],
      ),
      body: Column(children: [
        // ── Barre de recherche ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(4)),
            child: Row(children: [
              const SizedBox(width: 12),
              const Icon(Icons.search, color: Colors.black, size: 22),
              const SizedBox(width: 8),
              Expanded(child: TextField(
                controller: _ctrl,
                autofocus: true,
                style: const TextStyle(color: Colors.black, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Rechercher un titre…',
                  hintStyle: TextStyle(color: Color(0xFF666666)),
                  border: InputBorder.none, isDense: true),
                onChanged: _onChanged,
              )),
              if (_ctrl.text.isNotEmpty)
                GestureDetector(
                  onTap: () { _ctrl.clear(); _onChanged(''); },
                  child: const Padding(padding: EdgeInsets.all(10),
                    child: Icon(Icons.clear, color: Colors.black, size: 20))),
            ]),
          ),
        ),

        // ── Chip "X sélectionné(s)" ───────────────────────────────
        if (_selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: kGrad,
                  borderRadius: BorderRadius.circular(16)),
                child: Text(
                  '${_selected.length} titre${_selected.length > 1 ? "s" : ""} sélectionné${_selected.length > 1 ? "s" : ""}',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 12, fontWeight: FontWeight.w600))),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _selected.clear()),
                child: const Text('Tout désélectionner',
                  style: TextStyle(color: Colors.white54, fontSize: 12))),
            ]),
          ),

        // ── Résultats ─────────────────────────────────────────────
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(
              color: Sp.g2, strokeWidth: 2))
          : _results.isEmpty && _ctrl.text.isNotEmpty
            ? const Center(child: Text('Aucun résultat',
                style: TextStyle(color: Colors.white54)))
            : _results.isEmpty
              ? const Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_rounded,
                        color: Colors.white24, size: 56),
                    SizedBox(height: 12),
                    Text('Tapez le nom d\'un titre',
                      style: TextStyle(color: Colors.white54)),
                  ]))
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (ctx, i) {
                    final song = _results[i];
                    final alreadyIn =
                        widget.existingHashes.contains(song.hash);
                    final selected = _selected.contains(song.hash);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      leading: Stack(children: [
                        ArtworkWidget(key: ValueKey(song.hash),
                          hash: song.image ?? song.hash, size: 48,
                          borderRadius: BorderRadius.circular(4)),
                        if (selected)
                          Positioned.fill(child: Container(
                            decoration: BoxDecoration(
                              color: Sp.g2.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4)),
                            child: const Icon(Icons.check_rounded,
                                color: Colors.white, size: 22))),
                        if (alreadyIn && !selected)
                          Positioned.fill(child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4)),
                            child: const Icon(Icons.check_rounded,
                                color: Colors.white38, size: 18))),
                      ]),
                      title: Text(song.title, style: TextStyle(
                        color: alreadyIn ? Colors.white38 : Colors.white,
                        fontSize: 14, fontWeight: FontWeight.w500),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        alreadyIn
                            ? '${song.artist} · Déjà dans la playlist'
                            : song.artist,
                        style: TextStyle(
                          color: alreadyIn
                              ? Colors.white24 : Colors.white54,
                          fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: alreadyIn
                          ? null
                          : Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.add_circle_outline_rounded,
                              color: selected ? Sp.g2 : Colors.white38,
                              size: 24),
                      onTap: alreadyIn ? null : () {
                        setState(() {
                          selected
                              ? _selected.remove(song.hash)
                              : _selected.add(song.hash);
                        });
                      },
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ── Menu rapide sur un titre (long press) ─────────────────────────────────────
void _showSongMenu(BuildContext ctx, Song song) {
  showModalBottomSheet(
    context: ctx,
    backgroundColor: const Color(0xFF282828),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _SongQuickMenu(song: song),
  );
}

class _SongQuickMenu extends StatefulWidget {
  final Song song;
  const _SongQuickMenu({required this.song});
  @override
  State<_SongQuickMenu> createState() => _SongQuickMenuState();
}

class _SongQuickMenuState extends State<_SongQuickMenu> {
  List<Playlist> _playlists = [];
  bool _loadingPl = true;

  @override
  void initState() {
    super.initState();
    // Utiliser le cache du provider au lieu d'appeler l'API directement
    context.read<PlayerProvider>().getCachedPlaylists().then((pl) {
      if (mounted) setState(() {
        _playlists = pl.cast();
        _loadingPl = false;
      });
    });
  }

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white24,
              borderRadius: BorderRadius.circular(2))),
        // Titre de la chanson
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            ArtworkWidget(key: ValueKey(widget.song.hash),
              hash: widget.song.image ?? widget.song.hash, size: 44,
              borderRadius: BorderRadius.circular(4)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.song.title, style: const TextStyle(
                  color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(widget.song.artist, style: const TextStyle(
                  color: Colors.white54, fontSize: 13),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
          ])),
        const Divider(color: Colors.white12, height: 1),
        ListTile(
          leading: const Icon(Icons.queue_music_rounded, color: Colors.white70),
          title: const Text('Ajouter à la file d\'attente',
            style: TextStyle(color: Colors.white)),
          onTap: () {
            ctx.read<PlayerProvider>().addNextInQueue(widget.song);
            Navigator.pop(context);
          }),
        // Ajouter à une playlist
        if (_loadingPl)
          const Padding(padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(
                color: Sp.g2, strokeWidth: 2)))
        else if (_playlists.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('AJOUTER À UNE PLAYLIST',
              style: TextStyle(color: Colors.white38, fontSize: 11,
                  letterSpacing: 1.2, fontWeight: FontWeight.w600))),
          ...(_playlists.take(5).map((pl) => ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 2),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: NetImage(
                url: '${SwingApiService().baseUrl}/img/playlist/${pl.id}.webp',
                width: 36, height: 36,
                headers: SwingApiService().authHeaders,
                borderRadius: BorderRadius.circular(4))),
            title: Text(pl.name, style: const TextStyle(
                color: Colors.white, fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () async {
              Navigator.pop(context);
              final ok = await SwingApiService()
                  .addTracksToPlaylist(pl.id, [widget.song.hash]);
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                  content: Text(ok
                    ? 'Ajouté à « ${pl.name} »'
                    : 'Erreur lors de l\'ajout'),
                  behavior: SnackBarBehavior.floating));
              }
            }))),
        ],
      ]),
    );
  }
}
