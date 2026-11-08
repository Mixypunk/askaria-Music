import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/album.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/downloads_provider.dart';
import '../widgets/offline/offline_components.dart';

enum _OfflineFilter { all, playlists, songs }

class DownloadsScreen extends StatefulWidget {
  DownloadsScreen({super.key});
  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final _searchCtrl = TextEditingController();
  _OfflineFilter _filter = _OfflineFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Actualiser les données hors-ligne au chargement
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DownloadsProvider>().refresh();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> _deleteSong(BuildContext ctx, Song song) async {
    await ctx.read<DownloadsProvider>().deleteSong(song.hash, song.filepath);
  }

  Future<void> _playPlaylist(DownloadsProvider dl, Playlist pl) async {
    final tracks = await dl.getOfflinePlaylistTracks(pl.id);
    if (!mounted) return;
    if (tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Aucun titre disponible pour « ${pl.name} »'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    context.read<PlayerProvider>().playSong(tracks.first, queue: tracks);
    Navigator.pop(context);
  }

  void _playSongs(List<Song> queue, {int index = 0, bool shuffle = false}) {
    if (queue.isEmpty) return;
    final songs = List<Song>.of(queue);
    if (shuffle) songs.shuffle();
    context.read<PlayerProvider>().playSong(
          songs[shuffle ? 0 : index.clamp(0, songs.length - 1)],
          queue: songs,
        );
    Navigator.pop(context);
  }

  Future<void> _deletePlaylist(BuildContext ctx, Playlist pl) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Sp.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Retirer la playlist',
            style: TextStyle(color: Sp.white, fontWeight: FontWeight.bold)),
        content: Text('Supprimer « ${pl.name} » du mode hors-ligne ?',
            style: TextStyle(color: Sp.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Annuler', style: TextStyle(color: Sp.white70))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Supprimer',
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok == true && ctx.mounted) {
      await ctx.read<DownloadsProvider>().unsyncPlaylist(pl.id);
    }
  }

