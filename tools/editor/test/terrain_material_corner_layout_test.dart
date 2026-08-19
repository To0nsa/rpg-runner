import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/shared/terrain_material_corner_layout.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';
import 'package:terrain_materials/terrain_materials.dart';

void main() {
  test('solid rectangle assigns four corners without double painting', () {
    final caps = resolveTerrainMaterialEdgeCornerCaps(
      shape: _shape(
        mode: TerrainSourceCollisionMode.solid,
        vertices: const <TerrainSourceVertexDef>[
          TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
          TerrainSourceVertexDef(xHalfPixels: 200, yHalfPixels: 0),
          TerrainSourceVertexDef(xHalfPixels: 200, yHalfPixels: 100),
          TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 100),
        ],
      ),
      material: _material,
      edgeOrientations: const <TerrainMaterialEdgeOrientation>[
        TerrainMaterialEdgeOrientation.top,
        TerrainMaterialEdgeOrientation.rightWall,
        TerrainMaterialEdgeOrientation.underside,
        TerrainMaterialEdgeOrientation.leftWall,
      ],
    );

    expect(caps, <TerrainMaterialEdgeCornerCaps>[
      (start: true, end: true),
      (start: false, end: false),
      (start: true, end: true),
      (start: false, end: false),
    ]);
  });

  test('one-way rectangle caps only the exposed top run', () {
    final caps = resolveTerrainMaterialEdgeCornerCaps(
      shape: _shape(
        mode: TerrainSourceCollisionMode.oneWay,
        vertices: const <TerrainSourceVertexDef>[
          TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
          TerrainSourceVertexDef(xHalfPixels: 200, yHalfPixels: 0),
          TerrainSourceVertexDef(xHalfPixels: 200, yHalfPixels: 100),
          TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 100),
        ],
      ),
      material: _material,
      edgeOrientations: const <TerrainMaterialEdgeOrientation>[
        TerrainMaterialEdgeOrientation.top,
        TerrainMaterialEdgeOrientation.rightWall,
        TerrainMaterialEdgeOrientation.underside,
        TerrainMaterialEdgeOrientation.leftWall,
      ],
    );

    expect(caps, <TerrainMaterialEdgeCornerCaps>[
      (start: true, end: true),
      (start: false, end: false),
      (start: false, end: false),
      (start: false, end: false),
    ]);
  });

  test('concave indentation remains band-only at its inner vertex', () {
    final caps = resolveTerrainMaterialEdgeCornerCaps(
      shape: _shape(
        mode: TerrainSourceCollisionMode.solid,
        vertices: const <TerrainSourceVertexDef>[
          TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
          TerrainSourceVertexDef(xHalfPixels: 200, yHalfPixels: 0),
          TerrainSourceVertexDef(xHalfPixels: 200, yHalfPixels: 200),
          TerrainSourceVertexDef(xHalfPixels: 100, yHalfPixels: 100),
          TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 200),
        ],
      ),
      material: _material,
      edgeOrientations: const <TerrainMaterialEdgeOrientation>[
        TerrainMaterialEdgeOrientation.top,
        TerrainMaterialEdgeOrientation.rightWall,
        TerrainMaterialEdgeOrientation.underside,
        TerrainMaterialEdgeOrientation.underside,
        TerrainMaterialEdgeOrientation.leftWall,
      ],
    );

    expect(caps[2].end, isFalse);
    expect(caps[3].start, isFalse);
  });
}

TerrainSourceShapeDef _shape({
  required TerrainSourceCollisionMode mode,
  required List<TerrainSourceVertexDef> vertices,
}) => TerrainSourceShapeDef(
  shapeId: 'ground',
  vertices: vertices,
  collisionMode: mode,
  surfaceKind: 'ground',
  materialKey: 'grass_dirt',
);

const _region = TerrainMaterialImageRegion(
  assetPath: 'assets/images/terrain/test.png',
  x: 0,
  y: 0,
  width: 32,
  height: 32,
);

const _profile = TerrainMaterialEdgeProfile(
  base: TerrainMaterialEdgeLayer(region: _region, anchorY: 0),
);

const _startCap = TerrainMaterialCap(region: _region, anchorX: 0, anchorY: 0);

const _endCap = TerrainMaterialCap(region: _region, anchorX: 32, anchorY: 0);

const _material = TerrainMaterialDefinition(
  key: 'grass_dirt',
  displayName: 'Grass / Dirt',
  revision: 1,
  fill: _region,
  top: _profile,
  leftWall: _profile,
  rightWall: _profile,
  underside: _profile,
  topStartCap: _startCap,
  topEndCap: _endCap,
  undersideStartCap: _startCap,
  undersideEndCap: _endCap,
);
