import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:runner_core/contracts/render_anim_set_definition.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/projectiles/projectile_render_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';

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

  ImageInfo? _imageInfo;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Rect _srcRect = Rect.zero;

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

  void _clearImage() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _stream = null;
    _listener = null;
    _imageInfo?.dispose();
    _imageInfo = null;
  }

  @override
  void dispose() {
    _clearImage();
    super.dispose();
  }

  void _resolveImage() {
    if (widget.projectileId == ProjectileId.unknown) {
      _clearImage();
      return;
    }
    final anim = _catalog.get(widget.projectileId);
    final source = anim.sourcesByKey[AnimKey.idle];
    if (source == null) {
      _clearImage();
      return;
    }
    _srcRect = _firstFrameRect(anim);
    // Resolve with this consumer's bundle (game bundle or repository-backed tool).
    final stream = AssetImage('assets/images/$source')
        .resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _clearImage();
    _stream = stream;
    _listener = ImageStreamListener(
      (info, synchronousCall) {
        if (!mounted || _stream != stream) {
          info.dispose();
          return;
        }
        final previous = _imageInfo;
        if (synchronousCall) {
          _imageInfo = info;
        } else {
          setState(() => _imageInfo = info);
        }
        previous?.dispose();
      },
      onError: (Object error, StackTrace? stack) {
        if (mounted && _stream == stream) {
          setState(() {
            _imageInfo?.dispose();
            _imageInfo = null;
          });
        }
      },
    );
    stream.addListener(_listener!);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    if (_imageInfo == null) return SizedBox.square(dimension: size);
    return CustomPaint(
      size: Size.square(size),
      painter: _FramePainter(image: _imageInfo!.image, srcRect: _srcRect),
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