  Future<void> _confirmDeleteAll(
      BuildContext ctx, DownloadsProvider dl, List<Song> songs) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Sp.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Tout supprimer',
            style: TextStyle(color: Sp.white, fontWeight: FontWeight.bold)),
        content: Text(
            'Supprimer ${songs.length} titre${songs.length > 1 ? 's' : ''} du mode hors-ligne ?',
            style: TextStyle(color: Sp.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Annuler', style: TextStyle(color: Sp.white70))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Supprimer',
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok == true) {
      for (final s in [...songs]) {
        await dl.deleteSong(s.hash, s.filepath);
      }
    }
  }

  // ── Filtrage ───────────────────────────────────────────────────────────────
  bool _matchesSong(Song s) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return s.title.toLowerCase().contains(q) ||
        s.artist.toLowerCase().contains(q) ||
        s.album.toLowerCase().contains(q);
  }

  bool _matchesPlaylist(Playlist p) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return p.name.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadsProvider>(
      builder: (ctx, dl, _) {
        final allSongs = List<Song>.of(dl.downloadedSongs)
          ..sort((a, b) =>
              a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        final allPlaylists = List<Playlist>.of(dl.downloadedPlaylists)
          ..sort((a, b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        final songs = allSongs.where(_matchesSong).toList();
        final playlists = allPlaylists.where(_matchesPlaylist).toList();

        final isEmpty = allSongs.isEmpty && allPlaylists.isEmpty;
        final showPlaylists =
            _filter != _OfflineFilter.songs && playlists.isNotEmpty;
        final showSongs = _filter != _OfflineFilter.playlists && songs.isNotEmpty;
        final noResult = !isEmpty && !showPlaylists && !showSongs;

        return Scaffold(
          backgroundColor: Sp.bg,
          appBar: AppBar(
            backgroundColor: Sp.bg,
            title: Text('Hors-ligne',
                style: TextStyle(
                    color: Sp.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: Sp.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (allSongs.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.delete_sweep_rounded,
                      color: Sp.white70, size: 22),
                  tooltip: 'Tout supprimer',
                  onPressed: () => _confirmDeleteAll(ctx, dl, allSongs),
                ),
            ],
          ),
          body: !dl.isReady
              ? Center(
                  child:
                      CircularProgressIndicator(color: Sp.g2, strokeWidth: 2))
              : isEmpty
                  ? OfflineEmptyState(
                      title: 'Aucun contenu hors-ligne',
                      message:
                          'Téléchargez des titres ou des playlists pour les '
                          'écouter sans connexion.\n\n'
                          'Depuis un titre ou une playlist, appuyez sur '
                          'l\'icône de téléchargement.',
                    )
                  : CustomScrollView(
                      slivers: [
                        // ── Résumé stockage + actions ─────────────────
                        SliverToBoxAdapter(
                          child: _OfflineStorageHeader(
                            songCount: allSongs.length,
                            playlistCount: allPlaylists.length,
                            totalBytes: dl.offlineBytes,
                            onPlayAll: () => _playSongs(allSongs),
                            onShuffle: () =>
                                _playSongs(allSongs, shuffle: true),
                          ),
                        ),

                        // ── Recherche + filtres ───────────────────────
                        if (allSongs.length + allPlaylists.length > 2)
                          SliverToBoxAdapter(child: _buildSearch(ctx)),
                        SliverToBoxAdapter(child: _buildFilters(allSongs.length,
                            allPlaylists.length)),

                        if (noResult)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: OfflineEmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'Aucun résultat',
                              message:
                                  'Rien ne correspond à « $_query » dans vos '
                                  'téléchargements.',
                              actions: [
                                OfflineOutlineButton(
                                  label: 'Effacer la recherche',
                                  icon: Icons.close_rounded,
                                  onTap: () {
                                    _searchCtrl.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                              ],
                            ),
                          ),

                        // ── Playlists ─────────────────────────────────
                        if (showPlaylists) ...[
                          SliverToBoxAdapter(
                            child: OfflineSectionTitle(
                              title: 'Playlists',
                              icon: Icons.queue_music_rounded,
                              count: playlists.length,
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.78,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (c, i) {
                                  final pl = playlists[i];
                                  return LayoutBuilder(
                                    builder: (c2, cons) => OfflinePlaylistCard(
                                      playlist: pl,
                                      width: cons.maxWidth,
                                      onTap: () => _playPlaylist(dl, pl),
                                      onDelete: () =>
                                          _deletePlaylist(ctx, pl),
                                    ),
                                  );
                                },
                                childCount: playlists.length,
                              ),
                            ),
                          ),
                        ],

                        // ── Titres ────────────────────────────────────
                        if (showSongs) ...[
                          SliverToBoxAdapter(
                            child: OfflineSectionTitle(
                              title: 'Titres',
                              icon: Icons.music_note_rounded,
                              count: songs.length,
                              trailing: songs.length > 1
                                  ? GestureDetector(
                                      onTap: () => _playSongs(songs),
                                      child: Row(mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.play_arrow_rounded,
                                                color: Sp.g2, size: 16),
                                            SizedBox(width: 2),
                                            Text('Tout lire',
                                                style: TextStyle(
                                                    color: Sp.g2,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ]),
                                    )
                                  : null,
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (c, i) {
                                  final song = songs[i];
                                  final isCurrent =
                                      c.select<PlayerProvider, bool>(
                                    (p) => p.currentSong?.hash == song.hash,
                                  );
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 7),
                                    child: OfflineSongTile(
                                      song: song,
                                      isCurrent: isCurrent,
                                      onTap: () =>
                                          _playSongs(songs, index: i),
                                      onDelete: () => _deleteSong(ctx, song),
                                    ),
                                  );
                                },
                                childCount: songs.length,
                              ),
                            ),
                          ),
                        ],

                        SliverToBoxAdapter(child: SizedBox(height: 40)),
                      ],
                    ),
        );
      },
    );
  }

  // ── Barre de recherche ─────────────────────────────────────────────────────
  Widget _buildSearch(BuildContext ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v.trim()),
          style: TextStyle(color: Sp.white, fontSize: 14),
          cursorColor: Sp.g2,
          decoration: InputDecoration(
            hintText: 'Rechercher dans le hors-ligne…',
            hintStyle: TextStyle(color: Sp.white40, fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, color: Sp.white40, size: 19),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: Sp.white40, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
            filled: true,
            fillColor: Sp.card,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Sp.white12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Sp.white12, width: 0.8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: Sp.g2.withValues(alpha: 0.6), width: 1.2),
            ),
          ),
        ),
      );

  // ── Filtres ────────────────────────────────────────────────────────────────
  Widget _buildFilters(int songCount, int playlistCount) => Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(children: [
          _FilterChip(
            label: 'Tout',
            count: songCount + playlistCount,
            selected: _filter == _OfflineFilter.all,
            onTap: () => setState(() => _filter = _OfflineFilter.all),
          ),
          SizedBox(width: 8),
          _FilterChip(
            label: 'Playlists',
            count: playlistCount,
            selected: _filter == _OfflineFilter.playlists,
            onTap: () => setState(() => _filter = _OfflineFilter.playlists),
          ),
          SizedBox(width: 8),
          _FilterChip(
            label: 'Titres',
            count: songCount,
            selected: _filter == _OfflineFilter.songs,
            onTap: () => setState(() => _filter = _OfflineFilter.songs),
          ),
        ]),
      );
}

