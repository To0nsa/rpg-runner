import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/contracts/render_anim_set_definition.dart';
import '../../core/projectiles/projectile_id.dart';
import '../../core/projectiles/projectile_render_catalog.dart';
import '../../core/snapshots/enums.dart';

/// Displays the first frame of a projectile's idle animation as an icon.
///
/// Extracts the source rect from [ProjectileRenderCatalog] metadata (handles
/// strips, multi-row sheets, and grid layouts). Falls back to a transparent
/// box when the projectile has no idle animation.
class ProjectileIconFrame extends StatefulWidget {
  const ProjectileIconFrame({
    super.key,
    required this.projectileId,
    this.size = 32,
  });

  final ProjectileId projectileId;
  final double size;

  @override
  State<ProjectileIconFrame> createState() => _ProjectileIconFrameState();
}

class _ProjectileIconFrameState extends State<ProjectileIconFrame> {
  static const ProjectileRenderCatalog _catalog = ProjectileRenderCatalog();

  ui.Image? _image;
  Rect _srcRect = Rect.zero;
  String? _loadedAsset;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(ProjectileIconFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectileId != widget.projectileId) {
      _resolveImage();
    }
  }

  void _resolveImage() {
    if (widget.projectileId == ProjectileId.unknown) {
      _image = null;
      return;
    }

    final anim = _catalog.get(widget.projectileId);
    final source = anim.sourcesByKey[AnimKey.idle];
    if (source == null) {
      _image = null;
      return;
    }

    _srcRect = _firstFrameRect(anim);
    final assetPath = 'assets/images/$source';

    // Avoid reloading the same asset.
    if (assetPath == _loadedAsset && _image != null) return;
    _loadedAsset = assetPath;

    final provider = AssetImage(assetPath);
    final stream = provider.resolve(ImageConfiguration.empty);
    final completer = Completer<ui.Image>();
    final listener = ImageStreamListener(
      (info, _) => completer.complete(info.image),
      onError: (error, _) => completer.completeError(error),
    );
    stream.addListener(listener);
    completer.future.then((image) {
      if (!mounted) return;
      setState(() => _image = image);
    }).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    if (_image == null) return SizedBox.square(dimension: size);
    return CustomPaint(
      size: Size.square(size),
      painter: _FramePainter(image: _image!, srcRect: _srcRect),
    );
  }

  /// Computes the source rectangle for the first frame of [AnimKey.idle].
  static Rect _firstFrameRect(RenderAnimSetDefinition anim) {
    final row = anim.rowByKey[AnimKey.idle] ?? 0;
    final frameStart = anim.frameStartByKey[AnimKey.idle] ?? 0;
    final gridColumns = anim.gridColumnsByKey[AnimKey.idle];

    final double left;
    final double top;

    if (gridColumns != null) {
      // Grid layout: frameStart is a column index within the row.
      final col = frameStart % gridColumns;
      left = col * anim.frameWidth.toDouble();
      top = row * anim.frameHeight.toDouble();
    } else {
      // Horizontal strip: frameStart is an absolute frame index on that row.
      left = frameStart * anim.frameWidth.toDouble();
      top = row * anim.frameHeight.toDouble();
    }

    return Rect.fromLTWH(
      left,
      top,
      anim.frameWidth.toDouble(),
      anim.frameHeight.toDouble(),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter({required this.image, required this.srcRect});

  final ui.Image image;
  final Rect srcRect;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final dstRect = Offset.zero & canvasSize;
    canvas.drawImageRect(image, srcRect, dstRect, Paint());
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      image != old.image || srcRect != old.srcRect;
}
