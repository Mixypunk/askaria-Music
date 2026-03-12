import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

// Cache simple en mémoire pour les images
final _imageCache = <String, Uint8List>{};

class ArtworkWidget extends StatefulWidget {
  final String hash;
  final double size;
  final String type;
  final BorderRadius? borderRadius;

  const ArtworkWidget({
    super.key,
    required this.hash,
    this.size = 48,
    this.type = 'track',
    this.borderRadius,
  });

  @override
  State<ArtworkWidget> createState() => _ArtworkWidgetState();
}

class _ArtworkWidgetState extends State<ArtworkWidget> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = SwingApiService();
    final url = api.getThumbnailUrl(widget.hash, type: widget.type);

    // Check cache
    if (_imageCache.containsKey(url)) {
      if (mounted) setState(() { _bytes = _imageCache[url]; _loading = false; });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: api.cookie != null ? {'Cookie': api.cookie!} : {},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        _imageCache[url] = response.bodyBytes;
        if (mounted) setState(() { _bytes = response.bodyBytes; _loading = false; });
        return;
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final br = widget.borderRadius ?? BorderRadius.circular(4);
    if (_loading) {
      return ClipRRect(
        borderRadius: br,
        child: Container(
          width: widget.size, height: widget.size,
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: const Center(child: SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      );
    }
    if (_bytes == null) {
      return ClipRRect(
        borderRadius: br,
        child: Container(
          width: widget.size, height: widget.size,
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: Icon(Icons.music_note_rounded,
            size: widget.size * 0.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }
    return ClipRRect(
      borderRadius: br,
      child: Image.memory(_bytes!,
        width: widget.size, height: widget.size, fit: BoxFit.cover),
    );
  }
}
