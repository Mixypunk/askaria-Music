import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../main.dart';
import '../../../models/album.dart';
import '../../../models/artist.dart';
import '../../../services/api_service.dart';
import '../../../providers/player_provider.dart';
import '../../../widgets/artwork_widget.dart';
import '../../downloads_screen.dart';
import '../../albums_screen.dart';
import '../../artist_screen.dart';
import 'timer_sheet.dart';

class SongMenuSheet {
  static void show(BuildContext ctx, PlayerProvider player, dynamic song, Color accent) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            color: const Color(0xFF282828).withOpacity(0.7),
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.radio_rounded, color: Colors.white70),
            title: const Text('Lancer la radio',
                style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(ctx); _startRadio(ctx, player, song); }),
          ListTile(
            leading: const Icon(Icons.download_rounded, color: Colors.white70),
            title: const Text('Télécharger',
                style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(ctx); _downloadSong(ctx, song); }),
          ListTile(
            leading: const Icon(Icons.queue_music_rounded, color: Colors.white70),
            title: const Text('Ajouter à la file',
                style: TextStyle(color: Colors.white)),
            onTap: () { player.addNextInQueue(song); Navigator.pop(ctx); }),
          ListTile(
            leading: Icon(
              player.isFavourite(song.hash)
                  ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: player.isFavourite(song.hash) ? accent : Colors.white70),
            title: Text(
              player.isFavourite(song.hash)
                  ? 'Retirer des favoris' : 'Ajouter aux favoris',
              style: const TextStyle(color: Colors.white)),
            onTap: () { player.toggleFavourite(song.hash); Navigator.pop(ctx); }),
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded,
                color: Colors.white70),
            title: const Text('Ajouter à une playlist',
              style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(ctx);
              showAddToPlaylist(ctx, song);
            }),
          ListTile(
            leading: Icon(Icons.bedtime_rounded,
              color: player.hasSleepTimer ? Colors.blueAccent : Colors.white70),
            title: Text(
              player.hasSleepTimer
                ? 'Timer sommeil : ${_fmtRemaining(player.sleepRemaining)}'
                : 'Timer de sommeil',
              style: TextStyle(
                color: player.hasSleepTimer ? Colors.blueAccent : Colors.white)),
            onTap: () {
              Navigator.pop(ctx);
              TimerSheet.show(ctx, player);
            }),
          ListTile(
            leading: const Icon(Icons.album_rounded, color: Colors.white70),
            title: const Text("Aller à l'album",
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(ctx);
              final album = Album(
                hash: song.albumHash,
                title: song.album,
                artist: song.artist,
                artistHash: song.artistHash,
                image: song.image ?? '',
              );
              Navigator.of(ctx).push(MaterialPageRoute(
                builder: (_) => AlbumScreen(album: album)));
            }),
          ListTile(
            leading: const Icon(Icons.person_rounded, color: Colors.white70),
            title: const Text("Aller à l'artiste",
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(ctx);
              final artist = Artist(
                hash: song.artistHash,
                name: song.artist,
                image: '${song.artistHash}.webp',
              );
              Navigator.of(ctx).push(MaterialPageRoute(
                builder: (_) => ArtistScreen(artist: artist)));
            }),
        ]),
          ),
        ),
      ),
    );
  }

  static String _fmtRemaining(Duration? d) {
    if (d == null) return '';
    if (d.inHours > 0) return '${d.inHours}h${d.inMinutes.remainder(60)}min';
    return '${d.inMinutes}min';
  }

  static Future<void> _startRadio(BuildContext ctx, PlayerProvider player, dynamic song) async {
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
      content: Text('Génération de la radio…'),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating));
    final tracks = await SwingApiService().getRadio(song.hash);
    if (tracks.isEmpty) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('Pas assez de titres pour la radio'),
        behavior: SnackBarBehavior.floating));
      return;
    }
    if (ctx.mounted) player.playSong(tracks.first, queue: tracks, index: 0);
  }

  static Future<void> _downloadSong(BuildContext ctx, dynamic song) async {
    final api = SwingApiService();
    final messenger = ScaffoldMessenger.of(ctx);
    messenger.showSnackBar(SnackBar(
      content: Text('Téléchargement de ${song.title}…'),
      duration: const Duration(seconds: 60),
      behavior: SnackBarBehavior.floating));
    final path = await api.downloadTrack(song);
    messenger.hideCurrentSnackBar();
    if (path != null) {
      messenger.showSnackBar(SnackBar(
        content: Text('${song.title} téléchargé !'),
        backgroundColor: Sp.card,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Voir',
          textColor: Sp.g2,
          onPressed: () => Navigator.push(ctx,
              MaterialPageRoute(builder: (_) => const DownloadsScreen())))));
    } else {
      messenger.showSnackBar(const SnackBar(
        content: Text('Échec du téléchargement'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating));
    }
  }

  static Future<void> showAddToPlaylist(BuildContext ctx, dynamic song) async {
    final player = ctx.read<PlayerProvider>();
    final playlists = await player.getCachedPlaylists();
    if (!ctx.mounted) return;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            color: const Color(0xFF282828).withOpacity(0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              Container(width: 36, height: 4, margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
              const Text('Ajouter à une playlist',
                style: TextStyle(color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.bold)),
            ])),
          const Divider(color: Colors.white12, height: 1),
          if (playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Aucune playlist disponible',
                style: TextStyle(color: Colors.white54)))
          else
            SizedBox(
              height: playlists.length > 4 ? 250 : null,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (_, i) {
                  final pl = playlists[i];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: NetImage(
                        url: '${SwingApiService().baseUrl}/img/playlist/${pl.id}.webp',
                        width: 44, height: 44,
                        headers: SwingApiService().authHeaders,
                        borderRadius: BorderRadius.circular(4),
                        placeholder: Container(width: 44, height: 44,
                          color: Sp.card, child: const Icon(
                              Icons.queue_music_rounded,
                              color: Colors.white38, size: 20)))),
                    title: Text(pl.name,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${pl.trackCount} titre${pl.trackCount != 1 ? "s" : ""}',
                      style: const TextStyle(color: Colors.white54,
                          fontSize: 12)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final ok = await SwingApiService()
                          .addTracksToPlaylist(pl.id, [song.hash]);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(ok
                            ? 'Ajouté à « ${pl.name} »'
                            : 'Erreur lors de l\'ajout'),
                          behavior: SnackBarBehavior.floating));
                      }
                    });
                },
              )),
          const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  );
  }

  static void showShareSheet(BuildContext ctx, dynamic song, Color accent) {
    final api   = SwingApiService();
    final url   = api.getStreamUrl(song.hash, filepath: song.filepath);
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            color: const Color(0xFF282828).withOpacity(0.7),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          Text(song.title, style: const TextStyle(color: Colors.white,
              fontSize: 16, fontWeight: FontWeight.bold)),
          Text(song.artist,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(6)),
            child: Text(url,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              maxLines: 2, overflow: TextOverflow.ellipsis)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _ShareBtn(Icons.copy_rounded, 'Copier le lien', () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                content: const Text('Lien copié dans le presse-papier !'),
                backgroundColor: accent,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2)));
            }),
            _ShareBtn(Icons.share_rounded, 'Partager', () {
              Navigator.pop(ctx);
              Share.share('${song.title} — ${song.artist}\n$url', subject: song.title);
            }),
            _ShareBtn(Icons.info_outline_rounded, 'Infos', () {
              Navigator.pop(ctx);
              showDialog(context: ctx, builder: (_) => AlertDialog(
                backgroundColor: const Color(0xFF282828),
                title: Text(song.title,
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
                content: Column(mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _InfoRow('Artiste', song.artist),
                  _InfoRow('Album',   song.album),
                  _InfoRow('Durée',
                    '${song.duration ~/ 60}:${(song.duration % 60).toString().padLeft(2,"0")}'),
                ]),
                actions: [TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Fermer', style: TextStyle(color: accent)))],
              ));
            }),
          ]),
            ]),
          ),
        ),
      ),
    );
  }

  static void showDevicesSheet(BuildContext ctx, Color accent) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            color: const Color(0xFF282828).withOpacity(0.7),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          const Text('Lecture sur', style: TextStyle(color: Colors.white,
              fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(contentPadding: EdgeInsets.zero,
            leading: Container(width: 44, height: 44,
              decoration: BoxDecoration(color: accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.phone_android_rounded, color: accent, size: 24)),
            title: const Text('Cet appareil',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text('Connecté', style: TextStyle(color: accent, fontSize: 12)),
            trailing: Icon(Icons.check_circle_rounded, color: accent, size: 20)),
        ]),
          ),
        ),
      ),
    );
  }
}

class _ShareBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ShareBtn(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 56, height: 56,
        decoration: const BoxDecoration(color: Colors.white12, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 26)),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 60, child: Text(label,
        style: const TextStyle(color: Colors.white54, fontSize: 13))),
      Expanded(child: Text(value,
        style: const TextStyle(color: Colors.white, fontSize: 13))),
    ]),
  );
}
