import 'package:runner_core/collision/terrain/terrain_authoring_capacity.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:test/test.dart';

void main() {
  test('freezes authoring targets below their matching hard limits', () {
    expect(TerrainAuthoringCapacityTargets.shapesPerPrefab, 16);
    expect(TerrainAuthoringCapacityTargets.verticesPerShape, 24);
    expect(TerrainAuthoringCapacityTargets.exposedEdgesPerChunk, 1024);

    expect(
      TerrainAuthoringCapacityTargets.shapesPerPrefab,
      lessThan(TerrainGeometryLimits.maxShapesPerPrefab),
    );
    expect(
      TerrainAuthoringCapacityTargets.verticesPerShape,
      lessThan(TerrainGeometryLimits.maxVerticesPerShape),
    );
    expect(
      TerrainAuthoringCapacityTargets.exposedEdgesPerChunk,
      lessThan(TerrainGeometryLimits.maxExposedEdgesPerChunk),
    );
  });
}
