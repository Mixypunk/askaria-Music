import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../providers/player_provider.dart';
import '../widgets/song_tile.dart';

class SongsScreen extends StatefulWidget {
  const SongsScreen({super.key});
  @override
  State<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends State<SongsScreen> {
  List<Song> _songs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try { _songs = await SwingApiService().getSongs(limit: 500); }
    catch (e) { _error = e.toString(); }
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
          title: GradientText('Ma Musique',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          actions: [
            if (_songs.isNotEmpty)
              IconButton(
                icon: const GradientIcon(Icons.play_circle_fill_rounded, size: 34),
                onPressed: () => context.read<PlayerProvider>()
                    .playSong(_songs.first, queue: _songs, index: 0),
              ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
              onPressed: () => _confirmLogout(context),
            ),
          ],
        ),
        if (_loading)
          const SliverFillRemaining(child: Center(
            child: CircularProgressIndicator(color: AppColors.grad2)))
        else if (_error != null)
          SliverFillRemaining(child: _ErrorView(onRetry: _load))
        else
          SliverList(delegate: SliverChildBuilderDelegate(
            (ctx, i) => SongTile(song: _songs[i], queue: _songs, index: i),
            childCount: _songs.length,
          )),
      ]),
    );
  }

  void _confirmLogout(BuildContext context) => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
      content: const Text('Tu veux te déconnecter ?',
          style: TextStyle(color: AppColors.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary))),
        TextButton(onPressed: () async {
          await SwingApiService().logout();
          if (context.mounted) Navigator.of(context).pushReplacementNamed('/login');
        }, child: const Text('Déconnexion', style: TextStyle(color: Colors.redAccent))),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const GradientIcon(Icons.wifi_off_rounded, size: 64),
      const SizedBox(height: 16),
      const Text('Erreur de connexion', style: TextStyle(color: Colors.white, fontSize: 16)),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: onRetry,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(gradient: kGradient, borderRadius: BorderRadius.circular(24)),
          child: const Text('Réessayer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    ],
  ));
}
