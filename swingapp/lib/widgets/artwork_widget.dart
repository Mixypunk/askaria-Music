import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';

class ArtworkWidget extends StatelessWidget {
  final String? hash;
  final double size;
  final double borderRadius;
  final String type;

  const ArtworkWidget({
    super.key,
    required this.hash,
    required this.size,
    this.borderRadius = 8,
    this.type = 'track',
  });

  @override
  Widget build(BuildContext context) {
    final api = SwingApiService();
    final url = hash != null ? api.getThumbnailUrl(hash!, type: type) : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => _placeholder(context),
              errorWidget: (_, __, ___) => _placeholder(context),
            )
          : _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Icon(
        Icons.music_note_rounded,
        size: size * 0.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
