import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
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

class _RootScreenState extends State<RootScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0;
  final _tabs = const [HomeTab(), SearchTab(), LibraryTab()];
  DateTime? _lastBack;

  @override
  void initState() {
    super.initState();
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
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBack == null ||
            now.difference(_lastBack!) > const Duration(seconds: 2)) {
          _lastBack = now;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Appuyez encore une fois pour quitter'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Sp.card,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ));
          return;
        }
        exit(0);
      },
      child: Scaffold(
        backgroundColor: Sp.bg,
        // IndexedStack : tous les onglets restent montés en mémoire
        body: IndexedStack(index: _tab, children: _tabs),
        bottomNavigationBar: _BottomNav(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
        ),
      ),
    );
  }
}

// ── Bottom nav flottante ───────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  static const _items = [
    (Icons.home_rounded,       Icons.home_outlined,           'Accueil'),
    (Icons.search_rounded,     Icons.search_outlined,         'Rechercher'),
    (Icons.library_music_rounded, Icons.library_music_outlined, 'Bibliothèque'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MiniPlayer(),
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Sp.bg.withValues(alpha: 0.88),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 60,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(_items.length, (i) {
                      return _NavItem(
                        icon: _items[i].$1,
                        iconOutlined: _items[i].$2,
                        label: _items[i].$3,
                        selected: currentIndex == i,
                        onTap: () => onTap(i),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData iconOutlined;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.iconOutlined,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected ? Sp.glass : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            selected
                ? GIcon(icon, size: 24)
                : Icon(iconOutlined, size: 24, color: Sp.white40),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                color: selected ? Colors.white : Sp.white40,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