// ── En-tête stockage ─────────────────────────────────────────────────────────
class _OfflineStorageHeader extends StatelessWidget {
  final int songCount;
  final int playlistCount;
  final int totalBytes;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;

  const _OfflineStorageHeader({
    required this.songCount,
    required this.playlistCount,
    required this.totalBytes,
    required this.onPlayAll,
    required this.onShuffle,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Sp.g1.withValues(alpha: 0.18),
              Sp.g2.withValues(alpha: 0.10),
            ],
          ),
          border: Border.all(color: Sp.g2.withValues(alpha: 0.22)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const OfflinePill(
                label: 'Disponible hors ligne',
                icon: Icons.offline_pin_rounded),
            const Spacer(),
          ]),
          SizedBox(height: 14),
          Row(children: [
            OfflineStat(
              icon: Icons.music_note_rounded,
              value: '$songCount',
              label: songCount > 1 ? 'titres' : 'titre',
            ),
            OfflineStat(
              icon: Icons.queue_music_rounded,
              value: '$playlistCount',
              label: playlistCount > 1 ? 'playlists' : 'playlist',
            ),
            OfflineStat(
              icon: Icons.sd_storage_rounded,
              value: formatOfflineSize(totalBytes),
              label: 'occupés',
            ),
          ]),
          if (songCount > 0) ...[
            SizedBox(height: 16),
            Row(children: [
              OfflineGradientButton(
                label: 'Lecture',
                icon: Icons.play_arrow_rounded,
                onTap: onPlayAll,
              ),
              SizedBox(width: 10),
              GestureDetector(
                onTap: onShuffle,
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Sp.glass,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Sp.white12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.shuffle_rounded, size: 16, color: Sp.white70),
                    SizedBox(width: 7),
                    Text('Aléatoire',
                        style: TextStyle(
                            color: Sp.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ],
        ]),
      );
}

// ── Filtre (pill) ────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? Sp.g2.withValues(alpha: 0.16) : Sp.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? Sp.g2.withValues(alpha: 0.55)
                  : Sp.white12,
              width: selected ? 1.1 : 0.8,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Sp.g2 : Sp.white70,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                color: selected ? Sp.g2.withValues(alpha: 0.8) : Sp.white40,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
        ),
      );
}
