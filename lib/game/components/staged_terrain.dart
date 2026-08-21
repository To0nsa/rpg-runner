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
    // Source-replacement establishes semantic ownership between fill, edge,
    // and cap art. Isolating terrain keeps transparent authored pixels from
    // clearing scene content that was painted before this component.
    canvas.saveLayer(visibleWorldRect, _terrainLayerPaint);

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
        blendMode: ui.BlendMode.src,
      );
      _drawEdgeSeamBacking(
        canvas,
        edge: edge,
        fillPaint: material.seamBackingPaint,
      );
      if (profile.detail case final detail?) {
        _drawEdgeImage(
          canvas,
          edge: edge,
          image: material.imageFor(detail.region),
          anchorY: detail.anchorY,
          orientation: edge.orientation,
          blendMode: ui.BlendMode.srcOver,
        );
      }
    }
    // Generic convex turns retain fill behind their local edge overlap. This
    // runs after every band so no later source-replacement pass can reopen the
    // join, and before authored rectangle caps establish their final shape.
    for (final edge in _surfaceEdges) {
      if (!edge.bounds.overlaps(visibleWorldRect) ||
          edge.endJoinBackingDepth == null) {
        continue;
      }
      _drawConnectedJoinBacking(
        canvas,
        edge: edge,
        fillPaint: _materials[edge.materialKey]!.seamBackingPaint,
      );
    }
    // Endpoint and cardinal-corner art is a foreground pass so adjacent bands
    // cannot obscure the authored rectangle join selected by the resolver.
    for (final edge in _surfaceEdges) {
      if (!edge.bounds.overlaps(visibleWorldRect) ||
          (!edge.drawStartCap && !edge.drawEndCap)) {
        continue;
      }
      final material = _materials[edge.materialKey]!;
      final caps = StagedTerrainEdgeLayout.capsFor(
        material.spec,
        edge.orientation,
      );
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
      final cachedEdge = _CachedTerrainDecoratedEdge.fromLayout(
        decoration,
        ownerMesh: ownerMesh,
      );
      surfaceEdges.add(cachedEdge);
    }

    final edgePaintOrder = terrainMaterialEdgePaintOrder(
      surfaceEdges.map((edge) => edge.orientation),
    );
    final orderedSurfaceEdges = List<_CachedTerrainDecoratedEdge>.unmodifiable(
      edgePaintOrder.map((index) => surfaceEdges[index]),
    );
    for (final edge in orderedSurfaceEdges) {
      final material = TerrainMaterialRegistry.require(edge.materialKey);
      final profile = StagedTerrainEdgeLayout.profileFor(
        material,
        edge.orientation,
      )!;
      edge.seamBackingPath = terrainMaterialEdgeSeamBackingPath(
        start: edge.start,
        length: edge.length,
        angle: edge.angle,
        sourceWidth: profile.base.region.width,
        sourceHeight: profile.base.region.height,
        anchorY: profile.base.anchorY,
        orientation: edge.orientation,
      );
    }

    _meshes = List<_CachedTerrainMesh>.unmodifiable(meshes);
    _surfaceEdges = orderedSurfaceEdges;
    _geometryVersion = snapshot.geometryVersion;
  }

  void _drawEdgeImage(
    ui.Canvas canvas, {
    required _CachedTerrainDecoratedEdge edge,
    required ui.Image image,
    required double anchorY,
    required TerrainMaterialEdgeOrientation orientation,
    required ui.BlendMode blendMode,
  }) => paintTerrainMaterialEdgeImage(
    canvas,
    start: edge.start,
    length: edge.length,
    angle: edge.angle,
    image: image,
    anchorY: anchorY,
    orientation: orientation,
    clipPath: edge.ownerMesh.clipPath,
    blendMode: blendMode,
  );

  void _drawEdgeSeamBacking(
    ui.Canvas canvas, {
    required _CachedTerrainDecoratedEdge edge,
    required ui.Paint fillPaint,
  }) {
    if (edge.seamBackingPath.getBounds().isEmpty) return;
    canvas.save();
    canvas.clipPath(edge.ownerMesh.clipPath);
    canvas.clipPath(edge.seamBackingPath);
    canvas.drawRect(edge.ownerMesh.bounds, fillPaint);
    canvas.restore();
  }

  void _drawConnectedJoinBacking(
    ui.Canvas canvas, {
    required _CachedTerrainDecoratedEdge edge,
    required ui.Paint fillPaint,
  }) {
    final depth = edge.endJoinBackingDepth;
    if (depth == null || depth <= 0) return;
    canvas.save();
    canvas.clipPath(edge.ownerMesh.clipPath);
    canvas.drawCircle(edge.end, depth, fillPaint);
    canvas.restore();
  }

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
    clipPath: edge.ownerMesh.clipPath,
    blendMode: ui.BlendMode.src,
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
/// confines the complete edge band to its owning polygon.
@visibleForTesting
void paintTerrainMaterialEdgeImage(
  ui.Canvas canvas, {
  required ui.Offset start,
  required double length,
  required double angle,
  required ui.Image image,
  required double anchorY,
  required TerrainMaterialEdgeOrientation orientation,
  ui.Path? clipPath,
  ui.BlendMode blendMode = ui.BlendMode.srcOver,
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
  final firstTileX = terrainMaterialTileStart(phase, tileWidth) - phase;

  canvas.save();
  if (clipPath != null) canvas.clipPath(clipPath);
  canvas.translate(start.dx, start.dy);
  canvas.rotate(angle);
  canvas.clipRect(ui.Rect.fromLTWH(0, -anchorY, length, tileHeight));
  for (var x = firstTileX; x < length; x += tileWidth) {
    _drawNormalizedEdgeImage(
      canvas,
      image: image,
      destination: ui.Offset(x, -anchorY),
      quarterTurns: quarterTurns,
      blendMode: blendMode,
    );
  }
  canvas.restore();
}

/// Paints one world-facing endpoint/corner cap after all repeating edge bands.
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
  ui.BlendMode blendMode = ui.BlendMode.srcOver,
}) {
  if (length <= 0) return;
  final footprint = terrainMaterialCapFootprint(
    edgeLength: length,
    anchorX: anchorX,
    anchorY: anchorY,
    atEnd: atEnd,
    orientation: orientation,
    sourceWidth: image.width,
    sourceHeight: image.height,
  );
  canvas.save();
  if (clipPath != null) canvas.clipPath(clipPath);
  canvas.translate(start.dx, start.dy);
  canvas.rotate(angle);
  _drawNormalizedEdgeImage(
    canvas,
    image: image,
    destination: ui.Offset(footprint.left, footprint.top),
    quarterTurns: terrainMaterialEdgeNormalizationQuarterTurns(orientation),
    blendMode: blendMode,
  );
  canvas.restore();
}

