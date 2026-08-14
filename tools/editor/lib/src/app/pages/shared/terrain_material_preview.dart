import 'dart:async';
import 'dart:math' as math;
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
          keyPrefix: widget.keyPrefix,
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
    required this.keyPrefix,
  });

  final String workspaceRootPath;
  final TerrainMaterialDefinition material;
  final EditorUiImageCache imageCache;
  final double height;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
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
        builder: (context, constraints) {
          final horizontalInset = math.min(48.0, constraints.maxWidth * 0.18);
          final verticalInset = math.min(48.0, height * 0.27);
          final platform = Rect.fromLTRB(
            horizontalInset,
            verticalInset,
            constraints.maxWidth - horizontalInset,
            height - verticalInset,
          );
          return Stack(
            children: [
              Positioned.fromRect(
                rect: platform,
                child: _TerrainRegionImage.repeated(
                  key: _previewKey('fill'),
                  workspaceRootPath: workspaceRootPath,
                  region: material.fill,
                  imageCache: imageCache,
                  repeat: _RegionRepeat.both,
                  worldOrigin: platform.topLeft,
                ),
              ),
              ..._edgeProfile(
                material.top,
                role: 'top',
                start: platform.topLeft,
                end: platform.topRight,
              ),
              if (material.rightWall case final profile?)
                ..._edgeProfile(
                  profile,
                  role: 'right_wall',
                  start: platform.topRight,
                  end: platform.bottomRight,
                ),
              if (material.underside case final profile?)
                ..._edgeProfile(
                  profile,
                  role: 'underside',
                  start: platform.bottomRight,
                  end: platform.bottomLeft,
                ),
              if (material.leftWall case final profile?)
                ..._edgeProfile(
                  profile,
                  role: 'left_wall',
                  start: platform.bottomLeft,
                  end: platform.topLeft,
                ),
              if (material.topStartCap case final cap?)
                _cap(
                  cap,
                  role: 'start_cap',
                  edgeY: platform.top,
                  edgeX: platform.left,
                ),
              if (material.topEndCap case final cap?)
                _cap(
                  cap,
                  role: 'end_cap',
                  edgeY: platform.top,
                  edgeX: platform.right,
                ),
              Positioned(
                left: 8,
                top: 8,
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
          );
        },
      ),
    );
  }

  List<Widget> _edgeProfile(
    TerrainMaterialEdgeProfile profile, {
    required String role,
    required Offset start,
    required Offset end,
  }) => <Widget>[
    _edgeLayer(profile.base, role: '${role}_base', start: start, end: end),
    if (profile.detail case final detail?)
      _edgeLayer(detail, role: '${role}_detail', start: start, end: end),
  ];

  Widget _edgeLayer(
    TerrainMaterialEdgeLayer layer, {
    required String role,
    required Offset start,
    required Offset end,
  }) => Positioned.fill(
    child: _TerrainRegionImage.edge(
      key: _previewKey(role),
      workspaceRootPath: workspaceRootPath,
      region: layer.region,
      imageCache: imageCache,
      edgeStart: start,
      edgeEnd: end,
      anchorY: layer.anchorY,
    ),
  );

  Widget _cap(
    TerrainMaterialCap cap, {
    required String role,
    required double edgeY,
    required double edgeX,
  }) {
    return Positioned(
      left: edgeX - cap.anchorX,
      top: edgeY - cap.anchorY,
      width: cap.region.width.toDouble(),
      height: cap.region.height.toDouble(),
      child: _TerrainRegionImage.repeated(
        key: _previewKey(role),
        workspaceRootPath: workspaceRootPath,
        region: cap.region,
        imageCache: imageCache,
        repeat: _RegionRepeat.none,
        worldOrigin: Offset.zero,
      ),
    );
  }

  ValueKey<String> _previewKey(String role) => ValueKey<String>(
    '${keyPrefix ?? material.key}_material_preview_composed_$role',
  );
}

