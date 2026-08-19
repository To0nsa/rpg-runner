import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_polygon_contact_constraint.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_polygon_interaction.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  test('point placement snaps to contact and rejects occupied interiors', () {
    final target = TerrainAuthoringCollisionLoop.fromSourceShape(
      stableKey: 'direct:ground',
      shape: _rectangle('ground', left: 20, top: 20, right: 100, bottom: 80),
    );

    expect(
      TerrainPolygonContactConstraint.resolvePoint(
        desired: _vertex(110, 40),
        targets: <TerrainAuthoringCollisionLoop>[target],
        snapStepHalfPixels: 2,
        snapRadiusHalfPixels: 12,
      ),
      _vertex(100, 40),
    );
    expect(
      TerrainPolygonContactConstraint.resolvePoint(
        desired: _vertex(60, 40),
        targets: <TerrainAuthoringCollisionLoop>[target],
        snapStepHalfPixels: 2,
        snapRadiusHalfPixels: 0,
      ),
      isNull,
    );
    expect(
      TerrainPolygonContactConstraint.resolvePoint(
        desired: _vertex(100, 40),
        targets: <TerrainAuthoringCollisionLoop>[target],
        snapStepHalfPixels: 2,
        snapRadiusHalfPixels: 0,
      ),
      _vertex(100, 40),
    );
  });

  test('transformed boundary uses nearest non-overlapping source point', () {
    final target = TerrainAuthoringCollisionLoop(
      stableKey: 'expanded:rock:collision_001',
      vertices: <TerrainPoint>[
        _physicsFromHalfPixels(100, extraTicks: 128, yHalfPixels: 20),
        _physicsFromHalfPixels(160, extraTicks: 128, yHalfPixels: 20),
        _physicsFromHalfPixels(160, extraTicks: 128, yHalfPixels: 80),
        _physicsFromHalfPixels(100, extraTicks: 128, yHalfPixels: 80),
      ],
      collisionMode: TerrainCollisionMode.solid,
    );

    expect(
      TerrainPolygonContactConstraint.resolvePoint(
        desired: _vertex(94, 40),
        targets: <TerrainAuthoringCollisionLoop>[target],
        snapStepHalfPixels: 2,
        snapRadiusHalfPixels: 10,
      ),
      _vertex(100, 40),
    );
  });

  test('shape translation clamps at the first legal solid contact', () {
    final moving = _rectangle(
      'moving',
      left: 0,
      top: 20,
      right: 20,
      bottom: 40,
    );
    final target = TerrainAuthoringCollisionLoop.fromSourceShape(
      stableKey: 'direct:target',
      shape: _rectangle('target', left: 40, top: 20, right: 80, bottom: 60),
    );
    final gesture = TerrainPolygonGesture(
      pointer: 1,
      kind: TerrainPolygonGestureKind.translateShape,
      originalShape: moving,
      previewShape: moving,
      startPointer: _vertex(0, 0),
      activeVertexIndex: null,
    );

    TerrainSourceShapeDef preview(TerrainSourceVertexDef pointer) =>
        _translate(moving, pointer.xHalfPixels, pointer.yHalfPixels);

    final resolved = TerrainPolygonContactConstraint.resolveGesturePointer(
      gesture: gesture,
      desired: _vertex(30, 0),
      targets: <TerrainAuthoringCollisionLoop>[target],
      snapStepHalfPixels: 2,
      snapRadiusHalfPixels: 8,
      buildPreview: preview,
      isCandidateInBounds: (_) => true,
    );
    expect((resolved.xHalfPixels, resolved.yHalfPixels), (20, 0));
  });

  test('shape translation cannot tunnel through collision', () {
    final moving = _rectangle(
      'moving',
      left: 0,
      top: 20,
      right: 20,
      bottom: 40,
    );
    final target = TerrainAuthoringCollisionLoop.fromSourceShape(
      stableKey: 'direct:target',
      shape: _rectangle('target', left: 40, top: 20, right: 80, bottom: 60),
    );
    final gesture = TerrainPolygonGesture(
      pointer: 1,
      kind: TerrainPolygonGestureKind.translateShape,
      originalShape: moving,
      previewShape: moving,
      startPointer: _vertex(0, 0),
      activeVertexIndex: null,
    );

    TerrainSourceShapeDef preview(TerrainSourceVertexDef pointer) =>
        _translate(moving, pointer.xHalfPixels, pointer.yHalfPixels);

    final resolved = TerrainPolygonContactConstraint.resolveGesturePointer(
      gesture: gesture,
      desired: _vertex(100, 0),
      targets: <TerrainAuthoringCollisionLoop>[target],
      snapStepHalfPixels: 2,
      snapRadiusHalfPixels: 8,
      buildPreview: preview,
      isCandidateInBounds: (_) => true,
    );
    expect((resolved.xHalfPixels, resolved.yHalfPixels), (20, 0));
  });

  test('non-solid loops block interiors without attracting seams', () {
    for (final mode in <TerrainSourceCollisionMode>[
      TerrainSourceCollisionMode.oneWay,
      TerrainSourceCollisionMode.none,
    ]) {
      final target = TerrainAuthoringCollisionLoop.fromSourceShape(
        stableKey: 'direct:${mode.name}',
        shape: _rectangle(
          'non_solid_${mode.index}',
          left: 40,
          top: 20,
          right: 80,
          bottom: 60,
          collisionMode: mode,
        ),
      );

      expect(
        TerrainPolygonContactConstraint.resolvePoint(
          desired: _vertex(34, 40),
          targets: <TerrainAuthoringCollisionLoop>[target],
          snapStepHalfPixels: 2,
          snapRadiusHalfPixels: 10,
        ),
        _vertex(34, 40),
      );
      expect(
        TerrainPolygonContactConstraint.resolvePoint(
          desired: _vertex(60, 40),
          targets: <TerrainAuthoringCollisionLoop>[target],
          snapStepHalfPixels: 2,
          snapRadiusHalfPixels: 10,
        ),
        isNull,
      );
    }
  });
}

TerrainSourceShapeDef _rectangle(
  String shapeId, {
  required int left,
  required int top,
  required int right,
  required int bottom,
  TerrainSourceCollisionMode collisionMode = TerrainSourceCollisionMode.solid,
}) => TerrainSourceShapeDef(
  shapeId: shapeId,
  vertices: <TerrainSourceVertexDef>[
    _vertex(left, top),
    _vertex(right, top),
    _vertex(right, bottom),
    _vertex(left, bottom),
  ],
  collisionMode: collisionMode,
);

TerrainSourceShapeDef _translate(
  TerrainSourceShapeDef shape,
  int deltaX,
  int deltaY,
) => TerrainSourceShapeDef(
  shapeId: shape.shapeId,
  vertices: shape.vertices.map(
    (vertex) =>
        _vertex(vertex.xHalfPixels + deltaX, vertex.yHalfPixels + deltaY),
  ),
  collisionMode: shape.collisionMode,
  surfaceKind: shape.surfaceKind,
  materialKey: shape.materialKey,
);

TerrainSourceVertexDef _vertex(int x, int y) =>
    TerrainSourceVertexDef(xHalfPixels: x, yHalfPixels: y);

TerrainPoint _physicsFromHalfPixels(
  int xHalfPixels, {
  required int extraTicks,
  required int yHalfPixels,
}) => TerrainPoint(
  xHalfPixels *
          (terrainPhysicsTicksPerWorldUnit ~/ terrainSourceTicksPerWorldUnit) +
      extraTicks,
  yHalfPixels *
      (terrainPhysicsTicksPerWorldUnit ~/ terrainSourceTicksPerWorldUnit),
);
