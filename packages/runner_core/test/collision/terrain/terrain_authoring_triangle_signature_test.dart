import 'package:runner_core/collision/terrain/terrain_authoring_triangle_signature.dart';
import 'package:test/test.dart';

void main() {
  test('records and digest are canonical across input order', () {
    final direct = TerrainAuthoringTriangleRecord(
      chunkKey: 'chunk_a',
      placementKey: null,
      shapeId: 'ground',
      first: 3,
      second: 0,
      third: 1,
    );
    final placed = TerrainAuthoringTriangleRecord(
      chunkKey: 'chunk_a',
      placementKey: 'ramp|10|20|0',
      shapeId: 'collision_001',
      first: 1,
      second: 2,
      third: 3,
    );

    final forward = <TerrainAuthoringTriangleRecord>[direct, placed];
    final reversed = forward.reversed;
    expect(canonicalTerrainAuthoringTriangleRecords(reversed), <String>[
      direct.canonicalRecord(),
      placed.canonicalRecord(),
    ]);
    expect(
      terrainAuthoringTriangleSignature(reversed),
      terrainAuthoringTriangleSignature(forward),
    );
    expect(
      terrainAuthoringTriangleSignature(
        const <TerrainAuthoringTriangleRecord>[],
      ),
      'e3b0c44298fc1c149afbf4c8996fb924'
      '27ae41e4649b934ca495991b7852b855',
    );
  });

  test('duplicate records and invalid identities fail closed', () {
    final record = TerrainAuthoringTriangleRecord(
      chunkKey: 'chunk_a',
      placementKey: null,
      shapeId: 'ground',
      first: 0,
      second: 1,
      third: 2,
    );

    expect(
      () => canonicalTerrainAuthoringTriangleRecords(
        <TerrainAuthoringTriangleRecord>[record, record],
      ),
      throwsArgumentError,
    );
    expect(
      () => TerrainAuthoringTriangleRecord(
        chunkKey: '',
        placementKey: null,
        shapeId: 'ground',
        first: 0,
        second: 1,
        third: 2,
      ),
      throwsArgumentError,
    );
    expect(
      () => TerrainAuthoringTriangleRecord(
        chunkKey: 'chunk_a',
        placementKey: '',
        shapeId: 'ground',
        first: -1,
        second: 1,
        third: 2,
      ),
      throwsArgumentError,
    );
  });
}
