import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../widgets/artwork_widget.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(builder: (ctx, player, _) {
      final history = player.history;
      final stats   = _computeStats(history);

      return Scaffold(
        backgroundColor: Sp.bg,
        appBar: AppBar(
          backgroundColor: Sp.bg,
          title: const Text('Statistiques',
            style: TextStyle(color: Sp.white,
                fontSize: 18, fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Sp.white, size: 20),
            onPressed: () => Navigator.pop(context))),
        body: history.isEmpty
            ? const _EmptyStats()
            : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [

          // ── Résumé ──────────────────────────────────────────
          const SizedBox(height: 8),
          Row(children: [
            _StatCard(
              label: 'Titres joués',
              value: '${history.length}',
              icon: Icons.music_note_rounded,
              color: Sp.g2),
            const SizedBox(width: 12),
            _StatCard(
              label: 'Artistes',
              value: '${stats.artistCount}',
              icon: Icons.person_rounded,
              color: Sp.g1),
            const SizedBox(width: 12),
            _StatCard(
              label: 'Écoute',
              value: _fmtTime(stats.totalMinutes),
              icon: Icons.schedule_rounded,
              color: Sp.g3),
          ]),
          const SizedBox(height: 28),

          // ── Top titres ──────────────────────────────────────
          if (stats.topTracks.isNotEmpty) ...[
            const _SectionHeader('Titres les plus joués'),
            ...stats.topTracks.take(5).toList().asMap().entries.map((e) =>
              _TopTrackRow(
                rank: e.key + 1,
                song: e.value.song,
                count: e.value.count,
                allSongs: history)),
            const SizedBox(height: 24),
          ],

          // ── Top artistes ────────────────────────────────────
          if (stats.topArtists.isNotEmpty) ...[
            const _SectionHeader('Artistes les plus écoutés'),
            ...stats.topArtists.take(5).map((a) =>
              _TopArtistRow(name: a.name, count: a.count,
                  percentage: a.count / history.length)),
            const SizedBox(height: 24),
          ],

          // ── Récemment joués ─────────────────────────────────
          const _SectionHeader('Récemment joués'),
          ...history.take(10).toList().asMap().entries.map((e) =>
            _HistoryRow(song: e.value, allSongs: history, idx: e.key)),
        ]),
      );
    });
  }

  _Stats _computeStats(List<Song> history) {
    // Compter par chanson
    final trackCounts = <String, _TrackStat>{};
    for (final s in history) {
      trackCounts[s.hash] ??= _TrackStat(song: s, count: 0);
      trackCounts[s.hash] = _TrackStat(
          song: s, count: trackCounts[s.hash]!.count + 1);
    }
    final topTracks = trackCounts.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    // Compter par artiste
    final artistCounts = <String, int>{};
    for (final s in history) {
      artistCounts[s.artist] = (artistCounts[s.artist] ?? 0) + 1;
    }
    final topArtists = artistCounts.entries
        .map((e) => _ArtistStat(name: e.key, count: e.value))
        .toList()..sort((a, b) => b.count.compareTo(a.count));

    // Durée totale (minutes)
    final totalSec = history.fold(0, (sum, s) => sum + s.duration);

    return _Stats(
      topTracks:   topTracks,
      topArtists:  topArtists,
      artistCount: artistCounts.length,
      totalMinutes: totalSec ~/ 60,
    );
  }

  String _fmtTime(int minutes) {
    if (minutes >= 60) return '${minutes ~/ 60}h${minutes % 60}';
    return '${minutes}min';
  }
}

// ── Data classes ───────────────────────────────────────────────────────────────
class _TrackStat  { final Song song; final int count;
  const _TrackStat({required this.song, required this.count}); }
class _ArtistStat { final String name; final int count;
  const _ArtistStat({required this.name, required this.count}); }
class _Stats {
  final List<_TrackStat>  topTracks;
  final List<_ArtistStat> topArtists;
  final int artistCount;
  final int totalMinutes;
  const _Stats({required this.topTracks, required this.topArtists,
      required this.artistCount, required this.totalMinutes});
}

// ── Widgets ────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value,
      required this.icon, required this.color});
  @override
  Widget build(BuildContext ctx) => Expanded(child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 10),
      Text(value, style: TextStyle(color: color,
          fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Sp.white70, fontSize: 11)),
    ]),
  ));
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext ctx) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title, style: const TextStyle(
        color: Sp.white, fontSize: 18, fontWeight: FontWeight.bold)));
}

class _TopTrackRow extends StatelessWidget {
  final int rank;
  final Song song;
  final int count;
  final List<Song> allSongs;
  const _TopTrackRow({required this.rank, required this.song,
      required this.count, required this.allSongs});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: () => ctx.read<PlayerProvider>()
        .playSong(song, queue: allSongs, index: allSongs.indexOf(song)),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 28, child: Text('$rank',
          style: TextStyle(color: rank <= 3 ? Sp.g2 : Sp.white70,
              fontWeight: FontWeight.bold, fontSize: 15),
          textAlign: TextAlign.center)),
        const SizedBox(width: 8),
        ArtworkWidget(key: ValueKey(song.hash), hash: song.image ?? song.hash,
          size: 44, borderRadius: BorderRadius.circular(4)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(song.title, style: const TextStyle(color: Sp.white,
                fontWeight: FontWeight.w500, fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(song.artist, style: const TextStyle(
                color: Sp.white70, fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        Text('$count×', style: TextStyle(
            color: count > 1 ? Sp.g2 : Sp.white40,
            fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _TopArtistRow extends StatelessWidget {
  final String name;
  final int count;
  final double percentage;
  const _TopArtistRow({required this.name, required this.count,
      required this.percentage});
  @override
  Widget build(BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(name, style: const TextStyle(
            color: Sp.white, fontSize: 14, fontWeight: FontWeight.w500),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
        Text('$count titre${count != 1 ? "s" : ""}',
          style: const TextStyle(color: Sp.white70, fontSize: 12)),
      ]),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: percentage.clamp(0.0, 1.0),
          backgroundColor: Colors.white12,
          valueColor: AlwaysStoppedAnimation(Sp.g2),
          minHeight: 3)),
    ]),
  );
}

class _HistoryRow extends StatelessWidget {
  final Song song;
  final List<Song> allSongs;
  final int idx;
  const _HistoryRow({required this.song, required this.allSongs,
      required this.idx});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: () => ctx.read<PlayerProvider>()
        .playSong(song, queue: allSongs, index: idx),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        ArtworkWidget(key: ValueKey(song.hash), hash: song.image ?? song.hash,
          size: 44, borderRadius: BorderRadius.circular(4)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(song.title, style: const TextStyle(color: Sp.white,
                fontWeight: FontWeight.w500, fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(song.artist, style: const TextStyle(
                color: Sp.white70, fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
      ]),
    ),
  );
}

class _EmptyStats extends StatelessWidget {
  const _EmptyStats();
  @override
  Widget build(BuildContext ctx) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: const [
      Icon(Icons.bar_chart_rounded, color: Colors.white24, size: 72),
      SizedBox(height: 16),
      Text('Pas encore de statistiques',
        style: TextStyle(color: Colors.white54, fontSize: 18,
            fontWeight: FontWeight.bold)),
      SizedBox(height: 8),
      Text('Commencez à écouter de la musique !',
        style: TextStyle(color: Colors.white30, fontSize: 13)),
    ],
  ));
}
