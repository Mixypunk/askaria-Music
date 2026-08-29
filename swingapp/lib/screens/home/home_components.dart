part of '../home_tab.dart';

class _AvatarButton extends StatelessWidget {
  final String? avatarUrl;
  final String username;
  final VoidCallback onTap;
  const _AvatarButton({required this.avatarUrl, required this.username,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '';
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36, height: 36,
          decoration: const BoxDecoration(gradient: kGrad, shape: BoxShape.circle),
          padding: const EdgeInsets.all(2),
          child: ClipOval(
            child: SizedBox(
              width: 32, height: 32,
              child: avatarUrl != null
                  ? NetImage(
                      url: avatarUrl!, width: 32, height: 32,
                      circular: false,
                      headers: SwingApiService().authHeaders,
                      placeholder: _InitialFallback(initial))
                  : _InitialFallback(initial),
            ),
          ),
        ),
      ),
    );
  }
}

class _InitialFallback extends StatelessWidget {
  final String initial;
  const _InitialFallback(this.initial);
  @override
  Widget build(BuildContext context) => Container(
    color: Sp.card,
    child: initial.isEmpty
        ? const Icon(Icons.person_rounded, size: 18, color: Colors.white)
        : Center(child: Text(initial,
            style: const TextStyle(color: Colors.white,
                fontSize: 14, fontWeight: FontWeight.bold))),
  );
}

// ── Section header ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.icon, this.trailing});
  @override
  Widget build(BuildContext ctx) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 28, 16, 14),
    child: Row(children: [
      if (icon != null) ...[
        Icon(icon, color: Sp.white70, size: 16),
        const SizedBox(width: 8),
      ],
      Expanded(child: Text(title, style: const TextStyle(
        color: Sp.white, fontSize: 20, fontWeight: FontWeight.bold))),
      if (trailing != null) trailing!,
    ]),
  );
}

// ── Recent tile ────────────────────────────────────────────────────────────────
class _RecentTile extends StatelessWidget {
  final Song song; final List<Song> allSongs; final int idx;
  const _RecentTile({required this.song, required this.allSongs, required this.idx});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: () => ctx.read<PlayerProvider>()
        .playSong(song, queue: allSongs, index: idx),
    child: Container(
      width: 230,
      margin: const EdgeInsets.only(right: 10, bottom: 4),
      decoration: BoxDecoration(
        color: Sp.card, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        ClipRRect(
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
          child: ArtworkWidget(
            key: ValueKey(song.hash),
            hash: song.image ?? song.hash,
            size: 62,
            borderRadius: BorderRadius.zero),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(song.title,
          style: const TextStyle(color: Sp.white,
              fontSize: 13, fontWeight: FontWeight.w600),
          maxLines: 2, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
      ]),
    ),
  );
}

// ── Album card ─────────────────────────────────────────────────────────────────
class _AlbumCard extends StatelessWidget {
  final Album album;
  const _AlbumCard({required this.album});
  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();
    final url = api.getThumbnailUrl(album.image);
    return GestureDetector(
      onTap: () => _openAlbum(ctx),
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
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
                    child: const Icon(Icons.album, color: Sp.white40, size: 48))),
              ]),
            ),
            const SizedBox(height: 8),
            Text(album.title,
              style: const TextStyle(color: Sp.white,
                  fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(album.artist,
              style: const TextStyle(color: Sp.white70, fontSize: 12),
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
  const _ArtistCard({required this.artist});
  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();
    final url = '${api.baseUrl}/img/artist/small/${artist.image}';
    return GestureDetector(
      onTap: () => Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => ArtistScreen(artist: artist))),
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: SizedBox(width: 90, child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: kGrad,
              ),
              padding: const EdgeInsets.all(2),
              child: ClipOval(child: NetImage(
                url: url, width: 86, height: 86,
                headers: api.authHeaders,
                circular: true,
                placeholder: Container(width: 86, height: 86, color: Sp.card,
                  child: const Icon(Icons.person, color: Sp.white40, size: 40)),
              )),
            ),
            const SizedBox(height: 8),
            Text(artist.name,
              style: const TextStyle(color: Sp.white,
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
  const _SongRow({required this.song, required this.all,
      required this.idx, required this.index});
  @override
  Widget build(BuildContext ctx) {
    final isCurrent = ctx.select<PlayerProvider, bool>(
        (p) => p.currentSong?.hash == song.hash);
    return GestureDetector(
      onTap: () => ctx.read<PlayerProvider>()
          .playSong(song, queue: all, index: idx),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(children: [
          // Numéro de piste ou equalizer
          SizedBox(
            width: 24,
            child: isCurrent
                ? const GIcon(Icons.equalizer_rounded, size: 18)
                : Text('${index + 1}',
                    style: const TextStyle(color: Sp.white40, fontSize: 13),
                    textAlign: TextAlign.center),
          ),
          const SizedBox(width: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ArtworkWidget(
              key: ValueKey(song.hash), hash: song.image ?? song.hash,
              size: 50, borderRadius: BorderRadius.circular(8)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(song.title, style: TextStyle(
                color: isCurrent ? Sp.g2 : Sp.white,
                fontSize: 15, fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(song.artist,
                style: const TextStyle(color: Sp.white70, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
          const Icon(Icons.more_horiz, color: Sp.white40, size: 20),
        ]),
      ),
    );
  }
}

// ── All songs screen ───────────────────────────────────────────────────────────
