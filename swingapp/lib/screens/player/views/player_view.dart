import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/player_provider.dart';
import '../../../widgets/artwork_widget.dart';
import '../sheets/song_menu_sheet.dart';

class PlayerView extends StatelessWidget {
  final PlayerProvider player;
  final dynamic song;
  final Color accent;
  final VoidCallback onLyricsTap;

  const PlayerView({
    super.key,
    required this.player,
    required this.song,
    required this.accent,
    required this.onLyricsTap
  });

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        const SizedBox(height: 8),

        // Artwork avec halo + swipe up → paroles
        Expanded(flex: 5, child: GestureDetector(
          onVerticalDragEnd: (d) {
            if (d.primaryVelocity != null && d.primaryVelocity! < -300) {
              onLyricsTap();
            }
          },
          child: Center(child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(
                color: accent.withOpacity(0.4), blurRadius: 50,
                offset: const Offset(0, 16), spreadRadius: 4)],
            ),
            child: AspectRatio(aspectRatio: 1, child: Hero(
              tag: 'artwork-${song.hash}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ArtworkWidget(
                  key: ValueKey(song.hash),
                  hash: song.image ?? song.hash,
                  size: double.infinity,
                  borderRadius: BorderRadius.circular(8)),
              ),
            )),
          )),
        )),
        const SizedBox(height: 6),

        // Hint "Voir les paroles"
        if (player.hasLyrics)
          GestureDetector(
            onTap: onLyricsTap,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.lyrics_rounded, size: 14, color: accent.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text('Voir les paroles', style: TextStyle(
                  color: accent.withOpacity(0.7), fontSize: 12)),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_up_rounded, size: 14,
                  color: accent.withOpacity(0.7)),
            ]),
          )
        else
          const SizedBox(height: 2),
        const SizedBox(height: 14),

        // Titre + like
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(song.title, style: const TextStyle(
                color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.bold, letterSpacing: -0.3),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
              // Badge lossless
              if (song.isLossless) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: accent.withOpacity(0.8), width: 1),
                    borderRadius: BorderRadius.circular(4)),
                  child: Text(song.audioFormat,
                    style: TextStyle(
                      color: accent, fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
                ),
              ],
            ]),
            const SizedBox(height: 4),
            Text(song.artist, style: TextStyle(
              color: Colors.white.withOpacity(0.7), fontSize: 15),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => player.toggleFavourite(song.hash),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                player.isFavourite(song.hash)
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                key: ValueKey(player.isFavourite(song.hash)),
                color: player.isFavourite(song.hash) ? accent : Colors.white70,
                size: 28,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 20),

        // Progress bar dynamique
        _ProgressBar(accent: accent),
        const SizedBox(height: 4),
        // Labels position/durée
        Selector<PlayerProvider, (Duration, Duration)>(
          selector: (_, p) => (p.position, p.duration),
          builder: (_, data, __) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(data.$1),
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
              Text(_fmt(data.$2),
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Contrôles
        Selector<PlayerProvider, (bool, bool, bool, RepeatMode)>(
          selector: (_, p) => (p.isPlaying, p.isLoading, p.shuffle, p.repeatMode),
          builder: (ctx2, data, _) {
            final isPlaying  = data.$1;
            final isLoading  = data.$2;
            final isShuffle  = data.$3;
            final repeatMode = data.$4;
            return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center, children: [
              GestureDetector(
                onTap: () => ctx2.read<PlayerProvider>().toggleShuffle(),
                child: Stack(alignment: Alignment.bottomCenter, children: [
                  Icon(Icons.shuffle_rounded, size: 26,
                    color: isShuffle ? accent : Colors.white.withValues(alpha: 0.6)),
                  if (isShuffle) Positioned(bottom: -4,
                    child: Container(width: 4, height: 4,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle))),
                ]),
              ),
              GestureDetector(
                onTap: () => ctx2.read<PlayerProvider>().previous(),
                child: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 46)),
              GestureDetector(
                onTap: () => ctx2.read<PlayerProvider>().playPause(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 68, height: 68,
                  decoration: BoxDecoration(
                    color: accent, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: accent.withValues(alpha: 0.5), blurRadius: 22, spreadRadius: 2)]),
                  child: Center(child: isLoading
                      ? const SizedBox(width: 26, height: 26,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white, size: 42)),
                ),
              ),
              GestureDetector(
                onTap: () => ctx2.read<PlayerProvider>().next(),
                child: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 46)),
              GestureDetector(
                onTap: () => ctx2.read<PlayerProvider>().toggleRepeat(),
                child: Stack(alignment: Alignment.bottomCenter, children: [
                  Icon(
                    repeatMode == RepeatMode.one
                        ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                    size: 26,
                    color: repeatMode != RepeatMode.off
                        ? accent : Colors.white.withValues(alpha: 0.6)),
                  if (repeatMode != RepeatMode.off) Positioned(bottom: -4,
                    child: Container(width: 4, height: 4,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle))),
                ]),
              ),
            ]);
          },
        ),
        const SizedBox(height: 20),

        // Slider volume
        Selector<PlayerProvider, double>(
          selector: (_, p) => p.volume,
          builder: (ctx2, vol, _) => Row(children: [
            Icon(
              vol == 0
                  ? Icons.volume_off_rounded
                  : vol < 0.5
                      ? Icons.volume_down_rounded
                      : Icons.volume_up_rounded,
              size: 18, color: Colors.white38),
            Expanded(child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: accent,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: accent.withValues(alpha: 0.2)),
              child: Slider(
                value: vol,
                onChanged: (v) => ctx2.read<PlayerProvider>().setVolume(v)),
            )),
            const Icon(Icons.volume_up_rounded, size: 18, color: Colors.white38),
          ]),
        ),
        const SizedBox(height: 6),

        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          GestureDetector(
            onTap: () => SongMenuSheet.showDevicesSheet(ctx, accent),
            child: Icon(Icons.devices_rounded, size: 20,
                color: Colors.white.withValues(alpha: 0.6))),
          Row(children: [
            GestureDetector(
              onTap: () => SongMenuSheet.showShareSheet(ctx, song, accent),
              child: Icon(Icons.share_rounded, size: 20,
                  color: Colors.white.withValues(alpha: 0.6))),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: () => SongMenuSheet.show(ctx, player, song, accent),
              child: Icon(Icons.more_horiz_rounded, size: 24,
                  color: Colors.white.withValues(alpha: 0.6))),
          ]),
        ]),
        const SizedBox(height: 12),
      ]),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final Color accent;
  const _ProgressBar({required this.accent});

  @override
  Widget build(BuildContext ctx) {
    return Selector<PlayerProvider, (Duration, Duration)>(
      selector: (_, p) => (p.position, p.duration),
      builder: (ctx, data, _) {
        final pos = data.$1;
        final dur = data.$2;
        final maxMs = dur.inMilliseconds.toDouble() > 0
            ? dur.inMilliseconds.toDouble()
            : 1.0;
        return SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: accent,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: accent.withValues(alpha: 0.2)),
          child: Slider(
            min: 0.0,
            max: maxMs,
            value: pos.inMilliseconds.toDouble().clamp(0.0, maxMs),
            onChanged: (v) => ctx.read<PlayerProvider>()
                .seek(Duration(milliseconds: v.round())),
          ),
        );
      },
    );
  }
}
