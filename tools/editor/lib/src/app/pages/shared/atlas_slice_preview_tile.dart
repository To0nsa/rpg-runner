import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../prefabs/models/models.dart';
import 'editor_scene_view_utils.dart';

/// Shared atlas-slice thumbnail used by prefab authoring lists.
class AtlasSlicePreviewTile extends StatefulWidget {
  const AtlasSlicePreviewTile({
    super.key,
    required this.imageCache,
    required this.workspaceRootPath,
    required this.slice,
    this.width = 72,
    this.height = 56,
  });

  final EditorUiImageCache imageCache;
  final String workspaceRootPath;
  final AtlasSliceDef? slice;
  final double width;
  final double height;

  @override
  State<AtlasSlicePreviewTile> createState() => _AtlasSlicePreviewTileState();
}

class _AtlasSlicePreviewTileState extends State<AtlasSlicePreviewTile> {
  ui.Image? _image;
  String? _absolutePath;

  @override
  void initState() {
    super.initState();
    _refreshImage();
  }

  @override
  void didUpdateWidget(covariant AtlasSlicePreviewTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slice != widget.slice ||
        oldWidget.workspaceRootPath != widget.workspaceRootPath ||
        oldWidget.imageCache != widget.imageCache) {
      _refreshImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slice = widget.slice;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF101820),
          border: Border.all(color: const Color(0xFF29404F)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: slice == null || _image == null
              ? const Center(
                  child: Icon(Icons.image_not_supported_outlined, size: 18),
                )
              : CustomPaint(
                  painter: _AtlasSlicePreviewPainter(
                    image: _image!,
                    slice: slice,
                  ),
                ),
        ),
      ),
    );
  }

  void _refreshImage() {
    final slice = widget.slice;
    if (slice == null) {
      _absolutePath = null;
      _image = null;
      return;
    }

    final absolutePath = p.normalize(
      p.join(widget.workspaceRootPath, slice.sourceImagePath),
    );
    final cached = widget.imageCache.imageFor(absolutePath);
    _absolutePath = absolutePath;
    _image = cached;
    if (cached != null) {
      return;
    }

    unawaited(_loadImage(absolutePath));
  }

  Future<void> _loadImage(String absolutePath) async {
    final image = await widget.imageCache.ensureLoaded(absolutePath);
    if (!mounted || _absolutePath != absolutePath) {
      return;
    }
    setState(() {
      _image = image;
    });
  }
}

class _AtlasSlicePreviewPainter extends CustomPainter {
  const _AtlasSlicePreviewPainter({required this.image, required this.slice});

  final ui.Image image;
  final AtlasSliceDef slice;

  @override
  void paint(Canvas canvas, Size size) {
    final maxWidth = image.width.toDouble();
    final maxHeight = image.height.toDouble();
    final clampedWidth = (maxWidth - slice.x)
        .clamp(0.0, slice.width.toDouble())
        .toDouble();
    final clampedHeight = (maxHeight - slice.y)
        .clamp(0.0, slice.height.toDouble())
        .toDouble();
    if (clampedWidth <= 0 || clampedHeight <= 0) {
      return;
    }

    final sourceRect = Rect.fromLTWH(
      slice.x.toDouble().clamp(0.0, maxWidth).toDouble(),
      slice.y.toDouble().clamp(0.0, maxHeight).toDouble(),
      clampedWidth,
      clampedHeight,
    );
    final fittedSizes = applyBoxFit(BoxFit.contain, sourceRect.size, size);
    final outputRect = Alignment.center.inscribe(
      fittedSizes.destination,
      Offset.zero & size,
    );
    canvas.drawImageRect(
      image,
      sourceRect,
      outputRect,
      Paint()..filterQuality = FilterQuality.none,
    );
    canvas.drawRect(
      outputRect,
      Paint()
        ..color = const Color(0x6620404F)
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _AtlasSlicePreviewPainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.slice != slice;
  }
}
