import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:terrain_materials/terrain_materials.dart';

import '../../../atlas/atlas_pixel_rect.dart';
import 'atlas_region_preview_tile.dart';
import 'editor_scene_view_utils.dart';

/// Shared composed sample and explicit orientation coverage for one material.
class TerrainMaterialPreview extends StatefulWidget {
  const TerrainMaterialPreview({
    super.key,
    required this.workspaceRootPath,
    required this.material,
    this.compact = false,
    this.keyPrefix,
  });

  final String workspaceRootPath;
  final TerrainMaterialDefinition material;
  final bool compact;
  final String? keyPrefix;

  @override
  State<TerrainMaterialPreview> createState() => _TerrainMaterialPreviewState();
}

class _TerrainMaterialPreviewState extends State<TerrainMaterialPreview> {
  final EditorUiImageCache _imageCache = EditorUiImageCache();

  @override
  void dispose() {
    _imageCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final material = widget.material;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TerrainComposedSample(
          workspaceRootPath: widget.workspaceRootPath,
          material: material,
          imageCache: _imageCache,
          height: widget.compact ? 160 : 220,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            const _CoverageChip(label: 'Top / slope', configured: true),
            _CoverageChip(
              label: 'Left wall',
              configured: material.leftWall != null,
            ),
            _CoverageChip(
              label: 'Right wall',
              configured: material.rightWall != null,
            ),
            _CoverageChip(
              label: 'Underside',
              configured: material.underside != null,
            ),
            _CoverageChip(
              label: 'Cliff caps',
              configured:
                  material.topStartCap != null && material.topEndCap != null,
            ),
          ],
        ),
        if (!widget.compact) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: _assetTiles(material)),
        ],
      ],
    );
  }

  List<Widget> _assetTiles(TerrainMaterialDefinition material) => [
    _TerrainAssetTile(
      workspaceRootPath: widget.workspaceRootPath,
      label: 'Fill',
      region: material.fill,
      imageCache: _imageCache,
      tileKey: _tileKey('fill'),
    ),
    _TerrainAssetTile(
      workspaceRootPath: widget.workspaceRootPath,
      label: 'Top base',
      region: material.top.base.region,
      imageCache: _imageCache,
      tileKey: _tileKey('surface'),
    ),
    _TerrainAssetTile(
      workspaceRootPath: widget.workspaceRootPath,
      label: 'Top detail',
      region: material.top.detail?.region,
      imageCache: _imageCache,
      tileKey: _tileKey('foreground'),
    ),
    _TerrainAssetTile(
      workspaceRootPath: widget.workspaceRootPath,
      label: 'Start cap',
      region: material.topStartCap?.region,
      imageCache: _imageCache,
      tileKey: _tileKey('start_cap'),
    ),
    _TerrainAssetTile(
      workspaceRootPath: widget.workspaceRootPath,
      label: 'End cap',
      region: material.topEndCap?.region,
      imageCache: _imageCache,
      tileKey: _tileKey('end_cap'),
    ),
    _TerrainAssetTile(
      workspaceRootPath: widget.workspaceRootPath,
      label: 'Left wall',
      region: material.leftWall?.base.region,
      imageCache: _imageCache,
      tileKey: _tileKey('left_wall'),
    ),
    _TerrainAssetTile(
      workspaceRootPath: widget.workspaceRootPath,
      label: 'Right wall',
      region: material.rightWall?.base.region,
      imageCache: _imageCache,
      tileKey: _tileKey('right_wall'),
    ),
    _TerrainAssetTile(
      workspaceRootPath: widget.workspaceRootPath,
      label: 'Underside',
      region: material.underside?.base.region,
      imageCache: _imageCache,
      tileKey: _tileKey('underside'),
    ),
  ];

  String? _tileKey(String suffix) => widget.keyPrefix == null
      ? null
      : '${widget.keyPrefix}_material_preview_$suffix';
}

class _TerrainComposedSample extends StatelessWidget {
  const _TerrainComposedSample({
    required this.workspaceRootPath,
    required this.material,
    required this.imageCache,
    required this.height,
  });

  final String workspaceRootPath;
  final TerrainMaterialDefinition material;
  final EditorUiImageCache imageCache;
  final double height;

