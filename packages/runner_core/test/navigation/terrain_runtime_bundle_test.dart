import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/navigation/terrain_spawn_placement.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/navigation/terrain_runtime_bundle.dart';
import 'package:runner_core/navigation/types/terrain_navigation_surface.dart';
import 'package:test/test.dart';
import 'package:crypto/crypto.dart';
import 'package:runner_core/navigation/terrain_graph_artifact.dart';
import 'package:runner_core/navigation/terrain_graph_materializer.dart';

void main() {
  group('TerrainRuntimeBundle', () {
    test('offline construction materializes only accessed profiles and preserves all signatures', () {
      final requests = <String>[];
      final geometry = _geometry(version: 7, includeIsland: true);
      final profiles = buildDefaultGroundEnemyTerrainGraphProfiles();
      final lazy = TerrainRuntimeBundle.build(
        geometry: geometry,
        groundEnemyProfiles: profiles,
        graphMaterializer: TerrainGraphMaterializer.onDemand(
          lookup: (_, _, p) {
            requests.add(p.profileKey);
            return null;
          },
        ),
      );
      expect(requests, isEmpty);
      final rebound = lazy.withGeometryVersion(8);
      expect(requests, isEmpty);
      final first = rebound.grojibGraph;
      expect(rebound.grojibGraph, same(first));
      expect(requests, ['grojib']);
      expect(first.geometryVersion, 8);
      expect(rebound.graphSignature(), _bundle(geometry).graphSignature());
      expect(requests.toSet().length, profiles.length);
    });

    test('binary graph artifacts preserve exact CSR and reject corruption and changed inputs', () {
      final bundle = _bundle(_geometry(version: 1, includeIsland: true));
      final other = _bundle(_geometry(version: 9, includeIsland: true));
      final changed = _bundle(_geometry(version: 1, includeIsland: false));
      for (final graph in bundle.graphPublication.graphs) {
        final profile = graph.buildProfile;
        final key = terrainGraphArtifactKey(
          geometry: bundle.geometry,
          surfaces: bundle.surfaceSet,
          profile: profile,
        );
        final bytes = TerrainGraphArtifactCodec.encode(key: key, graph: graph);
        final digest = sha256.convert(bytes).toString();
        final sameKey = terrainGraphArtifactKey(
          geometry: other.geometry,
          surfaces: other.surfaceSet,
          profile: profile,
        );
        expect(sameKey, key);
        final decoded = TerrainGraphArtifactCodec.decode(
          bytes: bytes,
          expectedSha256: digest,
          key: sameKey,
          surfaces: other.surfaceSet,
          profile: profile,
        );
        expect(decoded.signature(), graph.signature());
        expect(decoded.surfaceSet, same(other.surfaceSet));
        final changedKey = terrainGraphArtifactKey(
          geometry: changed.geometry,
          surfaces: changed.surfaceSet,
          profile: profile,
        );
        expect(changedKey, isNot(key));
        expect(
          () => TerrainGraphArtifactCodec.decode(
            bytes: bytes,
            expectedSha256: digest,
            key: changedKey,
            surfaces: changed.surfaceSet,
            profile: profile,
          ),
          throwsFormatException,
        );
        bytes[bytes.length - 1] ^= 1;
        expect(
          () => TerrainGraphArtifactCodec.decode(
            bytes: bytes,
            expectedSha256: digest,
            key: key,
            surfaces: bundle.surfaceSet,
            profile: profile,
          ),
          throwsFormatException,
        );
      }
    });

    test('mirrored zero offsets retain canonical integer encoding', () {
      final profiles = buildDefaultGroundEnemyTerrainGraphProfiles();
      for (final profile in profiles) {
        if (profile.authoredOffsetXTicks == 0) {
          expect(profile.authoredOffsetXTicks.toString(), '0');
        }
      }
    });

    test('graph capsules match catalog collision for both enemy facings', () {
      const catalog = EnemyCatalog();
      for (final profile in buildDefaultGroundEnemyTerrainGraphProfiles()) {
        final enemy = EnemyId.values.byName(profile.profileKey);
        for (final facing in Facing.values) {
          final runtime = TerrainEnemySpawnPlacementProfile.fromCatalog(
            catalog: catalog,
            enemyId: enemy,
            facing: facing,
          ).capsule;
          final planned = profile.capsuleForDirection(
            facing == Facing.right ? 1 : -1,
          );
          expect(planned.resolvedOffsetXTicks, runtime.resolvedOffsetXTicks);
          expect(planned.radiusTicks, runtime.radiusTicks);
          expect(
            planned.verticalHalfSegmentTicks,
            runtime.verticalHalfSegmentTicks,
          );
          expect(planned.offsetYTicks, runtime.offsetYTicks);
        }
      }
    });
    test(
      'version rebinding shares admitted records and rejects substituted nodes',
      () {
        final original = _bundle(_geometry(version: 7, includeIsland: true));
        final rebound = original.withGeometryVersion(8);
        expect(rebound.version, 8);
        expect(original.version, 7);
        expect(
          identical(rebound.geometry.edges, original.geometry.edges),
          isTrue,
        );
        expect(
          identical(rebound.geometry.edgeById, original.geometry.edgeById),
          isTrue,
        );
        expect(
          identical(rebound.surfaceSet.surfaces, original.surfaceSet.surfaces),
          isTrue,
        );
        expect(
          identical(rebound.grojibGraph.edges, original.grojibGraph.edges),
          isTrue,
        );
        expect(
          identical(
            rebound.hashashGraph.edgeOffsets,
            original.hashashGraph.edgeOffsets,
          ),
          isTrue,
        );
        expect(rebound.graphSignature(), original.graphSignature());
        expect(
          identical(rebound.surfaceIndex.surfaceSet, rebound.surfaceSet),
          isTrue,
        );
        expect(
          identical(rebound.graphPublication.surfaceSet, rebound.surfaceSet),
          isTrue,
        );
        expect(
          rebound.surfaceIndex.insertedReferences,
          original.surfaceIndex.insertedReferences,
        );
        expect(() => rebound.grojibGraph.edges.clear(), throwsUnsupportedError);
        expect(
          () => original.grojibGraph.withSurfaceSetVersion(
            TerrainSurfaceSet(
              geometryVersion: 8,
              surfaces: original.surfaceSet.surfaces,
            ),
          ),
          throwsArgumentError,
        );
        expect(() => original.withGeometryVersion(-1), throwsArgumentError);
      },
    );

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
        <String>[
          EnemyId.bringerOfDeath.name,
          EnemyId.derf.name,
          EnemyId.grojib.name,
          EnemyId.hashash.name,
          EnemyId.shoggothMinion.name,
          EnemyId.voidTentacle.name,
          EnemyId.voidcaller.name,
        ],
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
