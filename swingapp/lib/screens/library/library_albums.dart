part of '../library_tab.dart';

class _AlbumsList extends StatelessWidget {
  final List<Album> albums;
  const _AlbumsList({required this.albums});
  @override
  Widget build(BuildContext ctx) {
    if (albums.isEmpty) return const _EmptyView(
      icon: Icons.album_rounded, label: 'Aucun album');
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120, top: 8),
      itemCount: albums.length,
      itemBuilder: (ctx, i) => _AlbumTile(album: albums[i]),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  final Album album;
  const _AlbumTile({required this.album});
  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();
    final url = api.getThumbnailUrl(album.image);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: GestureDetector(
        onTap: () => Navigator.push(ctx, MaterialPageRoute(
          builder: (_) => AlbumScreen(album: album))),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: kCardDecoration(radius: 14),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: NetImage(
                url: url,
                width: 56, height: 56,
                headers: url.startsWith(api.baseUrl) ? api.authHeaders : {},
                borderRadius: BorderRadius.circular(10),
                placeholder: Container(width: 56, height: 56, color: Sp.cardHi,
                  child: const Icon(Icons.album, color: Colors.white38, size: 28)))),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(album.title, style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  '${album.artist}${album.year != null ? " · ${album.year}" : ""}',
                  style: const TextStyle(color: Sp.white70, fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
            const Icon(Icons.chevron_right_rounded, color: Sp.white40, size: 20),
          ]),
        ),
      ),
    );
  }
}

// ── Artistes ───────────────────────────────────────────────────────────────────
