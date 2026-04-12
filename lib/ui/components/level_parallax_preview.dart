import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../assets/ui_asset_lifecycle.dart';

/// Static (non-scrolling) parallax preview for menu cards.
///
/// - Uses UiAssetLifecycle for theme → layers caching.
/// - Precaches per widget lifetime to avoid first-frame hitch.
/// - Never crashes the UI if a layer asset is missing.
class LevelParallaxPreview extends StatefulWidget {
  const LevelParallaxPreview({
    super.key,
    required this.visualThemeId,
    this.alignment = Alignment.bottomCenter,
    this.filterQuality = FilterQuality.none,
  });

  final String? visualThemeId;

  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;

  @override
  State<LevelParallaxPreview> createState() => _LevelParallaxPreviewState();
}

class _LevelParallaxPreviewState extends State<LevelParallaxPreview> {
  String? _cacheKey;
  List<AssetImage> _layers = const <AssetImage>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshLayers();
  }

  @override
  void didUpdateWidget(LevelParallaxPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visualThemeId != widget.visualThemeId) {
      _refreshLayers();
    }
  }

  void _refreshLayers() {
    final key = widget.visualThemeId ?? '__null__';
    if (_cacheKey == key) return;

    _cacheKey = key;
    // Keep current layers visible while next theme layers are loading.
    unawaited(_loadAndSwapLayers(key));
  }

  Future<void> _loadAndSwapLayers(String key) async {
    final lifecycle = context.read<UiAssetLifecycle>();
    try {
      final layers = await lifecycle.getParallaxLayers(widget.visualThemeId);
      if (!mounted || _cacheKey != key) return;

      // Keep currently rendered layers visible while pre-caching the next
      // theme, then swap atomically to avoid visible one-frame flashes.
      await lifecycle.precacheParallaxLayers(layers, context);
      if (!mounted || _cacheKey != key) return;

      if (!listEquals(_layers, layers)) {
        setState(() => _layers = layers);
      }
    } catch (_) {
      // Best-effort preview; ignore missing assets.
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final provider in _layers)
            Positioned.fill(
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
        ],
      ),
    );
  }
}