/// Returns fill-backed corridors at internal repeat boundaries for one edge.
///
/// Only one source pixel on either side of each seam is included; endpoints
/// and the remaining transparent silhouette stay unbacked.
@visibleForTesting
ui.Path terrainMaterialEdgeSeamBackingPath({
  required ui.Offset start,
  required double length,
  required double angle,
  required int sourceWidth,
  required int sourceHeight,
  required double anchorY,
  required TerrainMaterialEdgeOrientation orientation,
}) {
  final footprint = terrainMaterialEdgeFootprint(
    edgeLength: length,
    anchorY: anchorY,
    orientation: orientation,
    sourceWidth: sourceWidth,
    sourceHeight: sourceHeight,
  );
  final tangentX = math.cos(angle);
  final tangentY = math.sin(angle);
  final repeatWidth = terrainMaterialEdgeTileWidth(
    orientation: orientation,
    sourceWidth: sourceWidth,
    sourceHeight: sourceHeight,
  ).toDouble();
  final seams = terrainMaterialEdgeRepeatSeamOffsets(
    startX: start.dx,
    startY: start.dy,
    tangentX: tangentX,
    tangentY: tangentY,
    edgeLength: length,
    repeatWidth: repeatWidth,
  );
  final result = ui.Path();
  for (final seam in seams) {
    final left = math.max(
      0.0,
      seam - terrainMaterialRepeatSeamBackingHalfWidth,
    );
    final right = math.min(
      length,
      seam + terrainMaterialRepeatSeamBackingHalfWidth,
    );
    result.addPath(
      _terrainMaterialFootprintPath(
        start: start,
        angle: angle,
        left: left,
        top: footprint.top,
        width: right - left,
        height: footprint.height,
      ),
      ui.Offset.zero,
    );
  }
  return result;
}

