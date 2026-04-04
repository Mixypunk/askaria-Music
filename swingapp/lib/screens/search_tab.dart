import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/song.dart';
import '../models/album.dart';
import '../services/api_service.dart';
import '../providers/player_provider.dart';
import '../widgets/artwork_widget.dart';
import 'artist_screen.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});
  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> with AutomaticKeepAliveClientMixin {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  // Résultats par type
  List<Song>   _tracks  = [];
  List<Album>  _albums  = [];
  List<Artist> _artists = [];
  bool   _loading = false;
  String _query   = '';
  String? _activeCategory;

  static const _categories = [
    ('Tous',      Color(0xFF535353), Icons.apps_rounded,         ''),
    ('Hip-Hop',   Color(0xFFE8115B), Icons.headphones_rounded,   'hip hop'),
    ('Pop',       Color(0xFFE91429), Icons.star_rounded,          'pop'),
    ('Rock',      Color(0xFF148A08), Icons.electric_bolt_rounded, 'rock'),
    ('Électro',   Color(0xFF509BF5), Icons.graphic_eq_rounded,    'electro'),
    ('R&B',       Color(0xFFBA5D07), Icons.piano_rounded,         'rnb'),
    ('Jazz',      Color(0xFF0D73EC), Icons.music_note_rounded,    'jazz'),
    ('Classique', Color(0xFF7358FF), Icons.queue_music_rounded,   'classique'),
  ];

  bool get _hasResults =>
      _tracks.isNotEmpty || _albums.isNotEmpty || _artists.isNotEmpty;

  void _onChanged(String v) {
    _debounce?.cancel();
    if (v.trim().isEmpty && _activeCategory == null) {
      setState(() { _tracks = []; _albums = []; _artists = [];
                    _query = ''; _loading = false; });
      return;
    }
    setState(() { _loading = true; _query = v; });
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  void _selectCategory(String keyword) {
    if (_activeCategory == keyword) {
      setState(() => _activeCategory = null);
      _onChanged(_ctrl.text);
      return;
    }
    setState(() { _activeCategory = keyword; _loading = true; });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _search);
  }

  Future<void> _search() async {
    final base  = _ctrl.text.trim();
    final cat   = _activeCategory ?? '';
    final query = [base, cat].where((s) => s.isNotEmpty).join(' ');
    if (query.isEmpty) {
      setState(() { _tracks = []; _albums = []; _artists = []; _loading = false; });
      return;
    }

    try {
      // Lancer les 3 recherches en parallèle côté serveur
      final results = await Future.wait([
        SwingApiService().searchSongs(query),
        _searchAlbums(query),
        _searchArtists(query),
      ]).timeout(const Duration(seconds: 8));
      if (mounted) setState(() {
        _tracks  = results[0] as List<Song>;
        _albums  = results[1] as List<Album>;
        _artists = results[2] as List<Artist>;
        _loading = false;
      });
    } catch (_) {
      // Fallback local — filtrer la queue du player en mémoire
      if (mounted) _searchLocal(query);
    }
  }

  void _searchLocal(String query) {
    final q = query.toLowerCase();
    final player = context.read<PlayerProvider>();
    final allSongs = player.queue;
    final filtered = allSongs.where((s) =>
      s.title.toLowerCase().contains(q) ||
      s.artist.toLowerCase().contains(q) ||
      (s.album).toLowerCase().contains(q)
    ).toList();
    setState(() {
      _tracks  = filtered;
      _albums  = [];
      _artists = [];
      _loading = false;
    });
  }

  Future<List<Album>> _searchAlbums(String query) async {
    try {
      final data = await SwingApiService().searchTop(query);
      final raw = data['albums'] ?? [];
      if (raw is List && raw.isNotEmpty) {
        return raw.map((e) => Album.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Artist>> _searchArtists(String query) async {
    try {
      final data = await SwingApiService().searchTop(query);
      final raw = data['artists'] ?? [];
      if (raw is List && raw.isNotEmpty) {
        return raw.map((e) => Artist.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return CustomScrollView(slivers: [
      SliverAppBar(
        pinned: true,
        backgroundColor: Sp.bg,
        title: const Text('Rechercher',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: Sp.white)),
      ),

      // ── Barre de recherche ────────────────────────────────────
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(4)),
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
                border: InputBorder.none, isDense: true),
              onChanged: _onChanged,
            )),
            if (_ctrl.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _ctrl.clear();
                  _activeCategory = null;
                  _onChanged('');
                  _focus.unfocus();
                },
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.clear, color: Colors.black, size: 20))),
          ]),
        ),
      )),

      // ── Chips catégories ──────────────────────────────────────
      SliverToBoxAdapter(child: SizedBox(
        height: 36,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _categories.length,
          itemBuilder: (ctx, i) {
            final cat = _categories[i];
            final keyword = cat.$4;
            final isAll = keyword.isEmpty;
            final isActive = isAll
                ? _activeCategory == null
                : _activeCategory == keyword;
            return GestureDetector(
              onTap: () => isAll
                  ? _selectCategory('')
                  : _selectCategory(keyword),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isActive ? cat.$2 : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(cat.$3, size: 14,
                    color: isActive ? Colors.white : Sp.white70),
                  const SizedBox(width: 5),
                  Text(cat.$1, style: TextStyle(
                    color: isActive ? Colors.white : Sp.white70,
                    fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
            );
          },
        ),
      )),

      const SliverToBoxAdapter(child: SizedBox(height: 16)),

      // ── États ────────────────────────────────────────────────
      if (_loading)
        const SliverFillRemaining(child: Center(
          child: CircularProgressIndicator(color: Sp.g2, strokeWidth: 2)))

      else if (_hasResults) ...[
        // Artistes
        if (_artists.isNotEmpty) ...[
          _SectionTitle('Artistes'),
          SliverToBoxAdapter(child: SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _artists.length,
              itemBuilder: (ctx, i) => _ArtistChip(artist: _artists[i]),
            ),
          )),
        ],
        // Albums
        if (_albums.isNotEmpty) ...[
          _SectionTitle('Albums'),
          SliverToBoxAdapter(child: SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _albums.length,
              itemBuilder: (ctx, i) => _AlbumChip(album: _albums[i]),
            ),
          )),
        ],
        // Titres
        if (_tracks.isNotEmpty) ...[
          _SectionTitle('Titres'),
          SliverList(delegate: SliverChildBuilderDelegate(
            (ctx, i) => _TrackRow(
                song: _tracks[i], all: _tracks, idx: i),
            childCount: _tracks.length,
          )),
        ],
      ]

      else if (_query.isNotEmpty || _activeCategory != null)
        SliverFillRemaining(child: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, color: Sp.white40, size: 64),
            const SizedBox(height: 16),
            Text(
              _activeCategory != null && _query.isEmpty
                  ? 'Aucun résultat pour "$_activeCategory"'
                  : 'Aucun résultat pour "$_query"',
              style: const TextStyle(color: Sp.white70)),
          ],
        )))

      else
        SliverFillRemaining(child: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_rounded, color: Sp.white40, size: 64),
            const SizedBox(height: 16),
            const Text('Recherchez un titre, artiste ou album',
              style: TextStyle(color: Sp.white70)),
          ],
        ))),

      const SliverToBoxAdapter(child: SizedBox(height: 100)),
    ]);
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext ctx) => SliverToBoxAdapter(child: Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
    child: Text(title, style: const TextStyle(
        color: Sp.white, fontSize: 18, fontWeight: FontWeight.bold)),
  ));
}

