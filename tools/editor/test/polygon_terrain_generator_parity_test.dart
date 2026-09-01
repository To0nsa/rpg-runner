import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_triangle_signature.dart';
import 'package:runner_core/collision/terrain/terrain_triangulator.dart';
import 'package:runner_editor/src/chunks/chunk_v2_authoring_polygon_signature.dart';
import 'package:runner_editor/src/chunks/chunk_v2_collision_expansion.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/migration/legacy_prefab_collider_def.dart';
import 'package:runner_editor/src/prefabs/migration/legacy_prefab_collider_union.dart';
import 'package:runner_editor/src/prefabs/store/prefab_v3_file_codec.dart';

const String _fixtureDirectory = 'test/fixtures/polygon_terrain_generator';
const String _chunkSourcePath = 'chunks/forest/fixture_chunk.json';
const String _transformChunkSourcePath = 'chunks/forest/transform_chunk.json';
const String _migrationChunkSourcePath = 'chunks/forest/migration_chunk.json';

void main() {
  test('editor compile matches staged generator fixture signatures', () {
    _expectFixtureParity(
      prefabFixture: 'prefab_defs.json',
      chunkFixture: 'chunk.json',
      goldenFixture: 'golden.json',
      chunkSourcePath: _chunkSourcePath,
    );
  });

  test('editor matches transform and terrain feature fixture signatures', () {
    final expansion = _expectFixtureParity(
      prefabFixture: 'transform_prefab_defs.json',
      chunkFixture: 'transform_chunk.json',
      goldenFixture: 'transform_golden.json',
      chunkSourcePath: _transformChunkSourcePath,
    );
    expect(
      expansion.expandedPrefabShapes
          .map(
            (shape) => (
              shape.placementKey,
              shape.scaleTenths,
              shape.flipX,
              shape.flipY,
            ),
          )
          .toList(growable: false),
      <(String, int, bool, bool)>[
        ('prefab_asymmetric|30|30|0', 3, true, false),
        ('prefab_asymmetric|80|50|0', 30, false, true),
      ],
    );
  });

  test('legacy union output matches migration parity fixture', () {
    final prefabSource = _fixture('migration_prefab_defs.json');
    final prefabs = PrefabV3FileCodec.decode(
      prefabSource,
      sourcePath: 'migration_prefab_defs.json',
    );
    const collidersByPrefabKey = <String, List<PrefabColliderDef>>{
      'prefab_migration_concave': <PrefabColliderDef>[
        PrefabColliderDef(offsetX: 16, offsetY: 16, width: 32, height: 32),
        PrefabColliderDef(offsetX: 32, offsetY: 32, width: 32, height: 32),
      ],
      'prefab_migration_disconnected': <PrefabColliderDef>[
        PrefabColliderDef(offsetX: 10, offsetY: 0, width: 4, height: 4),
        PrefabColliderDef(offsetX: -10, offsetY: 0, width: 4, height: 4),
      ],
      'prefab_migration_rectangle': <PrefabColliderDef>[
        PrefabColliderDef(offsetX: 0, offsetY: 0, width: 4, height: 6),
      ],
    };

    for (final entry in collidersByPrefabKey.entries) {
      final planned = LegacyPrefabColliderUnion.plan(
        sourcePath: 'migration_fixture:${entry.key}',
        colliders: entry.value,
      );
      final reversed = LegacyPrefabColliderUnion.plan(
        sourcePath: 'migration_fixture:${entry.key}',
        colliders: entry.value.reversed,
      );
      final prefab = prefabs.prefabs.singleWhere(
        (candidate) => candidate.prefabKey == entry.key,
      );

      expect(planned.issues, isEmpty, reason: entry.key);
      expect(planned.shapes, prefab.collisionShapes, reason: entry.key);
      expect(reversed.shapes, planned.shapes, reason: entry.key);
    }

    final expansion = _expectFixtureParity(
      prefabFixture: 'migration_prefab_defs.json',
      chunkFixture: 'migration_chunk.json',
      goldenFixture: 'migration_golden.json',
      chunkSourcePath: _migrationChunkSourcePath,
    );
    final expandedIdentities =
        expansion.expandedPrefabShapes
            .map((shape) => '${shape.placementKey}:${shape.shapeId}')
            .toList(growable: false)
          ..sort();
    expect(expandedIdentities, <String>[
      'prefab_migration_concave|100|20|0:collision_001',
      'prefab_migration_disconnected|220|40|0:collision_001',
      'prefab_migration_disconnected|220|40|0:collision_002',
      'prefab_migration_rectangle|30|30|0:collision_001',
    ]);
  });

  test('editor polygon signature rejects stale accepted prefab evidence', () {
    final prefabs = PrefabV3FileCodec.decode(
      _fixture('prefab_defs.json'),
      sourcePath: 'prefab_defs.json',
    );
    final chunk = ChunkV2FileCodec.decode(
      _fixture('chunk.json'),
      sourcePath: _chunkSourcePath,
    );
    final expansion = expandChunkV2Collision(
      chunk: chunk,
      prefabs: prefabs.prefabs,
      sourcePath: _chunkSourcePath,
    ).expansion!;
    final stalePrefabs = prefabs.prefabs
        .map((prefab) => prefab.copyWith(revision: prefab.revision + 1))
        .toList(growable: false);

    expect(
      () => chunkV2AuthoringPolygonSignature(
        chunk: chunk,
        prefabs: stalePrefabs,
        expansion: expansion,
      ),
      throwsStateError,
    );
  });
}

