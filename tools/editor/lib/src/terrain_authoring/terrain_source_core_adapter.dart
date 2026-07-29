import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_source_canonicalizer.dart';

import 'terrain_source_models.dart';

/// Pure conversion boundary from editor source values to Core terrain input.
///
/// Coordinates remain integer half-pixel ticks throughout this adapter. It
/// performs no JSON, widget, or filesystem work and delegates every geometric
/// predicate to Core.
abstract final class TerrainSourceCoreAdapter {
  /// Converts one editor [shape] to the authoritative Core input contract.
  static TerrainPolygonInput toPolygonInput({
    required TerrainSourceShapeDef shape,
    required String sourcePath,
    required int chunkIndex,
    required String chunkKey,
    String? placementKey,
    TerrainSourceTransform transform = const TerrainSourceTransform(),
  }) {
    return TerrainPolygonInput(
      sourcePath: sourcePath,
      identity: TerrainSourceIdentity(
        chunkIndex: chunkIndex,
        chunkKey: chunkKey,
        placementKey: placementKey,
        shapeId: shape.shapeId,
      ),
      vertices: shape.vertices.map(
        (vertex) => SourceTerrainPoint(vertex.xHalfPixels, vertex.yHalfPixels),
      ),
      collisionMode: switch (shape.collisionMode) {
        TerrainSourceCollisionMode.solid => TerrainCollisionMode.solid,
        TerrainSourceCollisionMode.oneWay => TerrainCollisionMode.oneWay,
      },
      surfaceKind: shape.surfaceKind,
      materialKey: shape.materialKey,
      transform: transform,
    );
  }

  /// Builds the one exact Core placement transform from editor integer values.
  ///
  /// Anchor and translation values use the editor's half-pixel source ticks.
  /// [scaleTenths] is the existing authored `0.3` through `3.0` scale encoded
  /// as `3` through `30`; Core validates the accepted range.
  static TerrainSourceTransform placementTransform({
    required int anchorXHalfPixels,
    required int anchorYHalfPixels,
    required int translationXHalfPixels,
    required int translationYHalfPixels,
    required int scaleTenths,
    bool flipX = false,
    bool flipY = false,
  }) {
    final transform = TerrainSourceTransform(
      anchorXSourceTicks: anchorXHalfPixels,
      anchorYSourceTicks: anchorYHalfPixels,
      reflectX: flipX,
      reflectY: flipY,
      scaleNumerator: scaleTenths,
      scaleDenominator: 10,
      translateXSourceTicks: translationXHalfPixels,
      translateYSourceTicks: translationYHalfPixels,
    );
    final _ = transform.scaleTenths;
    return transform;
  }

  /// Runs Core's exact review without changing the editor [shape].
  static TerrainSourceCanonicalizationResult review({
    required TerrainSourceShapeDef shape,
    required String sourcePath,
    required int chunkIndex,
    required String chunkKey,
    String? placementKey,
    bool normalizeCollinear = false,
    bool requireCanonical = false,
  }) {
    return const TerrainSourceCanonicalizer().review(
      toPolygonInput(
        shape: shape,
        sourcePath: sourcePath,
        chunkIndex: chunkIndex,
        chunkKey: chunkKey,
        placementKey: placementKey,
      ),
      normalizeCollinear: normalizeCollinear,
      requireCanonical: requireCanonical,
    );
  }

  /// Returns [shape] with a reviewed canonical loop applied explicitly.
  ///
  /// This is intended for an undoable Normalize/quick-fix command. It throws
  /// when Core could not produce a safe loop and never mutates [shape].
  static TerrainSourceShapeDef applyCanonicalVertices(
    TerrainSourceShapeDef shape,
    TerrainSourceCanonicalizationResult review,
  ) {
    final vertices = review.canonicalVertices;
    if (vertices == null) {
      throw StateError('Core review did not produce a safe canonical loop.');
    }
    return TerrainSourceShapeDef(
      shapeId: shape.shapeId,
      vertices: vertices.map(
        (vertex) => TerrainSourceVertexDef(
          xHalfPixels: vertex.xTicks,
          yHalfPixels: vertex.yTicks,
        ),
      ),
      collisionMode: shape.collisionMode,
      surfaceKind: shape.surfaceKind,
      materialKey: shape.materialKey,
    );
  }
}
