part of '../home_tab.dart';

class _AvatarButton extends StatelessWidget {
  final int userId;
  final String username;
  final VoidCallback onTap;
  _AvatarButton({required this.userId, required this.username,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Center(
    child: GestureDetector(
      onTap: onTap,
      child: AvatarImage(
        userId: userId,
        username: username,
        size: 36,
      ),
    ),
  );
}

// ── Section header ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;
  _SectionHeader({required this.title, this.icon, this.trailing});
  @override
  Widget build(BuildContext ctx) => Padding(
    padding: EdgeInsets.fromLTRB(16, 28, 16, 14),
    child: Row(children: [
      if (icon != null) ...[
        Icon(icon, color: Sp.white70, size: 16),
        SizedBox(width: 8),
      ],
      Expanded(child: Text(title, style: TextStyle(
        color: Sp.white, fontSize: 20, fontWeight: FontWeight.bold))),
      if (trailing != null) trailing!,
    ]),
  );
}

// ── Recent tile ────────────────────────────────────────────────────────────────
class _RecentTile extends StatelessWidget {
  final Song song; final List<Song> allSongs; final int idx;
  final bool cacheOnly;
  _RecentTile({required this.song, required this.allSongs, required this.idx,
      this.cacheOnly = false});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: () => ctx.read<PlayerProvider>()
        .playSong(song, queue: allSongs, index: idx),
    child: Container(
      width: 230,
      margin: EdgeInsets.only(right: 10, bottom: 4),
      decoration: BoxDecoration(
        color: Sp.card, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
          child: ArtworkWidget(
            key: ValueKey(song.hash),
            hash: song.image ?? song.hash,
            size: 62,
            cacheOnly: cacheOnly,
            borderRadius: BorderRadius.zero),
        ),
        SizedBox(width: 10),
        Expanded(child: Text(song.title,
          style: TextStyle(color: Sp.white,
              fontSize: 13, fontWeight: FontWeight.w600),
          maxLines: 2, overflow: TextOverflow.ellipsis)),
        SizedBox(width: 8),
      ]),
    ),
  );
}

// ── Album card ─────────────────────────────────────────────────────────────────
class _AlbumCard extends StatelessWidget {
  final Album album;
  _AlbumCard({required this.album});
  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();
    final url = api.getThumbnailUrl(album.image);
    return GestureDetector(
      onTap: () => _openAlbum(ctx),
      child: Padding(
        padding: EdgeInsets.only(right: 14),
        child: SizedBox(width: 148, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(children: [
                NetImage(url: url, width: 148, height: 148,
                  headers: url.startsWith(api.baseUrl) ? api.authHeaders : {},
                  borderRadius: BorderRadius.circular(14),
                  placeholder: Container(width: 148, height: 148, color: Sp.card,
                    child: Icon(Icons.album, color: Sp.white40, size: 48))),
              ]),
            ),
            SizedBox(height: 8),
            Text(album.title,
              style: TextStyle(color: Sp.white,
                  fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(album.artist,
              style: TextStyle(color: Sp.white70, fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        )),
      ),
    );
  }

  void _openAlbum(BuildContext ctx) {
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => AlbumScreen(album: album)));
  }
}

// ── Artist card ────────────────────────────────────────────────────────────────
class _ArtistCard extends StatelessWidget {
  final Artist artist;
  _ArtistCard({required this.artist});
  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();
    final url = '${api.baseUrl}/img/artist/small/${artist.image}';
    return GestureDetector(
      onTap: () => Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => ArtistScreen(artist: artist))),
      child: Padding(
        padding: EdgeInsets.only(right: 16),
        child: SizedBox(width: 90, child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: kGrad,
              ),
              padding: EdgeInsets.all(2),
              child: ClipOval(child: NetImage(
                url: url, width: 86, height: 86,
                headers: api.authHeaders,
                circular: true,
                placeholder: Container(width: 86, height: 86, color: Sp.card,
                  child: Icon(Icons.person, color: Sp.white40, size: 40)),
              )),
            ),
            SizedBox(height: 8),
            Text(artist.name,
              style: TextStyle(color: Sp.white,
                  fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 2, overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
          ],
        )),
      ),
    );
  }
}

// ── Song row ───────────────────────────────────────────────────────────────────
class _SongRow extends StatelessWidget {
  final Song song; final List<Song> all; final int idx; final int index;
  _SongRow({required this.song, required this.all,
      required this.idx, required this.index});
  @override
  Widget build(BuildContext ctx) {
    final isCurrent = ctx.select<PlayerProvider, bool>(
        (p) => p.currentSong?.hash == song.hash);
    return GestureDetector(
      onTap: () => ctx.read<PlayerProvider>()
          .playSong(song, queue: all, index: idx),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(children: [
          // Numéro de piste ou equalizer
          SizedBox(
            width: 24,
            child: isCurrent
                ? GIcon(Icons.play_arrow_rounded, size: 18)
                : Text('${index + 1}',
                    style: TextStyle(color: Sp.white40, fontSize: 13),
                    textAlign: TextAlign.center),
          ),
          SizedBox(width: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ArtworkWidget(
              key: ValueKey(song.hash), hash: song.image ?? song.hash,
              size: 50, borderRadius: BorderRadius.circular(8)),
          ),
          SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(song.title, style: TextStyle(
                color: isCurrent ? Sp.g2 : Sp.white,
                fontSize: 15, fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              SizedBox(height: 2),
              Text(song.artist,
                style: TextStyle(color: Sp.white70, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
          Icon(Icons.more_horiz, color: Sp.white40, size: 20),
        ]),
      ),
    );
  }
}

// ── All songs screen ───────────────────────────────────────────────────────────
