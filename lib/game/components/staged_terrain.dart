import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:runner_core/collision/terrain/terrain_edge.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/snapshots/staged_terrain_render_snapshot.dart';

import '../game_controller.dart';
import '../spatial/world_view_transform.dart';
import '../themes/terrain_material_registry.dart';
import '../util/math_util.dart';
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
  List<_CachedTerrainMesh> _meshes = const <_CachedTerrainMesh>[];
  List<_CachedTerrainSurfaceEdge> _surfaceEdges =
      const <_CachedTerrainSurfaceEdge>[];
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

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (final spec in TerrainMaterialRegistry.byKey.values) {
      final images = await Future.wait<ui.Image>(<Future<ui.Image>>[
        game.images.load(spec.fillAssetPath),
        game.images.load(spec.surfaceAssetPath),
        game.images.load(spec.foregroundAssetPath),
      ]);
      _materials[spec.key] = _LoadedTerrainMaterial(
        spec: spec,
        fill: images[0],
        surface: images[1],
        foreground: images[2],
      );
    }
    _assetsReady = true;
    _syncSnapshot(controller.snapshot.stagedTerrainRenderSnapshot);
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
      _drawEdgeImage(
        canvas,
        edge: edge,
        image: material.surface,
        anchorY: material.spec.surfaceAnchorY,
      );
      _drawEdgeImage(
        canvas,
        edge: edge,
        image: material.foreground,
        anchorY: 0,
      );
    }

    canvas.restore();
  }

  void _syncSnapshot(StagedTerrainRenderSnapshot? snapshot) {
    if (snapshot == null) {
      _geometryVersion = null;
      _meshes = const <_CachedTerrainMesh>[];
      _surfaceEdges = const <_CachedTerrainSurfaceEdge>[];
      return;
    }
    if (_geometryVersion == snapshot.geometryVersion) return;

    final meshes = <_CachedTerrainMesh>[];
    for (final mesh in StagedTerrainMeshLayout.build(snapshot)) {
      TerrainMaterialRegistry.require(mesh.materialKey);
      if (mesh.positions.isEmpty || mesh.triangleIndices.isEmpty) continue;
      meshes.add(_CachedTerrainMesh.fromData(mesh));
    }

    final surfaceEdges = <_CachedTerrainSurfaceEdge>[];
    for (final edge in snapshot.edges) {
      final materialKey = edge.materialKey;
      if (materialKey == null || edge.outwardNormal.yTicks >= 0) continue;
      TerrainMaterialRegistry.require(materialKey);
      surfaceEdges.add(_CachedTerrainSurfaceEdge.fromCore(edge, materialKey));
    }

    _meshes = List<_CachedTerrainMesh>.unmodifiable(meshes);
    _surfaceEdges = List<_CachedTerrainSurfaceEdge>.unmodifiable(surfaceEdges);
    _geometryVersion = snapshot.geometryVersion;
  }

  void _drawEdgeImage(
    ui.Canvas canvas, {
    required _CachedTerrainSurfaceEdge edge,
    required ui.Image image,
    required double anchorY,
  }) {
    if (edge.length <= 0) return;
    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();
    final phase = positiveModDouble(edge.start.dx, imageWidth);

    canvas.save();
    canvas.translate(edge.start.dx, edge.start.dy);
    canvas.rotate(edge.angle);
    canvas.clipRect(ui.Rect.fromLTWH(0, -anchorY, edge.length, imageHeight));
    for (var x = -phase; x < edge.length; x += imageWidth) {
      canvas.drawImage(image, ui.Offset(x, -anchorY), _edgePaint);
    }
    canvas.restore();
  }

  static final Paint _edgePaint = Paint()..filterQuality = FilterQuality.none;
}

final class _LoadedTerrainMaterial {
  _LoadedTerrainMaterial({
    required this.spec,
    required ui.Image fill,
    required this.surface,
    required this.foreground,
  }) : fillPaint = Paint()
         ..filterQuality = FilterQuality.none
         ..shader = ui.ImageShader(
           fill,
           ui.TileMode.repeated,
           ui.TileMode.repeated,
           _identityMatrix,
           filterQuality: ui.FilterQuality.none,
         );

  final TerrainMaterialSpec spec;
  final Paint fillPaint;
  final ui.Image surface;
  final ui.Image foreground;
}

final class _CachedTerrainMesh {
  _CachedTerrainMesh({
    required this.materialKey,
    required this.vertices,
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
    return _CachedTerrainMesh(
      materialKey: data.materialKey,
      vertices: ui.Vertices(
        ui.VertexMode.triangles,
        data.positions,
        indices: data.triangleIndices,
      ),
      bounds: ui.Rect.fromLTRB(minX, minY, maxX, maxY),
    );
  }

  final String materialKey;
  final ui.Vertices vertices;
  final ui.Rect bounds;
}

final class _CachedTerrainSurfaceEdge {
  const _CachedTerrainSurfaceEdge({
    required this.materialKey,
    required this.start,
    required this.length,
    required this.angle,
    required this.bounds,
  });

  factory _CachedTerrainSurfaceEdge.fromCore(
    TerrainEdge edge,
    String materialKey,
  ) {
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
    return _CachedTerrainSurfaceEdge(
      materialKey: materialKey,
      start: start,
      length: math.sqrt(dx * dx + dy * dy),
      angle: math.atan2(dy, dx),
      bounds: ui.Rect.fromLTRB(
        math.min(start.dx, end.dx),
        math.min(start.dy, end.dy) - 52,
        math.max(start.dx, end.dx),
        math.max(start.dy, end.dy) + 52,
      ),
    );
  }

  final String materialKey;
  final ui.Offset start;
  final double length;
  final double angle;
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
