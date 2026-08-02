import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_store.dart';
import 'package:runner_editor/src/migration/polygon_authoring_legacy_codec.dart';
import 'package:runner_editor/src/migration/polygon_authoring_migration_plan.dart';
import 'package:runner_editor/src/migration/polygon_authoring_target_codec.dart';
import 'package:runner_editor/src/migration/polygon_authoring_target_models.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/prefabs/store/prefab_store.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';
import 'package:runner_editor/src/workspace/workspace_file_io.dart';

void main() {
  test('prefab v3 canonical round-trip preserves polygon source', () {
    final source = PolygonAuthoringTargetCodec.encodePrefabV3(
      PrefabV3TargetDocument(
        slices: const <AtlasSliceDef>[
          AtlasSliceDef(
            id: 'rock',
            sourceImagePath: 'assets/images/rock.png',
            x: 0,
            y: 0,
            width: 32,
            height: 32,
            tags: <String>['rock'],
          ),
        ],
        prefabs: <PrefabV3TargetDef>[
          PrefabV3TargetDef(
            prefabKey: 'rock_obstacle',
            id: 'rock_obstacle',
            revision: 2,
            status: PrefabStatus.active,
            kind: PrefabKind.obstacle,
            visualSource: const PrefabVisualSource.atlasSlice('rock'),
            anchorXPx: 16,
            anchorYPx: 32,
            collisionShapes: <TerrainSourceShapeDef>[_shape()],
            tags: const <String>['obstacle', 'rock'],
          ),
        ],
      ),
    );
    final decoded = PolygonAuthoringTargetCodec.decodePrefabV3(source);

    expect(PolygonAuthoringTargetCodec.encodePrefabV3(decoded), source);
    expect(source, contains('"schemaVersion": 3'));
    expect(source, contains('"collisionShapes"'));
    expect(source, isNot(contains('"colliders"')));
    expect(decoded.prefabs.single.collisionShapes.single, _shape());
  });

  test('prefab v3 target serialization canonicalizes copied records', () {
    final document = PrefabV3TargetDocument(
      slices: const <AtlasSliceDef>[],
      prefabs: <PrefabV3TargetDef>[
        PrefabV3TargetDef(
          prefabKey: 'rock',
          id: 'rock',
          revision: 1,
          status: PrefabStatus.active,
          kind: PrefabKind.obstacle,
          visualSource: const PrefabVisualSource.atlasSlice('rock'),
          anchorXPx: 0,
          anchorYPx: 0,
          collisionShapes: <TerrainSourceShapeDef>[
            _shape(shapeId: 'collision_002', xOffset: 20),
            _shape(),
          ],
          tags: const <String>['rock', 'obstacle', 'rock'],
        ),
      ],
    );
    final canonical = PolygonAuthoringTargetCodec.decodePrefabV3(
      PolygonAuthoringTargetCodec.encodePrefabV3(document),
    );

    expect(
      canonical.prefabs.single.collisionShapes.map((shape) => shape.shapeId),
      <String>['collision_001', 'collision_002'],
    );
    expect(canonical.prefabs.single.tags, <String>['obstacle', 'rock']);
    expect(
      document.prefabs.single.collisionShapes.map((shape) => shape.shapeId),
      <String>['collision_002', 'collision_001'],
    );
    expect(document.prefabs.single.tags, <String>['rock', 'obstacle', 'rock']);
  });

  test('prefab v3 rejects legacy, unknown, and noncanonical input', () {
    final canonical =
        jsonDecode(
              PolygonAuthoringTargetCodec.encodePrefabV3(
                PrefabV3TargetDocument(
                  slices: const <AtlasSliceDef>[],
                  prefabs: <PrefabV3TargetDef>[
                    PrefabV3TargetDef(
                      prefabKey: 'rock',
                      id: 'rock',
                      revision: 1,
                      status: PrefabStatus.active,
                      kind: PrefabKind.obstacle,
                      visualSource: const PrefabVisualSource.atlasSlice('rock'),
                      anchorXPx: 0,
                      anchorYPx: 0,
                      collisionShapes: <TerrainSourceShapeDef>[_shape()],
                      tags: const <String>['a', 'b'],
                    ),
                  ],
                ),
              ),
            )
            as Map<String, Object?>;

    expect(
      () => PolygonAuthoringTargetCodec.decodePrefabV3(
        _mutated(canonical, (root) => root['schemaVersion'] = 2),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => PolygonAuthoringTargetCodec.decodePrefabV3(
        _mutated(canonical, (root) {
          final prefab = _firstObject(root, 'prefabs');
          prefab['colliders'] = <Object?>[];
        }),
      ),
      throwsA(_formatMessage(contains('unknown field colliders'))),
    );
    expect(
      () => PolygonAuthoringTargetCodec.decodePrefabV3(
        _mutated(canonical, (root) {
          final prefab = _firstObject(root, 'prefabs');
          prefab['tags'] = <Object?>['b', 'a'];
        }),
      ),
      throwsA(_formatMessage(contains('strictly ordered'))),
    );
    expect(
      () => PolygonAuthoringTargetCodec.decodePrefabV3(
        _mutated(canonical, (root) {
          final prefab = _firstObject(root, 'prefabs');
          final shapes = prefab['collisionShapes']! as List<Object?>;
          final shape = shapes.single! as Map<String, Object?>;
          final vertices = shape['vertices']! as List<Object?>;
          final vertex = vertices.first! as Map<String, Object?>;
          vertex['x'] = 0.25;
        }),
      ),
      throwsA(_formatMessage(contains('divisible exactly by 0.5'))),
    );
  });

  test('chunk v2 canonical round-trip preserves all retained metadata', () {
    final document = ChunkV2TargetDocument(
      chunkKey: 'forest_test',
      id: 'forest_test',
      revision: 4,
      status: chunkStatusActive,
      levelId: 'forest',
      tileSize: 16,
      width: 600,
      height: 270,
      difficulty: chunkDifficultyEarly,
      assemblyGroupId: defaultChunkAssemblyGroupId,
      tags: const <String>['forest'],
      tileLayers: const <TileLayerDef>[
        TileLayerDef(id: 'background', kind: 'visual', visible: true),
      ],
      prefabs: const <PlacedPrefabDef>[
        PlacedPrefabDef(
          prefabId: 'rock',
          prefabKey: 'rock',
          x: 100,
          y: 224,
          zIndex: 1,
          snapToGrid: false,
          scale: 0.8,
          flipX: true,
        ),
      ],
      markers: const <PlacedMarkerDef>[
        PlacedMarkerDef(markerId: 'grojib', x: 300, y: 224, salt: 7),
      ],
      groundBandZIndex: -2,
      collisionShapes: <TerrainSourceShapeDef>[_groundShape()],
    );
    final source = PolygonAuthoringTargetCodec.encodeChunkV2(document);
    final decoded = PolygonAuthoringTargetCodec.decodeChunkV2(source);

    expect(PolygonAuthoringTargetCodec.encodeChunkV2(decoded), source);
    expect(source, contains('"schemaVersion": 2'));
    expect(source, contains('"groundBandZIndex": -2'));
    expect(source, isNot(contains('"groundProfile"')));
    expect(source, isNot(contains('"groundGaps"')));
    expect(decoded.prefabs.single.scale, 0.8);
    expect(decoded.collisionShapes.single, _groundShape());
  });

  test('chunk v2 rejects v1 fields, invalid scale, and wrong types', () {
    final canonical =
        jsonDecode(
              PolygonAuthoringTargetCodec.encodeChunkV2(
                ChunkV2TargetDocument(
                  chunkKey: 'forest_test',
                  id: 'forest_test',
                  revision: 1,
                  status: chunkStatusActive,
                  levelId: 'forest',
                  tileSize: 16,
                  width: 600,
                  height: 270,
                  difficulty: chunkDifficultyEarly,
                  assemblyGroupId: defaultChunkAssemblyGroupId,
                  tags: const <String>[],
                  tileLayers: const <TileLayerDef>[],
                  prefabs: const <PlacedPrefabDef>[
                    PlacedPrefabDef(
                      prefabId: 'rock',
                      prefabKey: 'rock',
                      x: 0,
                      y: 0,
                      zIndex: 0,
                      snapToGrid: true,
                    ),
                  ],
                  markers: const <PlacedMarkerDef>[],
                  groundBandZIndex: 0,
                  collisionShapes: <TerrainSourceShapeDef>[_groundShape()],
                ),
              ),
            )
            as Map<String, Object?>;

    expect(
      () => PolygonAuthoringTargetCodec.decodeChunkV2(
        _mutated(canonical, (root) => root['schemaVersion'] = 1),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => PolygonAuthoringTargetCodec.decodeChunkV2(
        _mutated(canonical, (root) {
          root['groundProfile'] = <String, Object?>{
            'kind': 'flat',
            'topY': 224,
          };
        }),
      ),
      throwsA(_formatMessage(contains('unknown field groundProfile'))),
    );
    expect(
      () => PolygonAuthoringTargetCodec.decodeChunkV2(
        _mutated(canonical, (root) {
          final placement = _firstObject(root, 'prefabs');
          placement['scale'] = 0.35;
        }),
      ),
      throwsA(_formatMessage(contains('0.3-3.0 scale in 0.1 steps'))),
    );
    expect(
      () => PolygonAuthoringTargetCodec.decodeChunkV2(
        _mutated(canonical, (root) => root['width'] = 600.0),
      ),
      throwsA(_formatMessage(contains('width must be an integer'))),
    );
  });

  test('complete repository migration output strictly round-trips', () async {
    final root = _repoRootPath();
    final prefabRaw = File(
      p.join(root, p.normalize(PrefabStore.prefabDefsPath)),
    ).readAsStringSync();
    final prefabDocument = PolygonAuthoringLegacyCodec.decodePrefab(
      prefabRaw,
      sourcePath: PrefabStore.prefabDefsPath,
    );
    final prefabData = prefabDocument.prefabData;
    final chunkDocument = await const ChunkStore().load(
      EditorWorkspace(rootPath: root),
    );
    final plan = PolygonAuthoringMigrationPlan.build(
      prefabData: prefabData,
      prefabSourcePath: PrefabStore.prefabDefsPath,
      prefabSourceSha256: prefabDocument.sourceSha256,
      chunks: chunkDocument.chunks,
      chunkSourcePathByKey: <String, String>{
        for (final entry in chunkDocument.baselineByChunkKey.entries)
          entry.key: entry.value.sourcePath,
      },
      chunkSourceSha256ByKey: <String, String>{
        for (final entry in chunkDocument.baselineByChunkKey.entries)
          entry.key: WorkspaceFileIo.sha256Digest(
            File(
              p.join(root, p.normalize(entry.value.sourcePath)),
            ).readAsStringSync(),
          ),
      },
    );
    expect(plan.hasBlockers, isFalse);
    final prefabEntries = <String, PrefabPolygonMigrationEntry>{
      for (final entry in plan.prefabs) entry.prefabKey: entry,
    };
    final prefabTarget = PrefabV3TargetDocument(
      slices: prefabData.prefabSlices,
      prefabs: prefabData.prefabs.map(
        (prefab) => prefabV3TargetFromLegacy(
          legacy: prefab,
          collisionShapes: prefabEntries[prefab.prefabKey]!.collisionShapes,
        ),
      ),
    );
    final prefabSource = PolygonAuthoringTargetCodec.encodePrefabV3(
      prefabTarget,
    );
    expect(
      PolygonAuthoringTargetCodec.encodePrefabV3(
        PolygonAuthoringTargetCodec.decodePrefabV3(prefabSource),
      ),
      prefabSource,
    );
    final decodedPrefabTarget = PolygonAuthoringTargetCodec.decodePrefabV3(
      prefabSource,
    );
    expect(
      decodedPrefabTarget.prefabs
          .where((prefab) => prefab.kind == PrefabKind.platform)
          .expand((prefab) => prefab.collisionShapes)
          .every(
            (shape) => shape.collisionMode == TerrainSourceCollisionMode.oneWay,
          ),
      isTrue,
    );

    final chunkEntries = <String, ChunkGroundPolygonMigrationEntry>{
      for (final entry in plan.chunks) entry.chunkKey: entry,
    };
    for (final chunk in chunkDocument.chunks) {
      final source = PolygonAuthoringTargetCodec.encodeChunkV2(
        chunkV2TargetFromLegacy(
          legacy: chunk,
          collisionShapes: chunkEntries[chunk.chunkKey]!.terrainShapes,
        ),
      );
      expect(
        PolygonAuthoringTargetCodec.encodeChunkV2(
          PolygonAuthoringTargetCodec.decodeChunkV2(source),
        ),
        source,
        reason: chunk.chunkKey,
      );
    }
  });
}

TerrainSourceShapeDef _shape({
  String shapeId = 'collision_001',
  int xOffset = 0,
}) => TerrainSourceShapeDef(
  shapeId: shapeId,
  vertices: <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: xOffset - 10, yHalfPixels: -10),
    TerrainSourceVertexDef(xHalfPixels: xOffset + 10, yHalfPixels: -10),
    TerrainSourceVertexDef(xHalfPixels: xOffset + 10, yHalfPixels: 10),
    TerrainSourceVertexDef(xHalfPixels: xOffset - 10, yHalfPixels: 10),
  ],
);

TerrainSourceShapeDef _groundShape() => TerrainSourceShapeDef(
  shapeId: 'ground_001',
  vertices: const <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 448),
    TerrainSourceVertexDef(xHalfPixels: 1200, yHalfPixels: 448),
    TerrainSourceVertexDef(xHalfPixels: 1200, yHalfPixels: 540),
    TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 540),
  ],
);

String _mutated(
  Map<String, Object?> canonical,
  void Function(Map<String, Object?> root) mutate,
) {
  final copied = jsonDecode(jsonEncode(canonical)) as Map<String, Object?>;
  mutate(copied);
  return jsonEncode(copied);
}

Map<String, Object?> _firstObject(Map<String, Object?> root, String field) =>
    (root[field]! as List<Object?>).first! as Map<String, Object?>;

Matcher _formatMessage(Matcher messageMatcher) => isA<FormatException>().having(
  (error) => error.message,
  'message',
  messageMatcher,
);

String _repoRootPath() {
  final cwd = p.normalize(Directory.current.path);
  if (p.basename(cwd).toLowerCase() == 'editor' &&
      p.basename(p.dirname(cwd)).toLowerCase() == 'tools') {
    return p.normalize(p.join(cwd, '..', '..'));
  }
  return cwd;
}
