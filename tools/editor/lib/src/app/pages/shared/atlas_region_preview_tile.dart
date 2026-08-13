import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../atlas/atlas_pixel_rect.dart';
import 'editor_scene_view_utils.dart';

/// Domain-neutral thumbnail for one exact region in a repository atlas.
class AtlasRegionPreviewTile extends StatefulWidget {
  const AtlasRegionPreviewTile({
    super.key,
    required this.imageCache,
    required this.workspaceRootPath,
    required this.sourceImagePath,
    required this.region,
    this.width = 72,
    this.height = 56,
  });

  final EditorUiImageCache imageCache;
  final String workspaceRootPath;
  final String? sourceImagePath;
  final AtlasPixelRect? region;
  final double width;
  final double height;

  @override
  State<AtlasRegionPreviewTile> createState() => _AtlasRegionPreviewTileState();
}

class _AtlasRegionPreviewTileState extends State<AtlasRegionPreviewTile> {
  ui.Image? _image;
  String? _absolutePath;

  @override
  void initState() {
    super.initState();
    _refreshImage();
  }

  @override
  void didUpdateWidget(covariant AtlasRegionPreviewTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceImagePath != widget.sourceImagePath ||
        oldWidget.workspaceRootPath != widget.workspaceRootPath ||
        oldWidget.imageCache != widget.imageCache) {
      _refreshImage();
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
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
        child: widget.region == null || _image == null
            ? const Center(
                child: Icon(Icons.image_not_supported_outlined, size: 18),
              )
            : CustomPaint(
                painter: _AtlasRegionPreviewPainter(
                  image: _image!,
                  region: widget.region!,
                ),
              ),
      ),
    ),
  );

  void _refreshImage() {
    final path = widget.sourceImagePath;
    if (path == null) {
      _absolutePath = null;
      _image = null;
      return;
    }
    final absolutePath = p.normalize(p.join(widget.workspaceRootPath, path));
    _absolutePath = absolutePath;
    _image = widget.imageCache.imageFor(absolutePath);
    if (_image == null) unawaited(_loadImage(absolutePath));
  }

  Future<void> _loadImage(String absolutePath) async {
    final image = await widget.imageCache.ensureLoaded(absolutePath);
    if (!mounted || _absolutePath != absolutePath) return;
    setState(() => _image = image);
  }
}

class _AtlasRegionPreviewPainter extends CustomPainter {
  const _AtlasRegionPreviewPainter({required this.image, required this.region});

  final ui.Image image;
  final AtlasPixelRect region;

  @override
  void paint(Canvas canvas, Size size) {
    if (!region.fitsWithin(
      imageWidth: image.width,
      imageHeight: image.height,
    )) {
      return;
    }
    final sourceRect = Rect.fromLTWH(
      region.x.toDouble(),
      region.y.toDouble(),
      region.width.toDouble(),
      region.height.toDouble(),
    );
    final fitted = applyBoxFit(BoxFit.contain, sourceRect.size, size);
    final destination = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    canvas.drawImageRect(
      image,
      sourceRect,
      destination,
      Paint()..filterQuality = FilterQuality.none,
    );
    canvas.drawRect(
      destination,
      Paint()
        ..color = const Color(0x6620404F)
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _AtlasRegionPreviewPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.region != region;
}
