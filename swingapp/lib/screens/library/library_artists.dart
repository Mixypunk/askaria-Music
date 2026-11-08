part of '../library_tab.dart';

class _ArtistsList extends StatelessWidget {
  final List<Artist> artists;
  _ArtistsList({required this.artists});
  @override
  Widget build(BuildContext ctx) {
    if (artists.isEmpty) return _EmptyView(
      icon: Icons.person_rounded, label: 'Aucun artiste');
    return ListView.builder(
      padding: EdgeInsets.only(bottom: 120, top: 8),
      itemCount: artists.length,
      itemBuilder: (ctx, i) => _ArtistTile(artist: artists[i]),
    );
  }
}

class _ArtistTile extends StatelessWidget {
  final Artist artist;
  _ArtistTile({required this.artist});
  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: GestureDetector(
        onTap: () => Navigator.push(ctx, MaterialPageRoute(
          builder: (_) => ArtistScreen(artist: artist))),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: kCardDecoration(radius: 14),
          child: Row(children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle, gradient: kGrad),
              padding: EdgeInsets.all(2),
              child: ClipOval(child: NetImage(
                url: '${api.baseUrl}/img/artist/small/${artist.image}',
                width: 52, height: 52,
                headers: api.authHeaders,
                borderRadius: BorderRadius.circular(26),
                placeholder: Container(width: 52, height: 52, color: Sp.cardHi,
                  child: Icon(Icons.person, color: Sp.white40, size: 28))))),
            SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(artist.name, style: TextStyle(
                    color: Sp.white, fontWeight: FontWeight.w600, fontSize: 15),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: 3),
                Text(
                  '${artist.trackCount} titre${artist.trackCount != 1 ? "s" : ""}'
                  '${artist.albumCount > 0 ? " · ${artist.albumCount} album${artist.albumCount != 1 ? "s" : ""}" : ""}',
                  style: TextStyle(color: Sp.white70, fontSize: 12)),
              ])),
            Icon(Icons.chevron_right_rounded, color: Sp.white40, size: 20),
          ]),
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────