  @override
  Widget build(BuildContext context) {
    final edgeY = height * 0.34;
    return Container(
      key: ValueKey<String>('terrain_material_sample_${material.key}'),
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Positioned(
              left: 24,
              right: 24,
              top: edgeY,
              bottom: 0,
              child: _TerrainRegionImage(
                workspaceRootPath: workspaceRootPath,
                region: material.fill,
                imageCache: imageCache,
                repeat: _RegionRepeat.both,
              ),
            ),
            _edgeLayer(material.top.base, edgeY: edgeY),
            if (material.top.detail case final detail?)
              _edgeLayer(detail, edgeY: edgeY),
            if (material.topStartCap case final cap?)
              _cap(cap, edgeY: edgeY, sampleWidth: constraints.maxWidth),
            if (material.topEndCap case final cap?)
              _cap(cap, edgeY: edgeY, sampleWidth: constraints.maxWidth),
            Positioned(
              left: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  child: Text(
                    '${material.displayName} · ${material.key}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _edgeLayer(TerrainMaterialEdgeLayer layer, {required double edgeY}) =>
      Positioned(
        left: 24,
        right: 24,
        top: edgeY - layer.anchorY,
        height: layer.region.height.toDouble(),
        child: _TerrainRegionImage(
          workspaceRootPath: workspaceRootPath,
          region: layer.region,
          imageCache: imageCache,
          repeat: _RegionRepeat.horizontal,
        ),
      );

  Widget _cap(
    TerrainMaterialCap cap, {
    required double edgeY,
    required double sampleWidth,
  }) {
    final isStart = identical(cap, material.topStartCap);
    return Positioned(
      left: (isStart ? 24 : sampleWidth - 24) - cap.anchorX,
      top: edgeY - cap.anchorY,
      width: cap.region.width.toDouble(),
      height: cap.region.height.toDouble(),
      child: _TerrainRegionImage(
        workspaceRootPath: workspaceRootPath,
        region: cap.region,
        imageCache: imageCache,
        repeat: _RegionRepeat.none,
      ),
    );
  }
}

class _TerrainRegionImage extends StatefulWidget {
  const _TerrainRegionImage({
    required this.workspaceRootPath,
    required this.region,
    required this.imageCache,
    required this.repeat,
  });

  final String workspaceRootPath;
  final TerrainMaterialImageRegion region;
  final EditorUiImageCache imageCache;
  final _RegionRepeat repeat;

  @override
  State<_TerrainRegionImage> createState() => _TerrainRegionImageState();
}

class _TerrainRegionImageState extends State<_TerrainRegionImage> {
  ui.Image? _image;
  String? _absolutePath;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant _TerrainRegionImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.region.assetPath != widget.region.assetPath ||
        oldWidget.workspaceRootPath != widget.workspaceRootPath ||
        oldWidget.imageCache != widget.imageCache) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) => _image == null
      ? const ColoredBox(color: Color(0x22000000))
      : CustomPaint(
          painter: _TerrainRegionPainter(
            image: _image!,
            region: widget.region,
            repeat: widget.repeat,
          ),
        );

  void _refresh() {
    final absolutePath = p.normalize(
      p.join(widget.workspaceRootPath, widget.region.assetPath),
    );
    _absolutePath = absolutePath;
    _image = widget.imageCache.imageFor(absolutePath);
    if (_image == null) unawaited(_load(absolutePath));
  }

  Future<void> _load(String absolutePath) async {
    final image = await widget.imageCache.ensureLoaded(absolutePath);
    if (!mounted || _absolutePath != absolutePath) return;
    setState(() => _image = image);
  }
}

class _TerrainRegionPainter extends CustomPainter {
  const _TerrainRegionPainter({
    required this.image,
    required this.region,
    required this.repeat,
  });

  final ui.Image image;
  final TerrainMaterialImageRegion region;
  final _RegionRepeat repeat;

  @override
  void paint(Canvas canvas, Size size) {
    if (region.right > image.width || region.bottom > image.height) return;
    final source = Rect.fromLTWH(
      region.x.toDouble(),
      region.y.toDouble(),
      region.width.toDouble(),
      region.height.toDouble(),
    );
    final paint = Paint()..filterQuality = FilterQuality.none;
    if (repeat == _RegionRepeat.none) {
      canvas.drawImageRect(image, source, Offset.zero & source.size, paint);
      return;
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final endY = repeat == _RegionRepeat.horizontal
        ? region.height.toDouble()
        : size.height;
    for (var y = 0.0; y < endY; y += region.height) {
      for (var x = 0.0; x < size.width; x += region.width) {
        canvas.drawImageRect(
          image,
          source,
          Rect.fromLTWH(
            x,
            y,
            region.width.toDouble(),
            region.height.toDouble(),
          ),
          paint,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TerrainRegionPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.region != region ||
      oldDelegate.repeat != repeat;
}

enum _RegionRepeat { none, horizontal, both }

class _CoverageChip extends StatelessWidget {
  const _CoverageChip({required this.label, required this.configured});

  final String label;
  final bool configured;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(
      configured ? Icons.check_circle_outline : Icons.remove_circle_outline,
      size: 17,
      color: configured
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    label: Text('$label · ${configured ? 'configured' : 'fill only'}'),
  );
}

class _TerrainAssetTile extends StatelessWidget {
  const _TerrainAssetTile({
    required this.workspaceRootPath,
    required this.label,
    required this.region,
    required this.imageCache,
    required this.tileKey,
  });

  final String workspaceRootPath;
  final String label;
  final TerrainMaterialImageRegion? region;
  final EditorUiImageCache imageCache;
  final String? tileKey;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        AtlasRegionPreviewTile(
          key: tileKey == null ? null : ValueKey<String>(tileKey!),
          imageCache: imageCache,
          workspaceRootPath: workspaceRootPath,
          sourceImagePath: region?.assetPath,
          region: region == null
              ? null
              : AtlasPixelRect(
                  x: region!.x,
                  y: region!.y,
                  width: region!.width,
                  height: region!.height,
                ),
          width: 150,
          height: 88,
        ),
        const SizedBox(height: 3),
        Tooltip(
          message: region?.assetPath ?? 'No region configured',
          child: Text(
            region == null
                ? '—'
                : '${p.basename(region!.assetPath)} '
                      '[${region!.x},${region!.y},${region!.width},${region!.height}]',
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
}
