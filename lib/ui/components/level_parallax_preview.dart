import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../assets/ui_asset_lifecycle.dart';
import '../theme/ui_tokens.dart';

/// Static (non-scrolling) parallax preview for menu cards.
///
/// - Uses UiAssetLifecycle for theme → layers caching.
/// - Precaches per widget lifetime to avoid first-frame hitch.
/// - Never crashes the UI if a layer asset is missing.
class LevelParallaxPreview extends StatefulWidget {
  const LevelParallaxPreview({
    super.key,
    required this.themeId,
    this.baseColor = UiBrandPalette.baseBackground,
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
    if (oldWidget.themeId != widget.themeId) {
      _refreshLayers();
    }
  }

  void _refreshLayers() {
    final key = widget.themeId ?? '__null__';
    if (_cacheKey == key) return;

    _cacheKey = key;
    if (_layers.isNotEmpty) {
      setState(() => _layers = const <AssetImage>[]);
    }
    unawaited(_loadAndSwapLayers(key));
  }

  Future<void> _loadAndSwapLayers(String key) async {
    final lifecycle = context.read<UiAssetLifecycle>();
    try {
      final layers = await lifecycle.getParallaxLayers(widget.themeId);
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
    final overlayColor = context.ui.colors.shadow.withValues(alpha: 0.4);
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: widget.baseColor),

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

          // Hardcoded tint overlay to improve text readability on top of previews.
          Positioned.fill(child: ColoredBox(color: overlayColor)),
        ],
      ),
    );
  }
}
