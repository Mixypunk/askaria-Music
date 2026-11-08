part of '../library_tab.dart';

class _PlaylistsList extends StatelessWidget {
  final List<Playlist> playlists;
  final String? error;
  final Future<void> Function()? onRefresh;
  final void Function(String id)? onDeleted;
  _PlaylistsList({
    required this.playlists,
    this.error,
    this.onRefresh,
    this.onDeleted,
  });

  Future<void> _refresh() async {
    final cb = onRefresh;
    if (cb != null) await cb();
  }

  @override
  Widget build(BuildContext ctx) {
    return RefreshIndicator(
      color: Sp.g2,
      backgroundColor: Sp.card,
      onRefresh: _refresh,
      child: playlists.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 360,
                  child: error != null
                      ? _ErrorView(error: error!, onRetry: _refresh)
                      : _EmptyView(
                          icon: Icons.queue_music_rounded,
                          label: 'Aucune playlist'),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: 120, top: 8),
              itemCount: playlists.length,
              itemBuilder: (ctx, i) => _PlaylistTile(
                  playlist: playlists[i], onDeleted: onDeleted),
            ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final void Function(String id)? onDeleted;
  _PlaylistTile({required this.playlist, this.onDeleted});
  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.push(ctx, MaterialPageRoute(
            builder: (_) => PlaylistScreen(playlist: playlist)));
          if (result == 'deleted' && ctx.mounted) {
            onDeleted?.call(playlist.id);
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: kCardDecoration(radius: 14),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: NetImage(
                url: '${api.baseUrl}/img/playlist/${playlist.id}.webp',
                width: 56, height: 56,
                headers: api.authHeaders,
                borderRadius: BorderRadius.circular(10),
                placeholder: Container(width: 56, height: 56, color: Sp.cardHi,
                  child: Icon(Icons.queue_music_rounded,
                      color: Sp.white40, size: 28)))),
            SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(playlist.name, style: TextStyle(
                    color: Sp.white, fontWeight: FontWeight.w600, fontSize: 15),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: 3),
                Text(
                  'Playlist · ${playlist.trackCount} titre${playlist.trackCount != 1 ? "s" : ""}',
                  style: TextStyle(color: Sp.white70, fontSize: 12)),
              ])),
            Icon(Icons.chevron_right_rounded, color: Sp.white40, size: 20),
          ]),
        ),
      ),
    );
  }
}

// ── Albums ─────────────────────────────────────────────────────────────────────
