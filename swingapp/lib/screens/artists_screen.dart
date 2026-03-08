import 'package:flutter/material.dart';
import '../models/album.dart';
import '../services/api_service.dart';
import '../widgets/artwork_widget.dart';

class ArtistsScreen extends StatefulWidget {
  const ArtistsScreen({super.key});

  @override
  State<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends State<ArtistsScreen> {
  List<Artist> _artists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _artists = await SwingApiService().getArtists(limit: 200);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Artistes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _artists.length,
                itemBuilder: (ctx, i) {
                  final a = _artists[i];
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 26,
                      child: ArtworkWidget(
                        hash: a.hash,
                        size: 52,
                        borderRadius: 26,
                        type: 'artist',
                      ),
                    ),
                    title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('${a.albumCount} albums · ${a.trackCount} titres'),
                  );
                },
              ),
            ),
    );
  }
}
