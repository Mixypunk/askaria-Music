import 'package:flutter/material.dart';
import '../main.dart';
import 'songs_screen.dart';
import 'albums_screen.dart';
import 'artists_screen.dart';
import 'playlists_screen.dart';
import 'search_screen.dart';
import '../widgets/mini_player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _pages = [
    SongsScreen(), AlbumsScreen(), ArtistsScreen(), PlaylistsScreen(), SearchScreen(),
  ];

  static const _navItems = [
    (Icons.library_music_outlined, Icons.library_music_rounded, 'Musique'),
    (Icons.album_outlined,         Icons.album_rounded,         'Albums'),
    (Icons.people_outline_rounded, Icons.people_rounded,        'Artistes'),
    (Icons.queue_music_outlined,   Icons.queue_music_rounded,   'Playlists'),
    (Icons.search_rounded,         Icons.search_rounded,        'Recherche'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Sp.bg,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          Container(
            color: Sp.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(_navItems.length, (i) {
                    final item = _navItems[i];
                    final active = _index == i;
                    return GestureDetector(
                      onTap: () => setState(() => _index = i),
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: 64,
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          if (active)
                            ShaderMask(
                              shaderCallback: (b) => kGrad.createShader(b),
                              child: Icon(item.$2, size: 26, color: Colors.white),
                            )
                          else
                            Icon(item.$1, size: 24, color: Sp.white40),
                          const SizedBox(height: 4),
                          Text(item.$3, style: TextStyle(
                            fontSize: 10,
                            color: active ? Sp.g2 : Sp.white40,
                            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                          )),
                        ]),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
