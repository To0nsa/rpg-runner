import 'dart:async';

import 'package:flutter/material.dart';
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
  String? _cacheKey;
  List<AssetImage> _layers = const <AssetImage>[];
  bool _precached = false;

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
    if (_cacheKey == key && _layers.isNotEmpty) return;

    _cacheKey = key;
    _precached = false;

    final lifecycle = context.read<UiAssetLifecycle>();
    lifecycle
        .getParallaxLayers(widget.themeId)
        .then((layers) {
          if (!mounted || _cacheKey != key) return;
          setState(() => _layers = layers);
          _schedulePrecache(layers);
        })
        .catchError((_) {
          // Best-effort preview; ignore missing assets.
        });
  }

  void _schedulePrecache(List<AssetImage> layers) {
    if (_precached) return;
    _precached = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        context.read<UiAssetLifecycle>().precacheParallaxLayers(
          layers,
          context,
        ),
      );
    });
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

          // Hardcoded tint overlay to improve text readability on top of previews.
          const Positioned.fill(child: ColoredBox(color: Color(0x66000000))),
        ],
      ),
    );
  }
}
