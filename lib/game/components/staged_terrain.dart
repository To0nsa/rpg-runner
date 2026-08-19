import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/snapshots/staged_terrain_render_snapshot.dart';
import 'package:terrain_materials/terrain_materials.dart';

import '../game_controller.dart';
import '../spatial/world_view_transform.dart';
import '../themes/terrain_material_registry.dart';
import 'staged_terrain_edge_layout.dart';
import 'staged_terrain_mesh_layout.dart';

/// Draws staged terrain using only Core-owned triangles and exposed edges.
class StagedTerrain extends Component with HasGameReference<FlameGame> {
  StagedTerrain({
    required this.controller,
    required this.virtualWidth,
    required this.virtualHeight,
  });

  final GameController controller;
  final int virtualWidth;
  final int virtualHeight;

  final Map<String, _LoadedTerrainMaterial> _materials =
      <String, _LoadedTerrainMaterial>{};
  final Map<TerrainMaterialImageRegionSpec, ui.Image> _regionImages =
      <TerrainMaterialImageRegionSpec, ui.Image>{};
  List<_CachedTerrainMesh> _meshes = const <_CachedTerrainMesh>[];
  List<_CachedTerrainDecoratedEdge> _surfaceEdges =
      const <_CachedTerrainDecoratedEdge>[];
  int? _geometryVersion;
  bool _assetsReady = false;

  @visibleForTesting
  bool get debugAssetsReady => _assetsReady;

  @visibleForTesting
  int? get debugGeometryVersion => _geometryVersion;

  @visibleForTesting
  int get debugMeshCount => _meshes.length;

  @visibleForTesting
  int get debugSurfaceEdgeCount => _surfaceEdges.length;

