import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/api_service.dart';
import '../widgets/artwork_widget.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _period = 'all'; // all | week | month

  // Données chargées depuis le serveur
  Map<String, dynamic> _overview   = {};
  List<dynamic> _topTracks  = [];
  List<dynamic> _topArtists = [];
  List<dynamic> _history    = [];
  List<dynamic> _heatmap    = [];
  List<dynamic> _daily      = [];
  List<dynamic> _genres     = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = SwingApiService();
    final results = await Future.wait([
      api.getStatsOverview(),
      api.getTopTracks(limit: 10, period: _period),
      api.getTopArtists(limit: 10, period: _period),
      api.getHistory(limit: 30),
      api.getHeatmap(),
      api.getDailyStats(days: 7),
      api.getTopGenres(),
    ]);
    if (mounted) {
      setState(() {
        _overview   = results[0] as Map<String, dynamic>;
        _topTracks  = (results[1] as Map<String, dynamic>)['items'] ?? [];
        _topArtists = (results[2] as Map<String, dynamic>)['items'] ?? [];
        _history    = (results[3] as Map<String, dynamic>)['items'] ?? [];
        _heatmap    = results[4] as List<dynamic>;
        _daily      = results[5] as List<dynamic>;
        _genres     = results[6] as List<dynamic>;
        _loading = false;
      });
    }
  }

  Future<void> _setPeriod(String p) async {
    _period = p;
    final api = SwingApiService();
    final results = await Future.wait([
      api.getTopTracks(limit: 10, period: p),
      api.getTopArtists(limit: 10, period: p),
    ]);
    if (mounted) {
      setState(() {
        _topTracks  = results[0]['items'] ?? [];
        _topArtists = results[1]['items'] ?? [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Sp.bg,
      appBar: AppBar(
        backgroundColor: Sp.bg,
        title: const Text('Statistiques',
            style: TextStyle(color: Sp.white, fontSize: 18,
                fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Sp.white, size: 20),
          onPressed: () => Navigator.pop(context)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Sp.g2,
          labelColor: Sp.white,
          unselectedLabelColor: Sp.white70,
          tabs: const [
            Tab(text: 'Résumé'),
            Tab(text: 'Top'),
            Tab(text: 'Historique'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Sp.g2))
          : TabBarView(
              controller: _tabs,
              children: [
                _buildResume(),
                _buildTop(),
                _buildHistory(),
              ],
            ),
    );
  }

  // ── Onglet Résumé ────────────────────────────────────────────────────────
  Widget _buildResume() {
    final totalPlays  = _overview['total_plays']  ?? 0;
    final listenHours = _overview['listen_hours'] ?? 0.0;
    final totalSongs  = _overview['total_songs']  ?? 0;
    final totalAlbums = _overview['total_albums'] ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      color: Sp.g2,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Cards stats
          Row(children: [
            _StatCard('Lectures', '$totalPlays', Icons.play_circle_rounded, Sp.g2),
            const SizedBox(width: 10),
            _StatCard('Heures', '${listenHours}h', Icons.schedule_rounded, Sp.g1),
            const SizedBox(width: 10),
            _StatCard('Titres', '$totalSongs', Icons.music_note_rounded, Sp.g3),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _StatCard('Albums', '$totalAlbums',
                Icons.album_rounded, const Color(0xFF1DB954)),
            const SizedBox(width: 10),
            _StatCard('Artistes',
                '${_overview['total_artists'] ?? 0}',
                Icons.person_rounded, const Color(0xFFE8375A)),
            const SizedBox(width: 10),
            Expanded(child: const SizedBox()),
          ]),
          const SizedBox(height: 28),

          // Graphique écoutes 7 derniers jours
          if (_daily.isNotEmpty) ...[
            const _SectionTitle('Écoutes — 7 derniers jours'),
            const SizedBox(height: 12),
            _DailyChart(data: _daily),
            const SizedBox(height: 28),
          ],

          // Heatmap heures actives
          if (_heatmap.isNotEmpty) ...[
            const _SectionTitle('Heures les plus actives'),
            const SizedBox(height: 12),
            _Heatmap(data: _heatmap),
            const SizedBox(height: 28),
          ],

          // Top genres
          if (_genres.isNotEmpty) ...[
            const _SectionTitle('Genres favoris'),
            const SizedBox(height: 12),
            ..._genres.take(5).map((g) => _GenreBar(
              genre:  g['genre'] ?? '',
              plays:  g['plays'] ?? 0,
              maxPlays: (_genres.first['plays'] ?? 1) as int,
            )),
          ],
        ],
      ),
    );
  }

  // ── Onglet Top ───────────────────────────────────────────────────────────
  Widget _buildTop() {
    return Column(children: [
      // Sélecteur de période
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(children: [
          _PeriodChip('Tout', 'all', _period, _setPeriod),
          const SizedBox(width: 8),
          _PeriodChip('Ce mois', 'month', _period, _setPeriod),
          const SizedBox(width: 8),
          _PeriodChip('Cette semaine', 'week', _period, _setPeriod),
        ]),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            // Top titres
            if (_topTracks.isNotEmpty) ...[
              const _SectionTitle('Titres les plus joués'),
              const SizedBox(height: 8),
              ..._topTracks.asMap().entries.map((e) =>
                _TopTrackRow(rank: e.key + 1, data: e.value)),
              const SizedBox(height: 24),
            ],
            // Top artistes
            if (_topArtists.isNotEmpty) ...[
              const _SectionTitle('Artistes les plus écoutés'),
              const SizedBox(height: 8),
              ..._topArtists.asMap().entries.map((e) =>
                _TopArtistRow(
                  rank: e.key + 1,
                  name:  e.value['name']  ?? '',
                  plays: e.value['plays'] ?? 0,
                  maxPlays: (_topArtists.first['plays'] ?? 1) as int,
                )),
            ],
            if (_topTracks.isEmpty && _topArtists.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: Text('Aucune écoute sur cette période',
                    style: TextStyle(color: Sp.white40))),
              ),
          ],
        ),
      ),
    ]);
  }

  // ── Onglet Historique ─────────────────────────────────────────────────────
  Widget _buildHistory() {
    if (_history.isEmpty) {
      return const Center(child: Text('Aucun historique',
          style: TextStyle(color: Sp.white40)));
    }
    final player = context.read<PlayerProvider>();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _history.length,
      itemBuilder: (ctx, i) {
        final item = _history[i];
        final song = Song.fromJson(item as Map<String, dynamic>);
        final playedAt = item['played_at'] as String? ?? '';
        return _HistoryRow(
          song: song,
          playedAt: _fmtDate(playedAt),
          onTap: () => player.playSong(song,
            queue: _history.map((h) =>
              Song.fromJson(h as Map<String, dynamic>)).toList(),
            index: i),
        );
      },
    );
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60)  return 'il y a ${diff.inMinutes}min';
      if (diff.inHours  < 24)  return 'il y a ${diff.inHours}h';
      if (diff.inDays   < 7)   return 'il y a ${diff.inDays}j';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext ctx) => Expanded(child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.25))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(color: color,
          fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Sp.white70, fontSize: 10)),
    ]),
  ));
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext ctx) => Text(title, style: const TextStyle(
      color: Sp.white, fontSize: 16, fontWeight: FontWeight.bold));
}