ChunkV2CollisionExpansion _expectFixtureParity({
  required String prefabFixture,
  required String chunkFixture,
  required String goldenFixture,
  required String chunkSourcePath,
}) {
  final prefabSource = _fixture(prefabFixture);
  final chunkSource = _fixture(chunkFixture);
  final prefabs = PrefabV3FileCodec.decode(
    prefabSource,
    sourcePath: prefabFixture,
  );
  final chunk = ChunkV2FileCodec.decode(
    chunkSource,
    sourcePath: chunkSourcePath,
  );
  final golden = jsonDecode(_fixture(goldenFixture)) as Map<String, Object?>;
  final canonicalPrefabs = PrefabV3FileCodec.encode(prefabs);
  final canonicalChunk = ChunkV2FileCodec.encode(chunk);

  expect(canonicalPrefabs, prefabSource);
  expect(canonicalChunk, chunkSource);
  expect(
    PrefabV3FileCodec.encode(PrefabV3FileCodec.decode(canonicalPrefabs)),
    canonicalPrefabs,
  );
  expect(
    ChunkV2FileCodec.encode(ChunkV2FileCodec.decode(canonicalChunk)),
    canonicalChunk,
  );

  final result = expandChunkV2Collision(
    chunk: chunk,
    prefabs: prefabs.prefabs,
    sourcePath: chunkSourcePath,
  );

  expect(result.issues, isEmpty);
  final expansion = result.expansion!;
  expect(
    expansion.geometry.polygons,
    hasLength(golden['polygonCount']! as int),
  );
  expect(expansion.geometry.edges, hasLength(golden['edgeCount']! as int));
  expect(expansion.geometry.sourceSignature(), golden['sourceSignature']);
  expect(expansion.geometry.edgeSignature(), golden['edgeSignature']);
  expect(
    chunkV2AuthoringPolygonSignature(
      chunk: chunk,
      prefabs: prefabs.prefabs,
      expansion: expansion,
    ),
    golden['authoringPolygonSignature'],
  );
  expect(_placementSignature(expansion), golden['placementSignature']);
  expect(_triangleSignature(expansion), golden['triangleSignature']);
  return expansion;
}

String _placementSignature(ChunkV2CollisionExpansion expansion) {
  final shapes =
      List<ChunkV2ExpandedPrefabShape>.of(expansion.expandedPrefabShapes)
        ..sort((left, right) {
          final placement = left.placementKey.compareTo(right.placementKey);
          return placement != 0
              ? placement
              : left.shapeId.compareTo(right.shapeId);
        });
  final records = <String>[
    for (final shape in shapes)
      _canonicalRecord(<String>[
        'authoring-placement-v1',
        shape.chunkKey,
        shape.placementKey,
        shape.prefabKey,
        shape.prefabId,
        shape.prefabRevision.toString(),
        shape.shapeId,
        shape.placementX.toString(),
        shape.placementY.toString(),
        shape.scaleTenths.toString(),
        shape.flipX ? '1' : '0',
        shape.flipY ? '1' : '0',
      ]),
  ];
  return sha256.convert(utf8.encode(records.join('\n'))).toString();
}

String _triangleSignature(ChunkV2CollisionExpansion expansion) {
  final triangles = <TerrainAuthoringTriangleRecord>[
    for (final polygon in expansion.geometry.polygons)
      if (polygon.identity.placementKey == null)
        for (final triangle in const TerrainTriangulator().triangulate(polygon))
          TerrainAuthoringTriangleRecord(
            chunkKey: polygon.identity.chunkKey,
            placementKey: polygon.identity.placementKey,
            shapeId: polygon.identity.shapeId,
            first: triangle.first,
            second: triangle.second,
            third: triangle.third,
          ),
  ];
  return terrainAuthoringTriangleSignature(triangles);
}

String _canonicalRecord(List<String> fields) =>
    fields.map((field) => '${utf8.encode(field).length}:$field').join('|');

String _fixture(String name) {
  final rootRelative = File('$_fixtureDirectory/$name');
  if (rootRelative.existsSync()) return rootRelative.readAsStringSync();
  final editorRelative = File('../../$_fixtureDirectory/$name');
  if (editorRelative.existsSync()) return editorRelative.readAsStringSync();
  throw StateError('Missing polygon generator fixture $name.');
}