  @visibleForTesting
  int get debugRegionImageCount => _regionImages.length;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final sourceImagesByPath = <String, ui.Image>{};
    try {
      final assetPaths =
          TerrainMaterialRegistry.byKey.values
              .expand((spec) => spec.assetPaths)
              .toSet()
              .toList(growable: false)
            ..sort();
      for (final assetPath in assetPaths) {
        sourceImagesByPath[assetPath] = await game.images.load(assetPath);
      }
      for (final spec in TerrainMaterialRegistry.byKey.values) {
        for (final region in spec.regions) {
          _regionImages[region] ??= await extractTerrainRegionImage(
            sourceImagesByPath[region.assetPath]!,
            region,
          );
        }
        _materials[spec.key] = _LoadedTerrainMaterial(
          spec: spec,
          imagesByRegion: _regionImages,
        );
      }
    } on Object {
      _disposeRegionImages();
      _materials.clear();
      rethrow;
    }
    _assetsReady = true;
    _syncSnapshot(controller.snapshot.stagedTerrainRenderSnapshot);
  }

  @override
  void onRemove() {
    _assetsReady = false;
    _materials.clear();
    _disposeRegionImages();
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_assetsReady) return;
    _syncSnapshot(controller.snapshot.stagedTerrainRenderSnapshot);
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    if (!_assetsReady || _meshes.isEmpty) return;

    final cameraX = -game.camera.viewfinder.transform.offset.x;
    final cameraY = -game.camera.viewfinder.transform.offset.y;
    final transform = WorldViewTransform(
      cameraCenterX: cameraX,
      cameraCenterY: cameraY,
      viewWidth: virtualWidth.toDouble(),
      viewHeight: virtualHeight.toDouble(),
    );
    final visibleWorldRect = ui.Rect.fromLTRB(
      transform.viewLeftX,
      transform.viewTopY,
      transform.viewRightX,
      transform.viewBottomY,
    );

    canvas.save();
    canvas.clipRect(
      ui.Rect.fromLTWH(0, 0, virtualWidth.toDouble(), virtualHeight.toDouble()),
    );
    canvas.translate(-transform.viewLeftX, -transform.viewTopY);

    for (final mesh in _meshes) {
      if (!mesh.bounds.overlaps(visibleWorldRect)) continue;
      final material = _materials[mesh.materialKey]!;
      canvas.drawVertices(
        mesh.vertices,
        ui.BlendMode.srcOver,
        material.fillPaint,
      );
    }
    for (final edge in _surfaceEdges) {
      if (!edge.bounds.overlaps(visibleWorldRect)) continue;
      final material = _materials[edge.materialKey]!;
      final profile = StagedTerrainEdgeLayout.profileFor(
        material.spec,
        edge.orientation,
      )!;
      _drawEdgeImage(
        canvas,
        edge: edge,
        image: material.imageFor(profile.base.region),
        anchorY: profile.base.anchorY,
        orientation: edge.orientation,
      );
      if (profile.detail case final detail?) {
        _drawEdgeImage(
          canvas,
          edge: edge,
          image: material.imageFor(detail.region),
          anchorY: detail.anchorY,
          orientation: edge.orientation,
        );
      }
    }
    // Endpoint art is a foreground pass so adjacent wall bands cannot obscure
    // the cliff silhouette when snapshot edge ordering changes.
    for (final edge in _surfaceEdges) {
      if (!edge.bounds.overlaps(visibleWorldRect) ||
          (!edge.drawStartCap && !edge.drawEndCap)) {
        continue;
      }
      final material = _materials[edge.materialKey]!;
      final caps = switch (edge.orientation) {
        TerrainMaterialEdgeOrientation.top => (
          material.spec.topStartCap,
          material.spec.topEndCap,
        ),
        TerrainMaterialEdgeOrientation.underside => (
          material.spec.undersideStartCap,
          material.spec.undersideEndCap,
        ),
        TerrainMaterialEdgeOrientation.leftWall ||
        TerrainMaterialEdgeOrientation.rightWall => (null, null),
      };
      if (edge.drawStartCap) {
        final cap = caps.$1;
        if (cap != null) {
          _drawEdgeCap(
            canvas,
            edge: edge,
            image: material.imageFor(cap.region),
            cap: cap,
            atEnd: false,
            orientation: edge.orientation,
          );
        }
      }
      if (edge.drawEndCap) {
        final cap = caps.$2;
        if (cap != null) {
          _drawEdgeCap(
            canvas,
            edge: edge,
            image: material.imageFor(cap.region),
            cap: cap,
            atEnd: true,
            orientation: edge.orientation,
          );
        }
      }
    }

    canvas.restore();
  }

  void _syncSnapshot(StagedTerrainRenderSnapshot? snapshot) {
    if (snapshot == null) {
      _geometryVersion = null;
      _meshes = const <_CachedTerrainMesh>[];
      _surfaceEdges = const <_CachedTerrainDecoratedEdge>[];
      return;
    }
    if (_geometryVersion == snapshot.geometryVersion) return;

    final meshes = <_CachedTerrainMesh>[];
    final meshesBySourceId = <TerrainSourceIdentity, _CachedTerrainMesh>{};
    for (final mesh in StagedTerrainMeshLayout.build(snapshot)) {
      TerrainMaterialRegistry.require(mesh.materialKey);
      if (mesh.positions.isEmpty || mesh.triangleIndices.isEmpty) continue;
      final cachedMesh = _CachedTerrainMesh.fromData(mesh);
      if (meshesBySourceId.containsKey(mesh.sourceId)) {
        throw StateError('Duplicate terrain render mesh for ${mesh.sourceId}.');
      }
      meshesBySourceId[mesh.sourceId] = cachedMesh;
      meshes.add(cachedMesh);
    }

    final surfaceEdges = <_CachedTerrainDecoratedEdge>[];
    for (final decoration in StagedTerrainEdgeLayout.build(snapshot)) {
      final edgeId = decoration.edge.id;
      final sourceId = TerrainSourceIdentity(
        chunkIndex: edgeId.chunkIndex,
        chunkKey: edgeId.chunkKey,
        placementKey: edgeId.placementKey,
        shapeId: edgeId.shapeId,
      );
      final ownerMesh = meshesBySourceId[sourceId];
      if (ownerMesh == null) {
        throw StateError('Terrain render edge $edgeId has no owner mesh.');
      }
      surfaceEdges.add(
        _CachedTerrainDecoratedEdge.fromLayout(
          decoration,
          clipPath: ownerMesh.clipPath,
        ),
      );
    }

    _meshes = List<_CachedTerrainMesh>.unmodifiable(meshes);
    final edgePaintOrder = terrainMaterialEdgePaintOrder(
      surfaceEdges.map((edge) => edge.orientation),
    );
    _surfaceEdges = List<_CachedTerrainDecoratedEdge>.unmodifiable(
      edgePaintOrder.map((index) => surfaceEdges[index]),
    );
    _geometryVersion = snapshot.geometryVersion;
  }

  void _drawEdgeImage(
    ui.Canvas canvas, {
    required _CachedTerrainDecoratedEdge edge,
    required ui.Image image,
    required double anchorY,
    required TerrainMaterialEdgeOrientation orientation,
  }) => paintTerrainMaterialEdgeImage(
    canvas,
    start: edge.start,
    length: edge.length,
    angle: edge.angle,
    image: image,
    anchorY: anchorY,
    orientation: orientation,
    startUnderlapFactor: edge.startUnderlapFactor,
    endUnderlapFactor: edge.endUnderlapFactor,
    clipPath: edge.clipPath,
  );

  void _drawEdgeCap(
    ui.Canvas canvas, {
    required _CachedTerrainDecoratedEdge edge,
    required ui.Image image,
    required TerrainMaterialCapSpec cap,
    required bool atEnd,
    required TerrainMaterialEdgeOrientation orientation,
  }) => paintTerrainMaterialCapImage(
    canvas,
    start: edge.start,
    length: edge.length,
    angle: edge.angle,
    image: image,
    anchorX: cap.anchorX,
    anchorY: cap.anchorY,
    atEnd: atEnd,
    orientation: orientation,
    clipPath: edge.clipPath,
  );

  void _disposeRegionImages() {
    for (final image in _regionImages.values) {
      image.dispose();
    }
    _regionImages.clear();
  }
}

