import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_core_adapter.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  test('adapts exact coordinates, identity, mode, and metadata', () {
    final shape = TerrainSourceShapeDef(
      shapeId: 'bridge_001',
      vertices: const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: -1, yHalfPixels: 3),
        TerrainSourceVertexDef(xHalfPixels: 7, yHalfPixels: 3),
        TerrainSourceVertexDef(xHalfPixels: 7, yHalfPixels: 5),
        TerrainSourceVertexDef(xHalfPixels: -1, yHalfPixels: 5),
      ],
      collisionMode: TerrainSourceCollisionMode.oneWay,
      surfaceKind: 'wood',
      materialKey: 'forest_bridge',
    );

    final input = TerrainSourceCoreAdapter.toPolygonInput(
      shape: shape,
      sourcePath: 'prefabs/bridge_001',
      chunkIndex: 4,
      chunkKey: 'forest_early_00',
      placementKey: 'placement_007',
    );

    expect(input.sourcePath, 'prefabs/bridge_001');
    expect(input.identity.chunkIndex, 4);
    expect(input.identity.chunkKey, 'forest_early_00');
    expect(input.identity.placementKey, 'placement_007');
    expect(input.identity.shapeId, 'bridge_001');
    expect(input.collisionMode, TerrainCollisionMode.oneWay);
    expect(input.surfaceKind, 'wood');
    expect(input.materialKey, 'forest_bridge');
    expect(
      input.vertices
          .map((vertex) => (vertex.xTicks, vertex.yTicks))
          .toList(growable: false),
      <(int, int)>[(-1, 3), (7, 3), (7, 5), (-1, 5)],
    );
  });

  test('delegates canonical diagnostics and explicit repair to Core', () {
    final rotated = TerrainSourceShapeDef(
      shapeId: 'ground_001',
      vertices: const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 8),
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 8),
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 0),
      ],
      collisionMode: TerrainSourceCollisionMode.solid,
      surfaceKind: 'grass',
    );

    final review = TerrainSourceCoreAdapter.review(
      shape: rotated,
      sourcePath: 'chunks/field_flat.json',
      chunkIndex: 0,
      chunkKey: 'field_flat',
      requireCanonical: true,
    );
    final repaired = TerrainSourceCoreAdapter.applyCanonicalVertices(
      rotated,
      review,
    );

    expect(review.diagnostics.map((diagnostic) => diagnostic.code), <String>[
      'noncanonical_start',
    ]);
    expect(repaired.shapeId, rotated.shapeId);
    expect(repaired.collisionMode, rotated.collisionMode);
    expect(repaired.surfaceKind, rotated.surfaceKind);
    expect(repaired.vertices, const <TerrainSourceVertexDef>[
      TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
      TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 0),
      TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 8),
      TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 8),
    ]);
  });

  test('explicit collinear normalization preserves exact half-unit ticks', () {
    final shape = TerrainSourceShapeDef(
      shapeId: 'slope_001',
      vertices: const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: -3, yHalfPixels: 5),
        TerrainSourceVertexDef(xHalfPixels: 1, yHalfPixels: 5),
        TerrainSourceVertexDef(xHalfPixels: 5, yHalfPixels: 5),
        TerrainSourceVertexDef(xHalfPixels: 5, yHalfPixels: 9),
        TerrainSourceVertexDef(xHalfPixels: -3, yHalfPixels: 9),
      ],
    );

    final review = TerrainSourceCoreAdapter.review(
      shape: shape,
      sourcePath: 'prefabs/slope_001',
      chunkIndex: 0,
      chunkKey: 'preview',
      normalizeCollinear: true,
      requireCanonical: true,
    );
    final normalized = TerrainSourceCoreAdapter.applyCanonicalVertices(
      shape,
      review,
    );

    expect(review.hasBlockingDiagnostics, isFalse);
    expect(review.diagnostics.single.code, 'normalized_collinear_vertex');
    expect(
      normalized.vertices
          .map((vertex) => (vertex.xHalfPixels, vertex.yHalfPixels))
          .toList(growable: false),
      <(int, int)>[(-3, 5), (5, 5), (5, 9), (-3, 9)],
    );
  });

  test('does not fabricate a quick fix for unsafe geometry', () {
    final crossing = TerrainSourceShapeDef(
      shapeId: 'crossing',
      vertices: const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 8),
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 8),
        TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 0),
      ],
    );
    final review = TerrainSourceCoreAdapter.review(
      shape: crossing,
      sourcePath: 'test/crossing',
      chunkIndex: 0,
      chunkKey: 'preview',
    );

    expect(review.canonicalVertices, isNull);
    expect(
      () => TerrainSourceCoreAdapter.applyCanonicalVertices(crossing, review),
      throwsStateError,
    );
  });

  test('builds and applies the exact Core placement transform once', () {
    final shape = TerrainSourceShapeDef(
      shapeId: 'asymmetric',
      vertices: const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 5, yHalfPixels: 3),
        TerrainSourceVertexDef(xHalfPixels: 9, yHalfPixels: 3),
        TerrainSourceVertexDef(xHalfPixels: 5, yHalfPixels: 7),
      ],
    );
    final transform = TerrainSourceCoreAdapter.placementTransform(
      anchorXHalfPixels: 2,
      anchorYHalfPixels: -4,
      translationXHalfPixels: 6,
      translationYHalfPixels: -8,
      scaleTenths: 7,
      flipX: true,
      flipY: true,
    );
    final input = TerrainSourceCoreAdapter.toPolygonInput(
      shape: shape,
      sourcePath: 'test/asymmetric',
      chunkIndex: 2,
      chunkKey: 'chunk_2',
      placementKey: 'placement_3',
      transform: transform,
    );

    expect(input.transform, same(transform));
    expect(input.transform.scaleTenths, 7);
    expect(
      input.transform.apply(input.vertices.first),
      TerrainPoint(1997, -6605),
    );
  });

  test('rejects placement scale outside the accepted integer tenths', () {
    for (final scaleTenths in <int>[2, 31]) {
      expect(
        () => TerrainSourceCoreAdapter.placementTransform(
          anchorXHalfPixels: 0,
          anchorYHalfPixels: 0,
          translationXHalfPixels: 0,
          translationYHalfPixels: 0,
          scaleTenths: scaleTenths,
        ),
        throwsRangeError,
      );
    }
  });
}
