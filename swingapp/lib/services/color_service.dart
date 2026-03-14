import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// Extrait la couleur dominante d'une image (pochette) et retourne
/// une [DynamicColors] prête à l'emploi dans toute l'UI.
class ColorService {
  static final _cache = <String, DynamicColors>{};

  static Future<DynamicColors> fromBytes(String cacheKey, Uint8List bytes) async {
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    try {
      final provider = MemoryImage(bytes);
      final palette = await PaletteGenerator.fromImageProvider(
        provider,
        size: const Size(200, 200),
        maximumColorCount: 20,
      );

      final dominant = palette.vibrantColor?.color
          ?? palette.dominantColor?.color
          ?? palette.mutedColor?.color
          ?? const Color(0xFF4776E6);

      final colors = DynamicColors._from(dominant);
      _cache[cacheKey] = colors;
      return colors;
    } catch (_) {
      return DynamicColors._fallback();
    }
  }

  static void clearCache() => _cache.clear();
}

class DynamicColors {
  /// Couleur principale extraite (vibrante, saturée)
  final Color accent;
  /// Version légèrement plus claire pour les dégradés
  final Color accentLight;
  /// Version sombre pour les fonds
  final Color accentDark;
  /// Gradient horizontal accent → accentLight
  final LinearGradient gradient;
  /// Gradient vertical pour le fond du player
  final LinearGradient backgroundGradient;

  const DynamicColors._({
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.gradient,
    required this.backgroundGradient,
  });

  factory DynamicColors._from(Color base) {
    // S'assurer que la couleur est suffisamment saturée/lumineuse
    final hsl = HSLColor.fromColor(base);
    final vivid = hsl
        .withSaturation((hsl.saturation * 1.2).clamp(0.45, 1.0))
        .withLightness((hsl.lightness).clamp(0.35, 0.65))
        .toColor();

    final light = HSLColor.fromColor(vivid)
        .withLightness((HSLColor.fromColor(vivid).lightness + 0.15).clamp(0.0, 1.0))
        .toColor();

    final dark = HSLColor.fromColor(vivid)
        .withLightness(0.18)
        .withSaturation((HSLColor.fromColor(vivid).saturation * 0.8).clamp(0.0, 1.0))
        .toColor();

    return DynamicColors._(
      accent: vivid,
      accentLight: light,
      accentDark: dark,
      gradient: LinearGradient(
        colors: [vivid, light],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      backgroundGradient: LinearGradient(
        colors: [dark, const Color(0xFF121212)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.6],
      ),
    );
  }

  static DynamicColors fallback() => DynamicColors._from(const Color(0xFF4776E6));

  /// Crée un shader pour ShaderMask (texte/icônes gradient)
  Shader shaderFor(Rect bounds) => gradient.createShader(bounds);
}
