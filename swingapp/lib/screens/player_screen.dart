import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../widgets/artwork_widget.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  int _tab = 0; // 0=player, 1=lyrics, 2=queue

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Consumer<PlayerProvider>(
        builder: (context, player, _) {
          final song = player.currentSong;
          if (song == null) {
            return const Center(child: Text('Aucune musique en cours'));
          }

          return SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text('En cours de lecture',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                )),
                          ],
                        ),
                      ),
                      // Tab switcher
                      Row(
                        children: [
                          _tabBtn(Icons.music_note_rounded, 0),
                          _tabBtn(Icons.lyrics_rounded, 1),
                          _tabBtn(Icons.queue_music_rounded, 2),
                        ],
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: [
                      _PlayerTab(player: player, song: song),
                      _LyricsTab(player: player),
                      _QueueTab(player: player),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tabBtn(IconData icon, int idx) {
    return IconButton(
      icon: Icon(icon),
      color: _tab == idx
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurfaceVariant,
      onPressed: () => setState(() => _tab = idx),
    );
  }
}

// ── PLAYER TAB ────────────────────────────────────────────────────────────────
class _PlayerTab extends StatelessWidget {
  final PlayerProvider player;
  final song;
  const _PlayerTab({required this.player, required this.song});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Big artwork
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: ArtworkWidget(
                  hash: song.hash,
                  size: double.infinity,
                  borderRadius: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Title & Artist
          Text(song.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(song.artist,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 24),
          // Progress slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: player.progress.clamp(0.0, 1.0),
              onChanged: (v) => player.seek(
                Duration(milliseconds: (v * player.duration.inMilliseconds).round()),
              ),
            ),
          ),
          // Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(player.position), style: const TextStyle(fontSize: 12)),
              Text(_fmt(player.duration), style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Shuffle
              IconButton(
                icon: Icon(Icons.shuffle_rounded,
                    color: player.shuffle
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant),
                onPressed: player.toggleShuffle,
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded),
                iconSize: 40,
                onPressed: player.previous,
              ),
              // Play/Pause
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: player.isLoading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : Icon(
                          player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                  iconSize: 40,
                  onPressed: player.playPause,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded),
                iconSize: 40,
                onPressed: player.next,
              ),
              // Repeat
              IconButton(
                icon: Icon(
                  player.repeatMode == RepeatMode.one
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  color: player.repeatMode != RepeatMode.off
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onPressed: player.toggleRepeat,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

// ── LYRICS TAB ───────────────────────────────────────────────────────────────
class _LyricsTab extends StatelessWidget {
  final PlayerProvider player;
  const _LyricsTab({required this.player});

  @override
  Widget build(BuildContext context) {
    if (player.lyricsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (player.lyrics == null || player.lyrics!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lyrics_outlined, size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text('Pas de paroles disponibles'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Text(
        player.lyrics!,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          height: 1.8,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── QUEUE TAB ─────────────────────────────────────────────────────────────────
class _QueueTab extends StatelessWidget {
  final PlayerProvider player;
  const _QueueTab({required this.player});

  @override
  Widget build(BuildContext context) {
    final queue = player.queue;
    if (queue.isEmpty) {
      return const Center(child: Text('File d\'attente vide'));
    }

    return ReorderableListView.builder(
      itemCount: queue.length,
      onReorder: player.reorderQueue,
      itemBuilder: (ctx, i) {
        final s = queue[i];
        final isCurrent = i == player.currentIndex;
        return ListTile(
          key: ValueKey(s.hash + i.toString()),
          leading: Text(
            '${i + 1}',
            style: TextStyle(
              color: isCurrent
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          title: Text(s.title,
              style: TextStyle(
                color: isCurrent ? Theme.of(context).colorScheme.primary : null,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          subtitle: Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: isCurrent
              ? Icon(Icons.equalizer_rounded,
                  color: Theme.of(context).colorScheme.primary)
              : IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                  onPressed: () => player.removeFromQueue(i),
                ),
          onTap: () => player.playSong(s, queue: queue, index: i),
        );
      },
    );
  }
}