/// Paints one isolated, world-facing edge image along a terrain tangent.
///
/// Exposed for renderer tests. Source art is normalized for its named role
/// before tangent placement, so axis-aligned walls and undersides retain their
/// authored atlas orientation. When supplied, [clipPath] is in world space and
/// confines the complete edge band to its owning polygon. Underlap factors
/// extend only an earlier-painted strip beneath its adjacent foreground strip.
@visibleForTesting
void paintTerrainMaterialEdgeImage(
  ui.Canvas canvas, {
  required ui.Offset start,
  required double length,
  required double angle,
  required ui.Image image,
  required double anchorY,
  required TerrainMaterialEdgeOrientation orientation,
  double startUnderlapFactor = 0,
  double endUnderlapFactor = 0,
  ui.Path? clipPath,
}) {
  if (length <= 0) return;
  final tileWidth = terrainMaterialEdgeTileWidth(
    orientation: orientation,
    sourceWidth: image.width,
    sourceHeight: image.height,
  ).toDouble();
  final tileHeight = terrainMaterialEdgeTileHeight(
    orientation: orientation,
    sourceWidth: image.width,
    sourceHeight: image.height,
  ).toDouble();
  final phase = terrainMaterialEdgeRepeatPhase(
    startX: start.dx,
    startY: start.dy,
    tangentX: math.cos(angle),
    tangentY: math.sin(angle),
    repeatWidth: tileWidth,
  );
  final quarterTurns = terrainMaterialEdgeNormalizationQuarterTurns(
    orientation,
  );
  final interiorDepth = math.max(0, tileHeight - anchorY);
  final paintStart = -startUnderlapFactor * interiorDepth;
  final paintEnd = length + endUnderlapFactor * interiorDepth;
  final firstTileX =
      terrainMaterialTileStart(paintStart + phase, tileWidth) - phase;

  canvas.save();
  if (clipPath != null) canvas.clipPath(clipPath);
  canvas.translate(start.dx, start.dy);
  canvas.rotate(angle);
  canvas.clipRect(
    ui.Rect.fromLTWH(paintStart, -anchorY, paintEnd - paintStart, tileHeight),
  );
  for (var x = firstTileX; x < paintEnd; x += tileWidth) {
    _drawNormalizedEdgeImage(
      canvas,
      image: image,
      destination: ui.Offset(x, -anchorY),
      quarterTurns: quarterTurns,
    );
  }
  canvas.restore();
}

