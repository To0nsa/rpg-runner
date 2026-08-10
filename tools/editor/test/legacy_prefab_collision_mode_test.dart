import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/migration/legacy_prefab_collision_mode.dart';
import 'package:runner_editor/src/migration/legacy_prefab_collider_def.dart';
import 'package:runner_editor/src/migration/legacy_prefab_models.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  test('legacy obstacle and platform kinds own migrated sidedness', () {
    final source = _shape(TerrainSourceCollisionMode.oneWay);
    final obstacle = applyLegacyPrefabCollisionMode(
      prefab: _prefab(PrefabKind.obstacle),
      shapes: <TerrainSourceShapeDef>[source],
    ).single;
    final platform = applyLegacyPrefabCollisionMode(
      prefab: _prefab(PrefabKind.platform),
      shapes: <TerrainSourceShapeDef>[_shape(TerrainSourceCollisionMode.solid)],
    ).single;

    expect(obstacle.collisionMode, TerrainSourceCollisionMode.solid);
    expect(platform.collisionMode, TerrainSourceCollisionMode.oneWay);
    expect(platform.shapeId, source.shapeId);
    expect(platform.vertices, source.vertices);
    expect(platform.surfaceKind, 'wood');
    expect(platform.materialKey, 'oak');
  });

  test('non-colliding legacy kinds fail closed when geometry is present', () {
    for (final kind in <PrefabKind>[
      PrefabKind.decoration,
      PrefabKind.unknown,
    ]) {
      expect(
        () => applyLegacyPrefabCollisionMode(
          prefab: _prefab(kind),
          shapes: <TerrainSourceShapeDef>[
            _shape(TerrainSourceCollisionMode.solid),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        applyLegacyPrefabCollisionMode(
          prefab: _prefab(kind),
          shapes: const <TerrainSourceShapeDef>[],
        ),
        isEmpty,
      );
    }
  });
}

LegacyPrefabDef _prefab(PrefabKind kind) => LegacyPrefabDef(
  prefabKey: 'prefab',
  id: 'prefab',
  revision: 1,
  status: PrefabStatus.active,
  kind: kind,
  visualSource: const PrefabVisualSource.atlasSlice('slice'),
  anchorXPx: 0,
  anchorYPx: 0,
  colliders: const <PrefabColliderDef>[],
  tags: const <String>[],
);

TerrainSourceShapeDef _shape(TerrainSourceCollisionMode mode) =>
    TerrainSourceShapeDef(
      shapeId: 'collision_001',
      vertices: const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 20),
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 20),
      ],
      collisionMode: mode,
      surfaceKind: 'wood',
      materialKey: 'oak',
    );
