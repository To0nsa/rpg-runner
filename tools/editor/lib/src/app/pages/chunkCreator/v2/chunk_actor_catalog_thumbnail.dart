import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../shared/editor_scene_view_utils.dart';
import 'chunk_actor_idle_frame.dart';

/// Shared cached first-frame thumbnail for enemy and allied NPC catalog cards.
class ChunkActorCatalogThumbnail extends StatefulWidget {
  const ChunkActorCatalogThumbnail({
    super.key,
    required this.frame,
    required this.imageCache,
  });

  final EditorUiImageCache imageCache;
  final ChunkActorIdleFrame? frame;

  @override
  State<ChunkActorCatalogThumbnail> createState() =>
      _ChunkActorCatalogThumbnailState();
}

class _ChunkActorCatalogThumbnailState
    extends State<ChunkActorCatalogThumbnail> {
  var _loadEpoch = 0;

  ChunkActorIdleFrame? get _frame => widget.frame;
  @override
  void initState() {
    super.initState();
    _ensureImageLoaded();
  }

  @override
  void didUpdateWidget(covariant ChunkActorCatalogThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frame?.absoluteSourcePath !=
            widget.frame?.absoluteSourcePath ||
        oldWidget.imageCache != widget.imageCache) {
      _ensureImageLoaded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frame;
    final absolutePath = frame?.absoluteSourcePath;
    final image = absolutePath == null
        ? null
        : widget.imageCache.imageFor(absolutePath);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF101820),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CustomPaint(
          painter: _ChunkActorCatalogThumbnailPainter(
            frame: frame,
            image: image,
          ),
        ),
      ),
    );
  }

  void _ensureImageLoaded() {
    final epoch = ++_loadEpoch;
    final absolutePath = _frame?.absoluteSourcePath;
    if (absolutePath == null) return;
    unawaited(() async {
      await widget.imageCache.ensureLoaded(absolutePath);
      if (mounted && epoch == _loadEpoch) setState(() {});
    }());
  }
}

final class _ChunkActorCatalogThumbnailPainter extends CustomPainter {
  const _ChunkActorCatalogThumbnailPainter({required this.frame, this.image});

  final ChunkActorIdleFrame? frame;
  final ui.Image? image;

  @override
  void paint(Canvas canvas, Size size) {
    final image = this.image;
    final frame = this.frame;
    if (image == null || frame == null || !frame.fits(image)) {
      _paintMissingPreview(canvas, size);
      return;
    }
    canvas.drawImageRect(
      image,
      frame.sourceRect,
      frame.thumbnailDestination(Offset.zero & size),
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  void _paintMissingPreview(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF607D8B)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: 28,
      height: 28,
    );
    canvas.drawCircle(rect.center, 9, paint);
    canvas.drawLine(rect.bottomLeft, rect.topRight, paint);
  }

  @override
  bool shouldRepaint(
    covariant _ChunkActorCatalogThumbnailPainter oldDelegate,
  ) =>
      oldDelegate.frame?.sourceRect != frame?.sourceRect ||
      oldDelegate.image != image;
}