class _DailyChart extends StatelessWidget {
  final List<dynamic> data;
  const _DailyChart({required this.data});
  @override
  Widget build(BuildContext ctx) {
    final maxVal = data.map((d) => (d['plays'] as int?) ?? 0)
        .fold(0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((d) {
          final plays  = (d['plays'] as int?) ?? 0;
          final date   = (d['date'] as String?) ?? '';
          final ratio  = maxVal > 0 ? plays / maxVal : 0.0;
          final day    = date.length >= 10 ? date.substring(8) : '';
          return Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (plays > 0) Text('$plays',
                  style: const TextStyle(color: Sp.white70, fontSize: 9)),
                const SizedBox(height: 2),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: (ratio * 52).clamp(3, 52),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [Sp.g1, Sp.g2]),
                    borderRadius: BorderRadius.circular(3))),
                const SizedBox(height: 4),
                Text(day, style: const TextStyle(
                    color: Sp.white40, fontSize: 9)),
              ],
            ),
          ));
        }).toList(),
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  final List<dynamic> data;
  const _Heatmap({required this.data});
  @override
  Widget build(BuildContext ctx) {
    final maxVal = data.map((d) => (d['plays'] as int?) ?? 0)
        .fold(0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 48,
      child: Row(
        children: data.map((d) {
          final plays = (d['plays'] as int?) ?? 0;
          final hour  = (d['hour']  as int?) ?? 0;
          final ratio = maxVal > 0 ? plays / maxVal : 0.0;
          return Expanded(child: Tooltip(
            message: '${hour}h : $plays écoutes',
            child: Container(
              margin: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: Color.lerp(
                  Colors.white.withValues(alpha: 0.04),
                  Sp.g2,
                  ratio,
                ),
                borderRadius: BorderRadius.circular(3)),
            ),
          ));
        }).toList(),
      ),
    );
  }
}

