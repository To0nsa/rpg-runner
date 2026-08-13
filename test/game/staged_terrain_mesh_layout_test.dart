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
    expect(material.fillAssetPath, 'terrain/grass_dirt/fill.png');
    expect(material.top.base.assetPath, 'terrain/grass_dirt/surface.png');
    expect(material.top.base.anchorY, 12);
    expect(material.top.detail?.assetPath, 'terrain/grass_dirt/foreground.png');
    expect(material.topStartCap?.assetPath, 'terrain/grass_dirt/cap_left.png');
    expect(material.topEndCap?.assetPath, 'terrain/grass_dirt/cap_right.png');
    expect(material.leftWall, isNull);
    expect(material.rightWall, isNull);
    expect(material.underside, isNull);
    expect(
      () => TerrainMaterialRegistry.require('missing_material'),
      throwsStateError,
    );
  });
}
