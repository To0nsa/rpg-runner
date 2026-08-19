import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:terrain_materials/terrain_materials.dart';

import '../../../atlas/atlas_pixel_rect.dart';
import 'atlas_region_preview_tile.dart';
import 'editor_scene_view_utils.dart';
import 'terrain_material_compositor.dart';

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
  late EditorUiImageCache _imageCache;

  @override
  void initState() {
    super.initState();
    _imageCache = EditorUiImageCache();
    _ensureRegionsLoaded();
  }

  @override
  void didUpdateWidget(covariant TerrainMaterialPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceRootPath != widget.workspaceRootPath) {
      _imageCache.dispose();
      _imageCache = EditorUiImageCache();
    }
    if (oldWidget.workspaceRootPath != widget.workspaceRootPath ||
        oldWidget.material != widget.material) {
      _ensureRegionsLoaded();
    }
  }

  @override
  void dispose() {
    _imageCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final material = widget.material;
    final imagesByRegion = <TerrainMaterialImageRegion, ui.Image>{};
    for (final region in terrainMaterialRegions(material)) {
      final image = _imageCache.regionImageFor(
        _absolutePath(region.assetPath),
        x: region.x,
        y: region.y,
        width: region.width,
        height: region.height,
      );
      if (image != null) imagesByRegion[region] = image;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TerrainComposedSample(
          material: material,
          imagesByRegion: imagesByRegion,
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
            _CoverageChip(
              label: 'Bottom corners',
              configured:
                  material.undersideStartCap != null &&
                  material.undersideEndCap != null,
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
    _assetTile('Fill', material.fill, 'fill'),
    _assetTile('Top base', material.top.base.region, 'surface'),
    _assetTile('Top detail', material.top.detail?.region, 'foreground'),
    _assetTile('Start cap', material.topStartCap?.region, 'start_cap'),
    _assetTile('End cap', material.topEndCap?.region, 'end_cap'),
    _assetTile('Left wall', material.leftWall?.base.region, 'left_wall'),
    _assetTile('Right wall', material.rightWall?.base.region, 'right_wall'),
    _assetTile('Underside', material.underside?.base.region, 'underside'),
    _assetTile(
      'Bottom right cap',
      material.undersideStartCap?.region,
      'underside_start_cap',
    ),
    _assetTile(
      'Bottom left cap',
      material.undersideEndCap?.region,
      'underside_end_cap',
    ),
  ];

  Widget _assetTile(
    String label,
    TerrainMaterialImageRegion? region,
    String suffix,
  ) => _TerrainAssetTile(
    workspaceRootPath: widget.workspaceRootPath,
    label: label,
    region: region,
    imageCache: _imageCache,
    tileKey: widget.keyPrefix == null
        ? null
        : '${widget.keyPrefix}_material_preview_$suffix',
  );

  String _absolutePath(String sourcePath) =>
      p.normalize(p.join(widget.workspaceRootPath, sourcePath));

  void _ensureRegionsLoaded() {
    for (final region in terrainMaterialRegions(widget.material)) {
      unawaited(() async {
        final image = await _imageCache.ensureRegionLoaded(
          _absolutePath(region.assetPath),
          x: region.x,
          y: region.y,
          width: region.width,
          height: region.height,
        );
        if (mounted && image != null) setState(() {});
      }());
    }
  }
}

class _TerrainComposedSample extends StatelessWidget {
  const _TerrainComposedSample({
    required this.material,
    required this.imagesByRegion,
    required this.height,
    required this.keyPrefix,
  });

  final TerrainMaterialDefinition material;
  final Map<TerrainMaterialImageRegion, ui.Image> imagesByRegion;
  final double height;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) => Container(
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
        final ownerPath = Path()..addRect(platform);
        final edges = <TerrainMaterialCompositorEdge>[
          TerrainMaterialCompositorEdge(
            profile: material.top,
            orientation: TerrainMaterialEdgeOrientation.top,
            start: platform.topLeft,
            end: platform.topRight,
            startCap: material.topStartCap,
            endCap: material.topEndCap,
          ),
          if (material.rightWall case final profile?)
            TerrainMaterialCompositorEdge(
              profile: profile,
              orientation: TerrainMaterialEdgeOrientation.rightWall,
              start: platform.topRight,
              end: platform.bottomRight,
            ),
          if (material.underside case final profile?)
            TerrainMaterialCompositorEdge(
              profile: profile,
              orientation: TerrainMaterialEdgeOrientation.underside,
              start: platform.bottomRight,
              end: platform.bottomLeft,
              startCap: material.undersideStartCap,
              endCap: material.undersideEndCap,
            ),
          if (material.leftWall case final profile?)
            TerrainMaterialCompositorEdge(
              profile: profile,
              orientation: TerrainMaterialEdgeOrientation.leftWall,
              start: platform.bottomLeft,
              end: platform.topLeft,
            ),
        ];
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                key: _previewKey('canvas'),
                painter: _TerrainCompositionPainter(
                  ownerPath: ownerPath,
                  material: material,
                  imagesByRegion: imagesByRegion,
                  edges: edges,
                ),
              ),
            ),
            for (final role in _configuredRoles(material))
              SizedBox.shrink(key: _previewKey(role)),
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

  ValueKey<String> _previewKey(String role) => ValueKey<String>(
    '${keyPrefix ?? material.key}_material_preview_composed_$role',
  );
}

Iterable<String> _configuredRoles(TerrainMaterialDefinition material) sync* {
  yield 'top_base';
  if (material.top.detail != null) yield 'top_detail';
  if (material.topStartCap != null) yield 'start_cap';
  if (material.topEndCap != null) yield 'end_cap';
  if (material.rightWall case final profile?) {
    yield 'right_wall_base';
    if (profile.detail != null) yield 'right_wall_detail';
  }
  if (material.underside case final profile?) {
    yield 'underside_base';
    if (profile.detail != null) yield 'underside_detail';
  }
  if (material.undersideStartCap != null) yield 'underside_start_cap';
  if (material.undersideEndCap != null) yield 'underside_end_cap';
  if (material.leftWall case final profile?) {
    yield 'left_wall_base';
    if (profile.detail != null) yield 'left_wall_detail';
  }
}

final class _TerrainCompositionPainter extends CustomPainter {
  const _TerrainCompositionPainter({
    required this.ownerPath,
    required this.material,
    required this.imagesByRegion,
    required this.edges,
  });

  final Path ownerPath;
  final TerrainMaterialDefinition material;
  final Map<TerrainMaterialImageRegion, ui.Image> imagesByRegion;
  final List<TerrainMaterialCompositorEdge> edges;

  @override
  void paint(Canvas canvas, Size size) => paintTerrainMaterialComposition(
    canvas,
    ownerPath: ownerPath,
    material: material,
    imagesByRegion: imagesByRegion,
    edges: edges,
  );

  @override
  bool shouldRepaint(covariant _TerrainCompositionPainter oldDelegate) =>
      oldDelegate.material != material ||
      oldDelegate.ownerPath != ownerPath ||
      oldDelegate.imagesByRegion.length != imagesByRegion.length;
}

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