/// Paints one world-facing endpoint cap after all repeating edge bands.
///
/// When supplied, [clipPath] is in world space and prevents the rectangular
/// cap image from crossing another boundary of its owning polygon.
@visibleForTesting
void paintTerrainMaterialCapImage(
  ui.Canvas canvas, {
  required ui.Offset start,
  required double length,
  required double angle,
  required ui.Image image,
  required double anchorX,
  required double anchorY,
  required bool atEnd,
  required TerrainMaterialEdgeOrientation orientation,
  ui.Path? clipPath,
}) {
  if (length <= 0) return;
  canvas.save();
  if (clipPath != null) canvas.clipPath(clipPath);
  canvas.translate(start.dx, start.dy);
  canvas.rotate(angle);
  _drawNormalizedEdgeImage(
    canvas,
    image: image,
    destination: ui.Offset((atEnd ? length : 0) - anchorX, -anchorY),
    quarterTurns: terrainMaterialEdgeNormalizationQuarterTurns(orientation),
  );
  canvas.restore();
}

void _drawNormalizedEdgeImage(
  ui.Canvas canvas, {
  required ui.Image image,
  required ui.Offset destination,
  required int quarterTurns,
}) {
  canvas.save();
  switch (quarterTurns) {
    case 0:
      canvas.translate(destination.dx, destination.dy);
    case 1:
      canvas.translate(destination.dx + image.height, destination.dy);
      canvas.rotate(math.pi / 2);
    case 2:
      canvas.translate(
        destination.dx + image.width,
        destination.dy + image.height,
      );
      canvas.rotate(math.pi);
    case 3:
      canvas.translate(destination.dx, destination.dy + image.width);
      canvas.rotate(-math.pi / 2);
    default:
      throw ArgumentError.value(
        quarterTurns,
        'quarterTurns',
        'Must be within [0, 3].',
      );
  }
  canvas.drawImage(image, ui.Offset.zero, _terrainEdgePaint);
  canvas.restore();
}

final Paint _terrainEdgePaint = Paint()..filterQuality = FilterQuality.none;

final class _LoadedTerrainMaterial {
  _LoadedTerrainMaterial({required this.spec, required this.imagesByRegion})
    : fillPaint = Paint()
        ..filterQuality = FilterQuality.none
        ..shader = ui.ImageShader(
          imagesByRegion[spec.fill]!,
          ui.TileMode.repeated,
          ui.TileMode.repeated,
          _identityMatrix,
          filterQuality: ui.FilterQuality.none,
        );

  final TerrainMaterialSpec spec;
  final Paint fillPaint;
  final Map<TerrainMaterialImageRegionSpec, ui.Image> imagesByRegion;

  ui.Image imageFor(TerrainMaterialImageRegionSpec region) =>
      imagesByRegion[region]!;
}

