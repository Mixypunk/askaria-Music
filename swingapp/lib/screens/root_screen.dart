import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/player_provider.dart';
import '../services/widget_service.dart';
import '../widgets/mini_player.dart';
import 'home_tab.dart';
import 'search_tab.dart';
import 'library_tab.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});
  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _tab = 0;

  final _tabs = const [HomeTab(), SearchTab(), LibraryTab()];

  DateTime? _lastBack;

  @override
  void initState() {
    super.initState();
    // Connecter les boutons du widget Android au PlayerProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = context.read<PlayerProvider>();
      WidgetService.instance.onAction = (action) {
        switch (action) {
          case 'prev': player.previous(); break;
          case 'play': player.playPause(); break;
          case 'next': player.next(); break;
        }
      };
      WidgetService.instance.startListening();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        // Double appui retour pour quitter
        final now = DateTime.now();
        if (_lastBack == null ||
            now.difference(_lastBack!) > const Duration(seconds: 2)) {
          _lastBack = now;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Appuyez encore une fois pour quitter'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ));
          return;
        }
        exit(0);
      },
      child: Scaffold(
      backgroundColor: Sp.bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim, child: child),
        child: KeyedSubtree(
          key: ValueKey(_tab),
          child: _tabs[_tab]),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          Container(
            color: Sp.bg,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 56,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _navItem(0, Icons.home_filled, Icons.home_outlined, 'Accueil'),
                    _navItem(1, Icons.search, Icons.search, 'Rechercher'),
                    _navItem(2, Icons.library_music, Icons.library_music_outlined, 'Bibliothèque'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _navItem(int idx, IconData active, IconData inactive, String label) {
    final sel = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          sel
              ? GIcon(active, size: 26)
              : Icon(inactive, size: 26, color: Sp.white70),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(
            fontSize: 10,
            color: sel ? Colors.white : Sp.white70,
            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
          )),
        ]),
      ),
    );
  }
}
