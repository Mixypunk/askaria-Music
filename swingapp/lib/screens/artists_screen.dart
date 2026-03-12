import 'package:flutter/material.dart';
import '../models/artist.dart';
import '../services/api_service.dart';

class ArtistsScreen extends StatefulWidget {
  const ArtistsScreen({super.key});
  @override
  State<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends State<ArtistsScreen> {
  List<Artist> _artists = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _artists = await SwingApiService().getArtists(limit: 200);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Artistes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                  ]),
                ))
              : _artists.isEmpty
                  ? const Center(child: Text('Aucun artiste'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _artists.length,
                        itemBuilder: (ctx, i) {
                          final a = _artists[i];
                          final thumb = SwingApiService().getThumbnailUrl(a.hash, type: 'artist');
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(thumb),
                              onBackgroundImageError: (_, __) {},
                              child: const Icon(Icons.person),
                            ),
                            title: Text(a.name),
                            subtitle: Text('${a.albumCount} albums · ${a.trackCount} titres'),
                          );
                        },
                      ),
                    ),
    );
  }
}
