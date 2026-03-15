import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../main.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

// Cache LRU simple — max 100 images en mémoire
class _ImageCache {
  static const _maxSize = 100;
  final _map = <String, Uint8List>{};
  final _order = <String>[];

  Uint8List? get(String key) {
    if (_map.containsKey(key)) {
      _order.remove(key);
      _order.add(key);
      return _map[key];
    }
    return null;
  }

  void put(String key, Uint8List data) {
    if (_map.containsKey(key)) {
      _order.remove(key);
    } else if (_map.length >= _maxSize) {
      final oldest = _order.removeAt(0);
      _map.remove(oldest);
    }
    _map[key] = data;
    _order.add(key);
  }

  // Nombre d'entrées en cache (accessible publiquement)
  int get count => _map.length;

  // Vider le cache
  void clear() {
    _map.clear();
    _order.clear();
  }
}

final artCache = _ImageCache();
// Évite les requêtes en double pour la même URL
final _inFlight = <String, Future<Uint8List?>>{};

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

  @override
  void didUpdateWidget(ArtworkWidget old) {
    super.didUpdateWidget(old);
    if (old.hash != widget.hash) {
      setState(() { _bytes = null; _loading = true; });
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.hash.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final api = SwingApiService();
    final url = '${api.baseUrl}/img/thumbnail/${widget.hash}';

    // Vérifier le cache d'abord
    final cached = artCache.get(url);
    if (cached != null) {
      if (mounted) setState(() { _bytes = cached; _loading = false; });
      return;
    }

    // Dédupliquer les requêtes en vol
    final future = _inFlight[url] ?? _fetchImage(url, api);
    _inFlight[url] = future;

    final result = await future;
    _inFlight.remove(url);

    if (mounted) setState(() { _bytes = result; _loading = false; });
  }

  Future<Uint8List?> _fetchImage(String url, SwingApiService api) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: api.authHeaders,
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        artCache.put(url, response.bodyBytes);
        return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final br = widget.borderRadius ?? BorderRadius.circular(4);
    final size = widget.size;

    if (_loading) {
      return RepaintBoundary(
        child: ClipRRect(
          borderRadius: br,
          child: Container(
            width: size, height: size,
            color: Sp.card,
            child: Center(child: SizedBox(
              width: size * 0.3, height: size * 0.3,
              child: const CircularProgressIndicator(
                  strokeWidth: 1.5, color: Colors.white24))),
          ),
        ),
      );
    }
    if (_bytes == null) {
      return RepaintBoundary(
        child: ClipRRect(
          borderRadius: br,
          child: Container(
            width: size, height: size,
            color: Sp.card,
            child: Icon(Icons.music_note_rounded,
              size: size * 0.45, color: Sp.white40),
          ),
        ),
      );
    }
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: br,
        child: Image.memory(_bytes!,
          width: size, height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true), // évite le flash blanc entre images
      ),
    );
  }
}

// ── Widget image réseau avec timeout + fallback ───────────────────────────────
// Utilise le même cache LRU qu'ArtworkWidget
class NetImage extends StatefulWidget {
  final String url;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool circular;
  final Map<String, String>? headers;
  final Widget? placeholder;

  const NetImage({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.circular = false,
    this.headers,
    this.placeholder,
  });

  @override
  State<NetImage> createState() => _NetImageState();
}

class _NetImageState extends State<NetImage> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void didUpdateWidget(NetImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      setState(() { _bytes = null; _loading = true; });
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.url.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    // Cache LRU partagé
    final cached = artCache.get(widget.url);
    if (cached != null) {
      if (mounted) setState(() { _bytes = cached; _loading = false; });
      return;
    }
    try {
      final r = await http.get(
        Uri.parse(widget.url),
        headers: widget.headers ?? {},
      ).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
        artCache.put(widget.url, r.bodyBytes);
        if (mounted) setState(() { _bytes = r.bodyBytes; _loading = false; });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_loading) {
      child = Container(
        width: widget.width, height: widget.height,
        color: const Color(0xFF282828),
        child: Center(child: SizedBox(
          width: widget.width * 0.25, height: widget.width * 0.25,
          child: const CircularProgressIndicator(
              strokeWidth: 1.5, color: Color(0xFF6A6A6A)))));
    } else if (_bytes == null) {
      child = widget.placeholder ?? Container(
        width: widget.width, height: widget.height,
        color: const Color(0xFF282828),
        child: Icon(Icons.music_note_rounded,
          size: widget.width * 0.4, color: const Color(0xFF6A6A6A)));
    } else {
      child = Image.memory(_bytes!,
        width: widget.width, height: widget.height,
        fit: widget.fit, gaplessPlayback: true);
    }

    if (widget.circular) {
      return ClipOval(child: child);
    }
    if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }
    return child;
  }
}
