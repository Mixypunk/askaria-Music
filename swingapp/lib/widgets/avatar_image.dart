import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../main.dart';
import '../services/api_service.dart';
import '../services/avatar_store.dart';

/// Avatar utilisateur qui **fonctionne hors ligne**.
///
/// 1. Affiche immédiatement l'image en RAM/disque si elle est connue.
/// 2. Tente une mise à jour réseau en arrière-plan (ignorée si hors ligne).
/// 3. Sinon, retombe sur l'initiale du pseudo (ou une icône personne).
class AvatarImage extends StatefulWidget {
  final int userId;
  final String username;
  final double size;
  final String? url;
  final bool showRing;
  final bool fetchFromNetwork;

  const AvatarImage({
    super.key,
    required this.userId,
    required this.username,
    this.size = 40,
    this.url,
    this.showRing = true,
    this.fetchFromNetwork = true,
  });

  @override
  State<AvatarImage> createState() => _AvatarImageState();
}

class _AvatarImageState extends State<AvatarImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    AvatarStore.instance.addListener(_onStoreChanged);
    _load();
  }

  @override
  void didUpdateWidget(AvatarImage old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId) {
      _bytes = null;
      _load();
    }
  }

  @override
  void dispose() {
    AvatarStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    final mem = AvatarStore.instance.memory(widget.userId);
    if (mem != null && mem != _bytes && mounted) {
      setState(() => _bytes = mem);
    }
  }

  Future<void> _load() async {
    final userId = widget.userId;
    if (userId <= 0) return;

    final cached = await AvatarStore.instance.cached(userId);
    if (cached != null && mounted) setState(() => _bytes = cached);

    if (!widget.fetchFromNetwork) return;
    final api = SwingApiService();
    final fresh = await AvatarStore.instance.fetch(
      userId: userId,
      url: widget.url ?? api.getAvatarUrl(userId),
      headers: api.authHeaders,
    );
    if (fresh != null && mounted) setState(() => _bytes = fresh);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final inner = size - (widget.showRing ? size * 0.09 : 0);

    Widget content;
    if (_bytes != null) {
      content = Image.memory(
        _bytes!,
        width: inner,
        height: inner,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        cacheWidth: (inner * 3).round(),
        cacheHeight: (inner * 3).round(),
      );
    } else {
      content = _InitialAvatar(username: widget.username, size: inner);
    }

    final avatar = ClipOval(child: SizedBox(width: inner, height: inner, child: content));

    if (!widget.showRing) return avatar;

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.045),
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: kGrad),
      child: Center(child: avatar),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String username;
  final double size;
  const _InitialAvatar({required this.username, required this.size});

  @override
  Widget build(BuildContext context) {
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '';
    return Container(
      color: Sp.card,
      alignment: Alignment.center,
      child: initial.isEmpty
          ? Icon(Icons.person_rounded, size: size * 0.55, color: Sp.white70)
          : Text(
              initial,
              style: TextStyle(
                color: Sp.white,
                fontSize: size * 0.42,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}
