import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../screens/player_screen.dart';
import '../main.dart';
import 'artwork_widget.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerProvider, String?>(
      selector: (_, p) => p.currentSong?.hash,
      builder: (ctx, hash, _) {
        if (hash == null) return const SizedBox.shrink();
        return RepaintBoundary(child: _MiniPlayerShell(hash: hash));
      },
    );
  }
}

class _MiniPlayerShell extends StatelessWidget {
  final String hash;
  const _MiniPlayerShell({required this.hash});

  @override
  Widget build(BuildContext context) {
    final song = context.select<PlayerProvider, dynamic>((p) => p.currentSong);
    if (song == null) return const SizedBox.shrink();

    final accent = context.select<PlayerProvider, Color>(
        (p) => p.dynamicColors.accent);

    return GestureDetector(
      onTap: () => Navigator.push(context, PageRouteBuilder(
        pageBuilder: (_, a, __) => const PlayerScreen(),
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      )),
      onHorizontalDragEnd: (d) {
        if (d.primaryVelocity == null) return;
        final player = context.read<PlayerProvider>();
        if (d.primaryVelocity! < -300) player.next();
        if (d.primaryVelocity! >  300) player.previous();
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        height: 66,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: accent.withValues(alpha: 0.2), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(children: [
          // ── Barre de progression gradient ───────────────────────
          Positioned(bottom: 0, left: 0, right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(18)),
              child: RepaintBoundary(
                  child: _MiniProgressBar(accent: accent)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
            child: Row(children: [
              // Artwork arrondi
              RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ArtworkWidget(
                    key: ValueKey(song.hash),
                    hash: song.image ?? song.hash,
                    size: 48,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Titre / Artiste
              Expanded(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title,
                    style: const TextStyle(color: Colors.white,
                        fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(song.artist,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              )),

              // Like
              _MiniLikeBtn(hash: song.hash, accent: accent),

              // Play/Pause
              const _MiniPlayBtn(),

              // Next
              GestureDetector(
                onTap: () => context.read<PlayerProvider>().next(),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.skip_next_rounded,
                      color: Colors.white, size: 26))),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Progress bar gradient ──────────────────────────────────────────────────────
class _MiniProgressBar extends StatelessWidget {
  final Color accent;
  const _MiniProgressBar({required this.accent});
  @override
  Widget build(BuildContext context) {
    final progress = context.select<PlayerProvider, double>(
        (p) => p.progress.clamp(0.0, 1.0));
    return SizedBox(
      height: 2.5,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, Sp.g3],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bouton play/pause isolé ────────────────────────────────────────────────────
class _MiniPlayBtn extends StatelessWidget {
  const _MiniPlayBtn();
  @override
  Widget build(BuildContext context) {
    final isPlaying = context.select<PlayerProvider, bool>((p) => p.isPlaying);
    final isLoading = context.select<PlayerProvider, bool>((p) => p.isLoading);
    final accent = context.select<PlayerProvider, Color>(
        (p) => p.dynamicColors.accent);
    return GestureDetector(
      onTap: () => context.read<PlayerProvider>().playPause(),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: isLoading
            ? SizedBox(width: 28, height: 28,
                child: CircularProgressIndicator(
                    color: accent, strokeWidth: 2))
            : Icon(
                isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white, size: 32),
      ),
    );
  }
}

// ── Bouton like isolé ──────────────────────────────────────────────────────────
class _MiniLikeBtn extends StatelessWidget {
  final String hash;
  final Color accent;
  const _MiniLikeBtn({required this.hash, required this.accent});
  @override
  Widget build(BuildContext context) {
    final isFav = context.select<PlayerProvider, bool>(
        (p) => p.isFavourite(hash));
    return GestureDetector(
      onTap: () => context.read<PlayerProvider>().toggleFavourite(hash),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isFav ? Colors.redAccent : Colors.white38,
          size: 20),
      ),
    );
  }
}