ui.Path _terrainMaterialFootprintPath({
  required ui.Offset start,
  required double angle,
  required double left,
  required double top,
  required double width,
  required double height,
}) {
  final tangentX = math.cos(angle);
  final tangentY = math.sin(angle);
  ui.Offset toWorld(double x, double y) => ui.Offset(
    start.dx + x * tangentX - y * tangentY,
    start.dy + x * tangentY + y * tangentX,
  );
  final right = left + width;
  final bottom = top + height;
  final topLeft = toWorld(left, top);
  final path = ui.Path()..moveTo(topLeft.dx, topLeft.dy);
  for (final point in <ui.Offset>[
    toWorld(right, top),
    toWorld(right, bottom),
    toWorld(left, bottom),
  ]) {
    path.lineTo(point.dx, point.dy);
  }
  return path..close();
}

void _drawNormalizedEdgeImage(
  ui.Canvas canvas, {
  required ui.Image image,
  required ui.Offset destination,
  required int quarterTurns,
  required ui.BlendMode blendMode,
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
  canvas.drawImage(
    image,
    ui.Offset.zero,
    blendMode == ui.BlendMode.src ? _terrainSourcePaint : _terrainEdgePaint,
  );
  canvas.restore();
}

final Paint _terrainEdgePaint = Paint()..filterQuality = FilterQuality.none;
final Paint _terrainSourcePaint = Paint()
  ..filterQuality = FilterQuality.none
  ..blendMode = ui.BlendMode.src;
final Paint _terrainLayerPaint = Paint();

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
        ),
      seamBackingPaint = Paint()
        ..filterQuality = FilterQuality.none
        ..blendMode = ui.BlendMode.dstOver
        ..shader = ui.ImageShader(
          imagesByRegion[spec.fill]!,
          ui.TileMode.repeated,
          ui.TileMode.repeated,
          _identityMatrix,
          filterQuality: ui.FilterQuality.none,
        );

  final TerrainMaterialSpec spec;
  final Paint fillPaint;
  final Paint seamBackingPaint;
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
  _CachedTerrainDecoratedEdge({
    required this.materialKey,
    required this.orientation,
    required this.drawStartCap,
    required this.drawEndCap,
    required this.start,
    required this.end,
    required this.length,
    required this.angle,
    required this.endJoinBackingDepth,
    required this.ownerMesh,
    required this.bounds,
  });

  factory _CachedTerrainDecoratedEdge.fromLayout(
    StagedTerrainEdgeDecoration decoration, {
    required _CachedTerrainMesh ownerMesh,
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
      start: start,
      end: end,
      length: math.sqrt(dx * dx + dy * dy),
      angle: math.atan2(dy, dx),
      endJoinBackingDepth: decoration.endJoinBackingDepth,
      ownerMesh: ownerMesh,
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
  final ui.Offset start;
  final ui.Offset end;
  final double length;
  final double angle;
  final double? endJoinBackingDepth;
  final _CachedTerrainMesh ownerMesh;
  final ui.Rect bounds;
  ui.Path? _seamBackingPath;

  ui.Path get seamBackingPath {
    final path = _seamBackingPath;
    if (path == null) {
      throw StateError('Terrain edge is missing its seam-backing path.');
    }
    return path;
  }

  set seamBackingPath(ui.Path path) => _seamBackingPath = path;
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
