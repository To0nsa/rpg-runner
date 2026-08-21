import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/snapshots/staged_terrain_render_snapshot.dart';

import 'package:rpg_runner/game/components/staged_terrain_mesh_layout.dart';
import 'package:rpg_runner/game/themes/terrain_material_registry.dart';

void main() {
  test('mesh layout preserves Core vertex and triangle order exactly', () {
    final snapshot = StagedTerrainRenderSnapshot(
      geometryVersion: 7,
      polygons: <StagedTerrainPolygonRenderSnapshot>[
        StagedTerrainPolygonRenderSnapshot(
          sourceId: TerrainSourceIdentity(
            chunkIndex: 3,
            chunkKey: 'forest_early_flat',
            shapeId: 'ground_001',
          ),
          vertices: <TerrainPoint>[
            TerrainPoint(0, 229376),
            TerrainPoint(614400, 229376),
            TerrainPoint(614400, 276480),
            TerrainPoint(0, 276480),
          ],
          triangles: const <StagedTerrainRenderTriangleSnapshot>[
            StagedTerrainRenderTriangleSnapshot(first: 0, second: 1, third: 2),
            StagedTerrainRenderTriangleSnapshot(first: 0, second: 2, third: 3),
          ],
          materialKey: 'grass_dirt',
        ),
      ],
      edges: const [],
    );

    final mesh = StagedTerrainMeshLayout.build(snapshot).single;

    expect(mesh.sourceId.chunkIndex, 3);
    expect(mesh.materialKey, 'grass_dirt');
    expect(mesh.positions.map((position) => position.dx), <double>[
      0,
      600,
      600,
      0,
    ]);
    expect(mesh.positions.map((position) => position.dy), <double>[
      224,
      224,
      270,
      270,
    ]);
    expect(mesh.triangleIndices, <int>[0, 1, 2, 0, 2, 3]);
  });

  test('mesh layout rejects a Core index outside its supplied loop', () {
    final snapshot = StagedTerrainRenderSnapshot(
      geometryVersion: 1,
      polygons: <StagedTerrainPolygonRenderSnapshot>[
        StagedTerrainPolygonRenderSnapshot(
          sourceId: TerrainSourceIdentity(
            chunkIndex: 0,
            chunkKey: 'field_flat',
            shapeId: 'ground_001',
          ),
          vertices: <TerrainPoint>[
            TerrainPoint(0, 0),
            TerrainPoint(1024, 0),
            TerrainPoint(0, 1024),
          ],
          triangles: const <StagedTerrainRenderTriangleSnapshot>[
            StagedTerrainRenderTriangleSnapshot(first: 0, second: 1, third: 3),
          ],
          materialKey: 'grass_dirt',
        ),
      ],
      edges: const [],
    );

    expect(() => StagedTerrainMeshLayout.build(snapshot), throwsStateError);
  });

  test('material registry resolves authored grass dirt assets centrally', () {
    final material = TerrainMaterialRegistry.require('grass_dirt');

    expect(material.displayName, 'Grass / Dirt');
    expect(material.revision, 9);
    expect(material.fill.assetPath, 'terrain/tx_tileset_ground/atlas.png');
    expect((material.fill.x, material.fill.y), (224, 192));
    expect(
      material.top.base.region.assetPath,
      'terrain/tx_tileset_ground/atlas.png',
    );
    expect((material.top.base.region.x, material.top.base.region.y), (32, 0));
    expect(material.top.base.anchorY, 1);
    expect(material.topStartCap?.anchorY, 1);
    expect(material.topEndCap?.anchorY, 1);
    expect(material.top.detail, isNull);
    expect(
      (material.topStartCap?.region.x, material.topStartCap?.anchorX),
      (0, 0),
    );
    expect(
      (material.topEndCap?.region.x, material.topEndCap?.anchorX),
      (64, 32),
    );
    expect(
      (material.leftWall?.base.region.x, material.leftWall?.base.region.y),
      (192, 192),
    );
    expect(material.leftWall?.base.anchorY, 1);
    expect(
      (material.rightWall?.base.region.x, material.rightWall?.base.region.y),
      (256, 192),
    );
    expect(material.rightWall?.base.anchorY, 1);
    expect(
      (material.underside?.base.region.x, material.underside?.base.region.y),
      (32, 64),
    );
    expect(material.underside?.base.anchorY, 1);
    expect(
      (
        material.undersideStartCap?.region.x,
        material.undersideStartCap?.region.y,
        material.undersideStartCap?.anchorX,
        material.undersideStartCap?.anchorY,
      ),
      (64, 64, 0, 1),
    );
    expect(
      (
        material.undersideEndCap?.region.x,
        material.undersideEndCap?.region.y,
        material.undersideEndCap?.anchorX,
        material.undersideEndCap?.anchorY,
      ),
      (0, 64, 32, 1),
    );
    expect(
      () => TerrainMaterialRegistry.require('missing_material'),
      throwsStateError,
    );
  });
}
