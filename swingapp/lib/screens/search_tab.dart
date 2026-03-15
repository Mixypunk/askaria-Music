import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../providers/player_provider.dart';
import '../widgets/artwork_widget.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});
  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  List<Song> _results = [];
  bool _loading = false;
  String _query  = '';
  Timer? _debounce;

  static const _categories = [
    ('Musique',   Color(0xFF4776E6), Icons.music_note_rounded),
    ('Podcasts',  Color(0xFF1DB954), Icons.podcasts_rounded),
    ('Hip-Hop',   Color(0xFFE8115B), Icons.headphones_rounded),
    ('Pop',       Color(0xFFE91429), Icons.star_rounded),
    ('Rock',      Color(0xFF148A08), Icons.electric_bolt_rounded),
    ('Électro',   Color(0xFF509BF5), Icons.graphic_eq_rounded),
    ('R&B',       Color(0xFFBA5D07), Icons.piano_rounded),
    ('Classique', Color(0xFF0D73EC), Icons.queue_music_rounded),
  ];

  // Debounce 400ms — évite une requête à chaque caractère
  void _onChanged(String v) {
    _debounce?.cancel();
    if (v.trim().isEmpty) {
      setState(() { _results = []; _query = ''; _loading = false; });
      return;
    }
    setState(() { _loading = true; _query = v; });
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(v));
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    try {
      final r = await SwingApiService().searchSongs(q);
      if (mounted && _query == q) setState(() { _results = r; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _results = []; _loading = false; });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: [
      SliverAppBar(
        pinned: true,
        backgroundColor: Sp.bg,
        title: const Text('Rechercher',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Sp.white)),
      ),

      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          height: 46,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
          child: Row(children: [
            const SizedBox(width: 12),
            const Icon(Icons.search, color: Colors.black, size: 22),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              style: const TextStyle(color: Colors.black, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Artistes, titres, albums',
                hintStyle: TextStyle(color: Color(0xFF666666)),
                border: InputBorder.none, isDense: true,
              ),
              onChanged: _onChanged,
            )),
            if (_ctrl.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _ctrl.clear();
                  _onChanged('');
                  _focus.unfocus();
                },
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.clear, color: Colors.black, size: 20))),
          ]),
        ),
      )),

      if (_loading)
        const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator(color: Sp.g2, strokeWidth: 2)))
      else if (_results.isNotEmpty)
        SliverList(delegate: SliverChildBuilderDelegate(
          (ctx, i) => _ResultRow(song: _results[i], all: _results, idx: i),
          childCount: _results.length,
        ))
      else if (_query.isNotEmpty)
        SliverFillRemaining(child: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, color: Sp.white40, size: 64),
            const SizedBox(height: 16),
            Text('Aucun résultat pour "$_query"',
              style: const TextStyle(color: Sp.white70)),
          ],
        )))
      else ...[
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: const Text('Parcourir les catégories',
            style: TextStyle(color: Sp.white, fontSize: 16, fontWeight: FontWeight.bold)),
        )),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, childAspectRatio: 2.8,
              mainAxisSpacing: 8, crossAxisSpacing: 8),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _CategoryCard(_categories[i]),
              childCount: _categories.length,
            ),
          ),
        ),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 100)),
    ]);
  }
}

class _CategoryCard extends StatelessWidget {
  final (String, Color, IconData) cat;
  const _CategoryCard(this.cat);
  @override
  Widget build(BuildContext ctx) => ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: Container(
      color: cat.$2,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        Expanded(child: Text(cat.$1,
          style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.bold, fontSize: 14))),
        Icon(cat.$3, color: Colors.white54, size: 36),
      ]),
    ),
  );
}

class _ResultRow extends StatelessWidget {
  final Song song; final List<Song> all; final int idx;
  const _ResultRow({required this.song, required this.all, required this.idx});
  @override
  Widget build(BuildContext ctx) {
    final isCurrent = ctx.watch<PlayerProvider>().currentSong == song;
    return GestureDetector(
      onTap: () => ctx.read<PlayerProvider>().playSong(song, queue: all, index: idx),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: ArtworkWidget(
              key: ValueKey(song.hash), hash: song.image ?? song.hash,
              size: 52, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(song.title, style: TextStyle(
              color: isCurrent ? Sp.g2 : Sp.white,
              fontSize: 15, fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(song.artist,
              style: const TextStyle(color: Sp.white70, fontSize: 13),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          if (isCurrent) const GIcon(Icons.equalizer_rounded, size: 20),
        ]),
      ),
    );
  }
}
