import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/navigation/terrain_runtime_bundle.dart';
import 'package:test/test.dart';

void main() {
  group('TerrainRuntimeBundle', () {
    test('publishes one version and one shared surface identity', () {
      final bundle = _bundle(_geometry(version: 7, includeIsland: true));

      expect(bundle.version, 7);
      expect(bundle.edgeIndex.edges, hasLength(bundle.geometry.edges.length));
      expect(bundle.surfaceIndex.geometryVersion, 7);
      expect(bundle.graphPublication.geometryVersion, 7);
      expect(
        identical(bundle.surfaceIndex.surfaceSet, bundle.surfaceSet),
        true,
      );
      expect(
        identical(bundle.graphPublication.surfaceSet, bundle.surfaceSet),
        true,
      );
      expect(identical(bundle.grojibGraph.surfaceSet, bundle.surfaceSet), true);
      expect(
        identical(bundle.hashashGraph.surfaceSet, bundle.surfaceSet),
        true,
      );
      expect(
        bundle.graphPublication.graphs.map((graph) => graph.profileKey),
        <String>[EnemyId.grojib.name, EnemyId.hashash.name],
      );
    });

    test('no-op rebuild signatures ignore version and input object order', () {
      final profiles = buildDefaultGroundEnemyTerrainGraphProfiles();
      final first = TerrainRuntimeBundle.build(
        geometry: _geometry(version: 1, includeIsland: true),
        groundEnemyProfiles: profiles,
      );
      final second = TerrainRuntimeBundle.build(
        geometry: _geometry(version: 2, includeIsland: true),
        groundEnemyProfiles:
            buildDefaultGroundEnemyTerrainGraphProfiles().reversed,
      );

      expect(first.version, 1);
      expect(second.version, 2);
      expect(second.surfaceSignature(), first.surfaceSignature());
      expect(second.graphSignature(), first.graphSignature());
      expect(second.surfaceSet, isNot(same(first.surfaceSet)));
      expect(second.graphPublication, isNot(same(first.graphPublication)));
    });

    test('add and cull rebuild adjacency without retaining removed nodes', () {
      final withIsland = _bundle(_geometry(version: 1, includeIsland: true));
      final withoutIsland = _bundle(
        _geometry(version: 2, includeIsland: false),
      );
      final removedIds = withIsland.surfaceSet.surfaces
          .map((surface) => surface.id)
          .where((id) => withoutIsland.surfaceSet.indexOfId(id) == null)
          .toSet();

      expect(removedIds, isNotEmpty);
      expect(
        withoutIsland.graphSignature(),
        isNot(withIsland.graphSignature()),
      );
      for (final graph in [
        withoutIsland.grojibGraph,
        withoutIsland.hashashGraph,
      ]) {
        for (final surface in graph.surfaces) {
          expect(removedIds, isNot(contains(surface.id)));
        }
        for (final edge in graph.edges) {
          expect(edge.to, inInclusiveRange(0, graph.surfaces.length - 1));
        }
      }
    });

    test('rejects incomplete or duplicated profile publications', () {
      final profiles = buildDefaultGroundEnemyTerrainGraphProfiles();
      expect(
        () => TerrainRuntimeBundle.build(
          geometry: _geometry(version: 1, includeIsland: false),
          groundEnemyProfiles: [profiles.first],
        ),
        throwsArgumentError,
      );
      expect(
        () => TerrainRuntimeBundle.build(
          geometry: _geometry(version: 1, includeIsland: false),
          groundEnemyProfiles: [profiles.first, profiles.first],
        ),
        throwsArgumentError,
      );
    });
  });
}

TerrainRuntimeBundle _bundle(TerrainGeometry geometry) =>
    TerrainRuntimeBundle.build(
      geometry: geometry,
      groundEnemyProfiles: buildDefaultGroundEnemyTerrainGraphProfiles(),
    );

TerrainGeometry _geometry({
  required int version,
  required bool includeIsland,
}) => const TerrainCompiler().compile(<TerrainPolygonInput>[
  TerrainPolygonInput.fromWorld(
    sourcePath: 'bundle/floor',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'bundle',
      shapeId: 'floor',
    ),
    vertices: <(double, double)>[(0, 100), (180, 100), (180, 150), (0, 150)],
  ),
  if (includeIsland)
    TerrainPolygonInput.fromWorld(
      sourcePath: 'bundle/island',
      identity: TerrainSourceIdentity(
        chunkIndex: 1,
        chunkKey: 'bundle',
        shapeId: 'island',
      ),
      vertices: <(double, double)>[
        (220, 80),
        (280, 80),
        (280, 110),
        (220, 110),
      ],
    ),
], geometryVersion: version);