class _GenreBar extends StatelessWidget {
  final String genre;
  final int plays, maxPlays;
  const _GenreBar({required this.genre, required this.plays,
      required this.maxPlays});
  @override
  Widget build(BuildContext ctx) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(genre, style: const TextStyle(
            color: Sp.white, fontSize: 13, fontWeight: FontWeight.w500))),
        Text('$plays écoutes', style: const TextStyle(
            color: Sp.white70, fontSize: 11)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: maxPlays > 0 ? plays / maxPlays : 0,
          backgroundColor: Colors.white12,
          valueColor: AlwaysStoppedAnimation(Sp.g2),
          minHeight: 4)),
    ]),
  );
}

class _PeriodChip extends StatelessWidget {
  final String label, value, current;
  final void Function(String) onTap;
  const _PeriodChip(this.label, this.value, this.current, this.onTap);
  @override
  Widget build(BuildContext ctx) {
    final sel = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: sel ? kGrad : null,
          color: sel ? null : Sp.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel ? Colors.transparent : Colors.white12)),
        child: Text(label, style: TextStyle(
          color: sel ? Colors.white : Sp.white70,
          fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}

class _TopTrackRow extends StatelessWidget {
  final int rank;
  final dynamic data;
  const _TopTrackRow({required this.rank, required this.data});
  @override
  Widget build(BuildContext ctx) {
    final song  = Song.fromJson(data as Map<String, dynamic>);
    final plays = (data['user_plays'] as int?) ?? (data['play_count'] as int?) ?? 0;
    final player = ctx.read<PlayerProvider>();
    return GestureDetector(
      onTap: () => player.playSong(song),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(width: 26, child: Text('$rank',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: rank <= 3 ? Sp.g2 : Sp.white40,
              fontWeight: FontWeight.bold, fontSize: 14))),
          const SizedBox(width: 10),
          ArtworkWidget(key: ValueKey(song.hash),
              hash: song.image ?? song.hash, size: 42,
              borderRadius: BorderRadius.circular(4)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Sp.white,
                    fontWeight: FontWeight.w500, fontSize: 13)),
              Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Sp.white70, fontSize: 11)),
            ])),
          Text('$plays×', style: TextStyle(
            color: plays > 1 ? Sp.g2 : Sp.white40,
            fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _TopArtistRow extends StatelessWidget {
  final int rank, plays, maxPlays;
  final String name;
  const _TopArtistRow({required this.rank, required this.name,
      required this.plays, required this.maxPlays});
  @override
  Widget build(BuildContext ctx) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      SizedBox(width: 26, child: Text('$rank',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: rank <= 3 ? Sp.g2 : Sp.white40,
          fontWeight: FontWeight.bold, fontSize: 14))),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Sp.white,
                fontWeight: FontWeight.w500, fontSize: 13)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: maxPlays > 0 ? plays / maxPlays : 0,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(Sp.g2),
              minHeight: 3)),
        ])),
      const SizedBox(width: 12),
      Text('$plays', style: const TextStyle(
          color: Sp.white70, fontSize: 12, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _HistoryRow extends StatelessWidget {
  final Song song;
  final String playedAt;
  final VoidCallback onTap;
  const _HistoryRow({required this.song, required this.playedAt,
      required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        ArtworkWidget(key: ValueKey(song.hash),
            hash: song.image ?? song.hash, size: 44,
            borderRadius: BorderRadius.circular(4)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Sp.white,
                  fontWeight: FontWeight.w500, fontSize: 13)),
            Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Sp.white70, fontSize: 11)),
          ])),
        Text(playedAt, style: const TextStyle(
            color: Sp.white40, fontSize: 11)),
      ]),
    ),
  );
}
