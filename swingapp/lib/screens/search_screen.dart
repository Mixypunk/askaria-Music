import 'package:flutter/material.dart';
import '../main.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../widgets/song_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<Song> _results = [];
  bool _loading = false;
  String _query = '';

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) { setState(() { _results = []; _query = ''; }); return; }
    setState(() { _loading = true; _query = q; });
    try { _results = await SwingApiService().searchSongs(q); } catch (_) { _results = []; }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          floating: true,
          backgroundColor: AppColors.bg,
          titleSpacing: 16,
          title: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _ctrl,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Titres, artistes, albums...',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                        onPressed: () { _ctrl.clear(); _search(''); })
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                fillColor: Colors.transparent, filled: true,
              ),
              onChanged: (v) { if (v.length >= 2 || v.isEmpty) _search(v); setState(() {}); },
              onSubmitted: _search,
            ),
          ),
        ),
        if (_loading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: AppColors.grad2)))
        else if (_results.isEmpty && _query.isNotEmpty)
          SliverFillRemaining(child: Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const GradientIcon(Icons.search_off_rounded, size: 56),
              const SizedBox(height: 16),
              Text('Aucun résultat pour "$_query"',
                style: const TextStyle(color: AppColors.textSecondary)),
            ],
          )))
        else if (_results.isEmpty)
          SliverFillRemaining(child: Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const GradientIcon(Icons.search_rounded, size: 56),
              const SizedBox(height: 16),
              const Text('Cherche une musique, un artiste...',
                style: TextStyle(color: AppColors.textSecondary)),
            ],
          )))
        else
          SliverList(delegate: SliverChildBuilderDelegate(
            (ctx, i) => SongTile(song: _results[i], queue: _results, index: i),
            childCount: _results.length,
          )),
      ]),
    );
  }
}