/// Copies one exact atlas region into an independently owned image.
@visibleForTesting
Future<ui.Image> extractTerrainRegionImage(
  ui.Image source,
  TerrainMaterialImageRegionSpec region,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawImageRect(
    source,
    ui.Rect.fromLTWH(
      region.x.toDouble(),
      region.y.toDouble(),
      region.width.toDouble(),
      region.height.toDouble(),
    ),
    ui.Rect.fromLTWH(0, 0, region.width.toDouble(), region.height.toDouble()),
    Paint()..filterQuality = FilterQuality.none,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(region.width, region.height);
  } finally {
    picture.dispose();
  }
}

final class _CachedTerrainMesh {
  _CachedTerrainMesh({
    required this.materialKey,
    required this.vertices,
    required this.clipPath,
    required this.bounds,
  });

  factory _CachedTerrainMesh.fromData(StagedTerrainMeshData data) {
    var minX = data.positions.first.dx;
    var minY = data.positions.first.dy;
    var maxX = minX;
    var maxY = minY;
    for (final position in data.positions.skip(1)) {
      minX = math.min(minX, position.dx);
      minY = math.min(minY, position.dy);
      maxX = math.max(maxX, position.dx);
      maxY = math.max(maxY, position.dy);
    }
    final clipPath = ui.Path()
      ..moveTo(data.positions.first.dx, data.positions.first.dy);
    for (final position in data.positions.skip(1)) {
      clipPath.lineTo(position.dx, position.dy);
    }
    clipPath.close();
    return _CachedTerrainMesh(
      materialKey: data.materialKey,
      vertices: ui.Vertices(
        ui.VertexMode.triangles,
        data.positions,
        indices: data.triangleIndices,
      ),
      clipPath: clipPath,
      bounds: ui.Rect.fromLTRB(minX, minY, maxX, maxY),
    );
  }

  final String materialKey;
  final ui.Vertices vertices;
  final ui.Path clipPath;
  final ui.Rect bounds;
}

final class _CachedTerrainDecoratedEdge {
  const _CachedTerrainDecoratedEdge({
    required this.materialKey,
    required this.orientation,
    required this.drawStartCap,
    required this.drawEndCap,
    required this.startUnderlapFactor,
    required this.endUnderlapFactor,
    required this.start,
    required this.length,
    required this.angle,
    required this.clipPath,
    required this.bounds,
  });

  factory _CachedTerrainDecoratedEdge.fromLayout(
    StagedTerrainEdgeDecoration decoration, {
    required ui.Path clipPath,
  }) {
    final edge = decoration.edge;
    final start = ui.Offset(
      edge.start.xTicks / terrainPhysicsTicksPerWorldUnit,
      edge.start.yTicks / terrainPhysicsTicksPerWorldUnit,
    );
    final end = ui.Offset(
      edge.end.xTicks / terrainPhysicsTicksPerWorldUnit,
      edge.end.yTicks / terrainPhysicsTicksPerWorldUnit,
    );
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    return _CachedTerrainDecoratedEdge(
      materialKey: decoration.materialKey,
      orientation: decoration.orientation,
      drawStartCap: decoration.drawStartCap,
      drawEndCap: decoration.drawEndCap,
      startUnderlapFactor: decoration.startUnderlapFactor,
      endUnderlapFactor: decoration.endUnderlapFactor,
      start: start,
      length: math.sqrt(dx * dx + dy * dy),
      angle: math.atan2(dy, dx),
      clipPath: clipPath,
      bounds: ui.Rect.fromLTRB(
        math.min(start.dx, end.dx) - 160,
        math.min(start.dy, end.dy) - 160,
        math.max(start.dx, end.dx) + 160,
        math.max(start.dy, end.dy) + 160,
      ),
    );
  }

  final String materialKey;
  final TerrainMaterialEdgeOrientation orientation;
  final bool drawStartCap;
  final bool drawEndCap;
  final double startUnderlapFactor;
  final double endUnderlapFactor;
  final ui.Offset start;
  final double length;
  final double angle;
  final ui.Path clipPath;
  final ui.Rect bounds;
}

final Float64List _identityMatrix = Float64List.fromList(<double>[
  1,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  1,
]);