class _ArtistChip extends StatelessWidget {
  final Artist artist;
  const _ArtistChip({required this.artist});
  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();
    return GestureDetector(
      onTap: () => Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => ArtistScreen(artist: artist))),
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: SizedBox(width: 80, child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipOval(child: Image.network(
              '${api.baseUrl}/img/artist/small/${artist.image}',
              width: 80, height: 80, fit: BoxFit.cover,
              headers: api.authHeaders,
              errorBuilder: (_, __, ___) => Container(
                width: 80, height: 80, color: Sp.card,
                child: const Icon(Icons.person,
                    color: Sp.white40, size: 36)))),
            const SizedBox(height: 6),
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

class _AlbumChip extends StatelessWidget {
  final Album album;
  const _AlbumChip({required this.album});
  @override
  Widget build(BuildContext ctx) {
    final api = SwingApiService();
    return GestureDetector(
      onTap: () => Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => AlbumScreen(album: album))),
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: SizedBox(width: 120, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                '${api.baseUrl}/img/thumbnail/${album.image}',
                width: 120, height: 120, fit: BoxFit.cover,
                headers: api.authHeaders,
                errorBuilder: (_, __, ___) => Container(
                  width: 120, height: 120, color: Sp.card,
                  child: const Icon(Icons.album,
                      color: Sp.white40, size: 40)))),
            const SizedBox(height: 6),
            Text(album.title,
              style: const TextStyle(color: Sp.white,
                  fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(album.artist,
              style: const TextStyle(color: Sp.white70, fontSize: 11),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        )),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  final Song song; final List<Song> all; final int idx;
  const _TrackRow({required this.song, required this.all, required this.idx});
  @override
  Widget build(BuildContext ctx) {
    final isCurrent = ctx.watch<PlayerProvider>().currentSong == song;
    return GestureDetector(
      onTap: () => ctx.read<PlayerProvider>()
          .playSong(song, queue: all, index: idx),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: ArtworkWidget(
              key: ValueKey(song.hash), hash: song.image ?? song.hash,
              size: 52, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(song.title, style: TextStyle(
                color: isCurrent ? Sp.g2 : Sp.white,
                fontSize: 15, fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(song.artist,
                style: const TextStyle(color: Sp.white70, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
          if (isCurrent)
            const GIcon(Icons.equalizer_rounded, size: 20),
        ]),
      ),
    );
  }
}