class _TerrainRegionImage extends StatefulWidget {
  const _TerrainRegionImage.repeated({
    super.key,
    required this.workspaceRootPath,
    required this.region,
    required this.imageCache,
    required this.repeat,
    required this.worldOrigin,
  }) : edgeStart = null,
       edgeEnd = null,
       anchorY = null;

  const _TerrainRegionImage.edge({
    super.key,
    required this.workspaceRootPath,
    required this.region,
    required this.imageCache,
    required this.edgeStart,
    required this.edgeEnd,
    required this.anchorY,
  }) : repeat = null,
       worldOrigin = null;

  final String workspaceRootPath;
  final TerrainMaterialImageRegion region;
  final EditorUiImageCache imageCache;
  final _RegionRepeat? repeat;
  final Offset? worldOrigin;
  final Offset? edgeStart;
  final Offset? edgeEnd;
  final double? anchorY;

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
          painter: widget.edgeStart == null
              ? _TerrainRegionPainter(
                  image: _image!,
                  region: widget.region,
                  repeat: widget.repeat!,
                  worldOrigin: widget.worldOrigin!,
                )
              : _TerrainEdgePainter(
                  image: _image!,
                  region: widget.region,
                  start: widget.edgeStart!,
                  end: widget.edgeEnd!,
                  anchorY: widget.anchorY!,
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

class _TerrainEdgePainter extends CustomPainter {
  const _TerrainEdgePainter({
    required this.image,
    required this.region,
    required this.start,
    required this.end,
    required this.anchorY,
  });

  final ui.Image image;
  final TerrainMaterialImageRegion region;
  final Offset start;
  final Offset end;
  final double anchorY;

  @override
  void paint(Canvas canvas, Size size) {
    if (region.right > image.width || region.bottom > image.height) return;
    final delta = end - start;
    final length = delta.distance;
    if (length <= 0) return;
    final angle = math.atan2(delta.dy, delta.dx);
    final tangentX = delta.dx / length;
    final tangentY = delta.dy / length;
    final phase = terrainMaterialEdgeRepeatPhase(
      startX: start.dx,
      startY: start.dy,
      tangentX: tangentX,
      tangentY: tangentY,
      repeatWidth: region.width.toDouble(),
    );
    final source = Rect.fromLTWH(
      region.x.toDouble(),
      region.y.toDouble(),
      region.width.toDouble(),
      region.height.toDouble(),
    );
    final paint = Paint()..filterQuality = FilterQuality.none;

    canvas.save();
    canvas.translate(start.dx, start.dy);
    canvas.rotate(angle);
    canvas.clipRect(
      Rect.fromLTWH(0, -anchorY, length, region.height.toDouble()),
    );
    for (var x = -phase; x < length; x += region.width) {
      canvas.drawImageRect(
        image,
        source,
        Rect.fromLTWH(
          x,
          -anchorY,
          region.width.toDouble(),
          region.height.toDouble(),
        ),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TerrainEdgePainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.region != region ||
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.anchorY != anchorY;
}

class _TerrainRegionPainter extends CustomPainter {
  const _TerrainRegionPainter({
    required this.image,
    required this.region,
    required this.repeat,
    required this.worldOrigin,
  });

  final ui.Image image;
  final TerrainMaterialImageRegion region;
  final _RegionRepeat repeat;
  final Offset worldOrigin;

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
    final startX = -terrainMaterialPositiveModulo(
      worldOrigin.dx,
      region.width.toDouble(),
    );
    final startY = repeat == _RegionRepeat.horizontal
        ? 0.0
        : -terrainMaterialPositiveModulo(
            worldOrigin.dy,
            region.height.toDouble(),
          );
    for (var y = startY; y < endY; y += region.height) {
      for (var x = startX; x < size.width; x += region.width) {
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
      oldDelegate.repeat != repeat ||
      oldDelegate.worldOrigin != worldOrigin;
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
