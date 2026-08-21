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
    expect(material.revision, 10);
    expect(material.fill.assetPath, 'terrain/tx_tileset_ground/atlas.png');
    expect((material.fill.x, material.fill.y), (224, 192));
    expect(
      material.top.base.region.assetPath,
      'terrain/tx_tileset_ground/atlas.png',
    );
    expect(
      (
        material.top.base.region.x,
        material.top.base.region.y,
        material.top.base.region.width,
        material.top.base.region.height,
      ),
      (32, 1, 32, 31),
    );
    expect(material.top.base.anchorY, 0);
    expect(material.top.detail, isNull);
    expect(
      (
        material.topStartCap?.region.x,
        material.topStartCap?.region.y,
        material.topStartCap?.region.height,
        material.topStartCap?.anchorX,
        material.topStartCap?.anchorY,
      ),
      (0, 1, 31, 0, 0),
    );
    expect(
      (
        material.topEndCap?.region.x,
        material.topEndCap?.region.y,
        material.topEndCap?.region.height,
        material.topEndCap?.anchorX,
        material.topEndCap?.anchorY,
      ),
      (64, 1, 31, 32, 0),
    );
    expect(
      (
        material.leftWall?.base.region.x,
        material.leftWall?.base.region.y,
        material.leftWall?.base.region.width,
        material.leftWall?.base.region.height,
      ),
      (193, 192, 31, 32),
    );
    expect(material.leftWall?.base.anchorY, 0);
    expect(
      (
        material.rightWall?.base.region.x,
        material.rightWall?.base.region.y,
        material.rightWall?.base.region.width,
        material.rightWall?.base.region.height,
      ),
      (256, 192, 31, 32),
    );
    expect(material.rightWall?.base.anchorY, 0);
    expect(
      (
        material.underside?.base.region.x,
        material.underside?.base.region.y,
        material.underside?.base.region.width,
        material.underside?.base.region.height,
      ),
      (32, 64, 32, 31),
    );
    expect(material.underside?.base.anchorY, 0);
    expect(
      (
        material.undersideStartCap?.region.x,
        material.undersideStartCap?.region.y,
        material.undersideStartCap?.region.height,
        material.undersideStartCap?.anchorX,
        material.undersideStartCap?.anchorY,
      ),
      (64, 64, 31, 0, 0),
    );
    expect(
      (
        material.undersideEndCap?.region.x,
        material.undersideEndCap?.region.y,
        material.undersideEndCap?.region.height,
        material.undersideEndCap?.anchorX,
        material.undersideEndCap?.anchorY,
      ),
      (0, 64, 31, 32, 0),
    );
    expect(
      () => TerrainMaterialRegistry.require('missing_material'),
      throwsStateError,
    );
  });
}
