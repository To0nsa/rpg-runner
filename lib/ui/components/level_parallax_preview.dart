import 'dart:collection';

import 'package:flutter/material.dart';

import '../../game/themes/parallax_theme_registry.dart';

/// Static (non-scrolling) parallax preview for menu cards.
///
/// - Uses ParallaxThemeRegistry as the source of truth.
/// - LRU caches resolved layer AssetImages by themeId.
/// - Precaches per widget lifetime to avoid first-frame hitch.
/// - Never crashes the UI if a layer asset is missing.
class LevelParallaxPreview extends StatefulWidget {
  const LevelParallaxPreview({
    super.key,
    required this.themeId,
    this.baseColor = const Color(0xFF0B1020),
    this.alignment = Alignment.bottomCenter,
    this.filterQuality = FilterQuality.none,
  });

  final String? themeId;

  /// Fill behind transparent pixels in layers.
  /// Important because MenuScaffold background is black.
  final Color baseColor;

  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;

  @override
  State<LevelParallaxPreview> createState() => _LevelParallaxPreviewState();
}

class _LevelParallaxPreviewState extends State<LevelParallaxPreview> {
  // Small LRU (more than enough for current scope: field/forest).
  static const int _maxCacheEntries = 8;
  static final LinkedHashMap<String, List<AssetImage>> _lru = LinkedHashMap();

  String? _cacheKey;
  late List<AssetImage> _layers;
  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final key = widget.themeId ?? '__null__';
    if (_cacheKey == key) return;

    _cacheKey = key;
    _layers = _getOrBuildLayers(widget.themeId);
    _precached = false;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _precached) return;
      _precached = true;

      // Best-effort precache: never throw.
      for (final img in _layers) {
        try {
          await precacheImage(img, context);
        } catch (_) {
          // Ignore missing/bad assets; Image.errorBuilder handles it.
        }
      }
    });
  }

  static List<AssetImage> _getOrBuildLayers(String? themeId) {
    final key = themeId ?? '__null__';

    // LRU hit
    final hit = _lru.remove(key);
    if (hit != null) {
      _lru[key] = hit; // re-insert as most-recent
      return hit;
    }

    final theme = ParallaxThemeRegistry.forThemeId(themeId);

    AssetImage img(String relToImagesFolder) =>
        AssetImage('assets/images/$relToImagesFolder');

    final built = <AssetImage>[
      for (final layer in theme.backgroundLayers) img(layer.assetPath),
      img(theme.groundLayerAsset),
      for (final layer in theme.foregroundLayers) img(layer.assetPath),
    ];

    // LRU insert + evict
    _lru[key] = built;
    while (_lru.length > _maxCacheEntries) {
      _lru.remove(_lru.keys.first);
    }

    return built;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: widget.baseColor),

          for (final provider in _layers)
            Positioned.fill(
              child: Align(
                alignment: widget.alignment,
                child: Image(
                  image: provider,
                  fit: BoxFit.cover,
                  alignment: widget.alignment,
                  filterQuality: widget.filterQuality,
                  errorBuilder: (context, error, stackTrace) {
                    // If one layer is missing, just skip it visually.
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
