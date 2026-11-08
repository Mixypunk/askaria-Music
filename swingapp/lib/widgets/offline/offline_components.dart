import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models/album.dart' show Playlist;
import '../../models/song.dart';
import '../../services/api_service.dart';
import '../artwork_widget.dart';

/// Taille lisible (Ko / Mo / Go).
String formatOfflineSize(int bytes) {
  if (bytes <= 0) return '0 Ko';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} Ko';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} Go';
}

String formatOfflineDuration(int seconds) {
  if (seconds <= 0) return '';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

// ── Pastille « Hors connexion » ───────────────────────────────────────────────
class OfflinePill extends StatelessWidget {
  final String label;
  final IconData icon;
  const OfflinePill({
    super.key,
    this.label = 'Hors connexion',
    this.icon = Icons.cloud_off_rounded,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Sp.g2.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Sp.g2.withValues(alpha: 0.35)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: Sp.g2),
      const SizedBox(width: 5),
      Text(
        label,
        style: TextStyle(
          color: Sp.g2,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    ]),
  );
}

// ── En-tête de section ────────────────────────────────────────────────────────
class OfflineSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final int? count;
  final Widget? trailing;
  const OfflineSectionTitle({
    super.key,
    required this.title,
    required this.icon,
    this.count,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
    child: Row(children: [
      Icon(icon, color: Sp.white70, size: 16),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(
          color: Sp.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      if (count != null) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Sp.glass,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: Sp.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
      const Spacer(),
      if (trailing != null) trailing!,
    ]),
  );
}

// ── Carte de statistiques ─────────────────────────────────────────────────────
class OfflineStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const OfflineStat({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(children: [
      Icon(icon, size: 16, color: Sp.g2),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Sp.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Sp.white40, fontSize: 11),
            ),
          ],
        ),
      ),
    ]),
  );
}

// ── Carte playlist hors ligne ────────────────────────────────────────────────
class OfflinePlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final int? trackCount;
  final double width;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const OfflinePlaylistCard({
    super.key,
    required this.playlist,
    required this.onTap,
    this.trackCount,
    this.width = 132,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final api = SwingApiService();
    final cover = '${api.baseUrl}/img/playlist/${playlist.id}.webp';

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(fit: StackFit.expand, children: [
                NetImage(
                  url: cover,
                  width: width,
                  height: width,
                  cacheOnly: true,
                  headers: api.authHeaders,
                  borderRadius: BorderRadius.circular(16),
                  placeholder: Container(
                    decoration: BoxDecoration(
                      color: Sp.card,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.queue_music_rounded,
                      color: Sp.white40,
                      size: width * 0.32,
                    ),
                  ),
                ),
                // Voile + bouton lecture
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.35),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: kGrad,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Sp.g2.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                if (onDelete != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            playlist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Sp.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${trackCount ?? playlist.trackCount} titre${(trackCount ?? playlist.trackCount) > 1 ? 's' : ''}',
            style: TextStyle(color: Sp.white40, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Tuile titre hors ligne ───────────────────────────────────────────────────
class OfflineSongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool isCurrent;
  final bool playing;
  final Widget? trailing;

  const OfflineSongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.onDelete,
    this.isCurrent = false,
    this.playing = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (song.artist.isNotEmpty) song.artist,
      if (song.album.isNotEmpty) song.album,
    ].join(' · ');

    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: isCurrent ? Sp.g2.withValues(alpha: 0.10) : Sp.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCurrent ? Sp.g2.withValues(alpha: 0.45) : Sp.white12,
              width: 0.8,
            ),
          ),
          child: Row(children: [
            ArtworkWidget(
              key: ValueKey(song.hash),
              hash: song.image?.isNotEmpty == true ? song.image! : song.hash,
              size: 46,
              cacheOnly: true,
              borderRadius: BorderRadius.circular(9),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? Sp.g2 : Sp.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta.isEmpty ? 'Fichier local' : meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Sp.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (song.isLossless)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Sp.g2.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  song.audioFormat,
                  style: TextStyle(
                    color: Sp.g2,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            if (trailing != null)
              trailing!
            else
              Text(
                playing && isCurrent
                    ? ''
                    : formatOfflineDuration(song.duration),
                style: TextStyle(color: Sp.white40, fontSize: 11),
              ),
          ]),
        ),
      ),
    );

    if (onDelete == null) return tile;
    return Dismissible(
      key: ValueKey('offline_${song.hash}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.redAccent,
          size: 22,
        ),
      ),
      onDismissed: (_) => onDelete!(),
      child: tile,
    );
  }
}

// ── État vide ────────────────────────────────────────────────────────────────
class OfflineEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final List<Widget> actions;
  final IconData icon;

  const OfflineEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actions = const [],
    this.icon = Icons.cloud_off_rounded,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: Sp.g2.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(color: Sp.g2.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: Sp.g2, size: 38),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Sp.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Sp.white70, fontSize: 13, height: 1.45),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 24),
            ...actions,
          ],
        ],
      ),
    ),
  );
}

// ── Bouton secondaire (contour) ──────────────────────────────────────────────
class OfflineOutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const OfflineOutlineButton({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Sp.white12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Sp.white70),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Sp.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ]),
    ),
  );
}

// ── Bouton principal (dégradé) ───────────────────────────────────────────────
class OfflineGradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const OfflineGradientButton({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        gradient: kGrad,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Sp.g2.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ]),
    ),
  );
}
