import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_core/collision/terrain/terrain_authoring_issue.dart';
import 'package:runner_editor/src/chunks/migration/legacy_chunk_models.dart';
import 'package:runner_editor/src/migration/polygon_authoring_legacy_codec.dart';
import 'package:runner_editor/src/migration/polygon_authoring_migration_plan.dart';
import 'package:runner_editor/src/migration/legacy_prefab_models.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/prefabs/store/prefab_store.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';
import 'package:runner_editor/src/workspace/workspace_file_io.dart';

void main() {
  test('repository check plan is complete and blocker-free', () async {
    final fixture = await _loadRepositoryFixture();
    final plan = _buildPlan(fixture);

    expect(plan.hasBlockers, isFalse);
    expect(plan.summary.toJson(), <String, Object>{
      'prefabCount': 99,
      'collisionPrefabCount': 0,
      'decorationPrefabCount': 29,
      'multiColliderPrefabCount': 0,
      'reauthoredPrefabCount': 0,
      'prefabShapeCount': 0,
      'chunkCount': 9,
      'legacyGapCount': 9,
      'groundShapeCount': 0,
      'blockerCount': 0,
    });
    final decoded = jsonDecode(plan.toCanonicalJson()) as Map<String, Object?>;
    expect(decoded['reportVersion'], 2);
    expect(decoded['mode'], 'check');
    expect((decoded['sourceFiles']! as List<Object?>), hasLength(10));
    expect((decoded['prefabs']! as List<Object?>), hasLength(99));
    expect((decoded['chunks']! as List<Object?>), hasLength(9));
    expect((decoded['blockers']! as List<Object?>), isEmpty);
    final legacyByKey = <String, LegacyPrefabDef>{
      for (final prefab in fixture.prefabData.prefabs) prefab.prefabKey: prefab,
    };
    final platformEntries = plan.prefabs.where(
      (entry) => legacyByKey[entry.prefabKey]!.kind == PrefabKind.platform,
    );
    expect(platformEntries, hasLength(4));
    expect(
      plan.prefabs.where(
        (entry) => entry.kind == PrefabPolygonMigrationKind.collisionCleared,
      ),
      hasLength(70),
    );
    expect(
      platformEntries
          .expand((entry) => entry.collisionShapes)
          .every(
            (shape) => shape.collisionMode == TerrainSourceCollisionMode.oneWay,
          ),
      isTrue,
    );
    expect(
      plan.prefabs
          .where(
            (entry) =>
                legacyByKey[entry.prefabKey]!.kind == PrefabKind.obstacle,
          )
          .expand((entry) => entry.collisionShapes)
          .every(
            (shape) => shape.collisionMode == TerrainSourceCollisionMode.solid,
          ),
      isTrue,
    );
    expect(WorkspaceFileIo.fingerprint(plan.toCanonicalJson()), '860ddde2');
  });

  test('input order and host path separators do not affect report', () async {
    final fixture = await _loadRepositoryFixture();
    final forward = _buildPlan(fixture);
    final reversedPaths = <String, String>{
      for (final entry in fixture.chunkSourcePaths.entries.toList().reversed)
        entry.key: entry.value.replaceAll('/', r'\'),
    };
    final reversed = PolygonAuthoringMigrationPlan.build(
      prefabData: fixture.prefabData.copyWith(
        prefabs: fixture.prefabData.prefabs.reversed.toList(growable: false),
      ),
      prefabSourcePath: PrefabStore.prefabDefsPath.replaceAll('/', r'\'),
      prefabSourceSha256: fixture.prefabSourceSha256,
      chunks: fixture.chunks.reversed,
      chunkSourcePathByKey: reversedPaths,
      chunkSourceSha256ByKey: <String, String>{
        for (final entry
            in fixture.chunkSourceSha256ByKey.entries.toList().reversed)
          entry.key: entry.value,
      },
    );

    expect(reversed.toCanonicalJson(), forward.toCanonicalJson());
  });

  test(
    'missing reviewed prefab and duplicate identities fail closed',
    () async {
      final fixture = await _loadRepositoryFixture();
      final retainedPrefabs =
          fixture.prefabData.prefabs
              .where((prefab) => prefab.prefabKey != 'dark_menhir_01')
              .toList(growable: true)
            ..add(fixture.prefabData.prefabs.first)
            ..add(fixture.prefabData.prefabs.first);
      final duplicateChunk = fixture.chunks.first;
      final plan = PolygonAuthoringMigrationPlan.build(
        prefabData: fixture.prefabData.copyWith(prefabs: retainedPrefabs),
        prefabSourcePath: PrefabStore.prefabDefsPath,
        prefabSourceSha256: fixture.prefabSourceSha256,
        chunks: <LevelChunkDef>[...fixture.chunks, duplicateChunk],
        chunkSourcePathByKey: fixture.chunkSourcePaths,
        chunkSourceSha256ByKey: fixture.chunkSourceSha256ByKey,
      );

      expect(plan.hasBlockers, isTrue);
      expect(
        plan.issues.map((issue) => issue.code),
        containsAll(<String>[
          'migration_reauthoring_prefab_missing',
          'migration_prefab_key_duplicate',
          'migration_chunk_key_duplicate',
        ]),
      );
      expect(plan.summary.blockerCount, 3);
      final sharedIssues = plan.terrainAuthoringIssues;
      expect(sharedIssues, hasLength(plan.issues.length));
      for (var index = 0; index < plan.issues.length; index += 1) {
        final legacy = plan.issues[index];
        final shared = sharedIssues[index];
        expect(shared.severity, TerrainAuthoringIssueSeverity.error);
        expect(shared.code, legacy.code);
        expect(shared.message, legacy.message);
        expect(shared.sourcePath, legacy.sourcePath);
        expect(shared.ownerKey, legacy.ownerKey);
        expect(shared.elementIndex, legacy.elementIndex);
        expect(shared.placementKey, isNull);
        expect(shared.shapeId, isNull);
      }
    },
  );

  test('source audit detects changed, missing, and ambiguous files', () async {
    final fixture = await _loadRepositoryFixture();
    final plan = _buildPlan(fixture);
    final current = fixture.currentSha256BySourcePath;

    expect(plan.auditSourceDigests(current), isEmpty);

    final changed = Map<String, String>.from(current);
    changed[PrefabStore.prefabDefsPath] = _sha('0');
    expect(
      plan.auditSourceDigests(changed).map((issue) => issue.code),
      <String>['migration_source_drift'],
    );
    final sharedChanged = plan.auditSourceDigestAuthoringIssues(changed).single;
    expect(sharedChanged.severity, TerrainAuthoringIssueSeverity.error);
    expect(sharedChanged.code, 'migration_source_drift');
    expect(sharedChanged.ownerKey, 'prefab_defs');
    expect(sharedChanged.sourcePath, PrefabStore.prefabDefsPath);

    final missing = Map<String, String>.from(current)
      ..remove(fixture.chunkSourcePaths[fixture.chunks.first.chunkKey]);
    expect(
      plan.auditSourceDigests(missing).map((issue) => issue.code),
      <String>['migration_source_missing'],
    );

    final ambiguous = Map<String, String>.from(current)
      ..[PrefabStore.prefabDefsPath.replaceAll('/', r'\')] = _sha('1');
    expect(
      plan.auditSourceDigests(ambiguous).map((issue) => issue.code),
      <String>['migration_source_path_ambiguous'],
    );
  });

  test('missing and malformed source signatures block planning', () async {
    final fixture = await _loadRepositoryFixture();
    final chunkSha256 = Map<String, String>.from(fixture.chunkSourceSha256ByKey)
      ..remove(fixture.chunks.first.chunkKey);
    final plan = PolygonAuthoringMigrationPlan.build(
      prefabData: fixture.prefabData,
      prefabSourcePath: PrefabStore.prefabDefsPath,
      prefabSourceSha256: 'NOT_A_SHA',
      chunks: fixture.chunks,
      chunkSourcePathByKey: fixture.chunkSourcePaths,
      chunkSourceSha256ByKey: chunkSha256,
    );

    expect(plan.hasBlockers, isTrue);
    expect(
      plan.issues.map((issue) => issue.code),
      containsAll(<String>[
        'migration_source_sha256_invalid',
        'migration_source_sha256_missing',
      ]),
    );
    expect(plan.summary.blockerCount, 2);
  });
}

final class _RepositoryMigrationFixture {
  const _RepositoryMigrationFixture({
    required this.prefabData,
    required this.prefabSourceSha256,
    required this.chunks,
    required this.chunkSourcePaths,
    required this.chunkSourceSha256ByKey,
  });

  final LegacyPrefabData prefabData;
  final String prefabSourceSha256;
  final List<LevelChunkDef> chunks;
  final Map<String, String> chunkSourcePaths;
  final Map<String, String> chunkSourceSha256ByKey;

  Map<String, String> get currentSha256BySourcePath => <String, String>{
    PrefabStore.prefabDefsPath: prefabSourceSha256,
    for (final entry in chunkSourcePaths.entries)
      entry.value: chunkSourceSha256ByKey[entry.key]!,
  };
}

Future<_RepositoryMigrationFixture> _loadRepositoryFixture() async {
  final root = _repoRootPath();
  final prefabRaw = File(
    p.join(root, p.normalize(PrefabStore.prefabDefsPath)),
  ).readAsStringSync();
  final prefabDocument = PolygonAuthoringLegacyCodec.decodePrefab(
    _demotePrefabSource(prefabRaw),
    sourcePath: PrefabStore.prefabDefsPath,
  );
  final chunkFiles =
      Directory(p.join(root, 'assets', 'authoring', 'level', 'chunks'))
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => p.extension(file.path).toLowerCase() == '.json');
  final chunks = <LevelChunkDef>[];
  final chunkSourcePaths = <String, String>{};
  final chunkSourceSha256ByKey = <String, String>{};
  for (final file in chunkFiles) {
    final sourcePath = p.relative(file.path, from: root).replaceAll(r'\', '/');
    final document = PolygonAuthoringLegacyCodec.decodeChunkV1(
      _demoteChunkSource(file.readAsStringSync()),
      sourcePath: sourcePath,
    );
    chunks.add(document.chunk);
    chunkSourcePaths[document.chunk.chunkKey] = sourcePath;
    chunkSourceSha256ByKey[document.chunk.chunkKey] = document.sourceSha256;
  }
  return _RepositoryMigrationFixture(
    prefabData: prefabDocument.prefabData,
    prefabSourceSha256: prefabDocument.sourceSha256,
    chunks: chunks,
    chunkSourcePaths: chunkSourcePaths,
    chunkSourceSha256ByKey: chunkSourceSha256ByKey,
  );
}

String _demotePrefabSource(String currentSource) {
  final root = jsonDecode(currentSource) as Map<String, Object?>;
  root['schemaVersion'] = 2;
  for (final rawPrefab in root['prefabs']! as List<Object?>) {
    final prefab = rawPrefab! as Map<String, Object?>;
    final legacy = <String, Object?>{};
    for (final entry in prefab.entries) {
      if (entry.key == 'collisionShapes') {
        legacy['colliders'] = <Object?>[];
      } else {
        legacy[entry.key] = entry.value;
      }
    }
    prefab
      ..clear()
      ..addAll(legacy);
  }
  return _canonicalJson(root);
}

String _demoteChunkSource(String currentSource) {
  final root = jsonDecode(currentSource) as Map<String, Object?>;
  root['schemaVersion'] = 1;
  final legacy = <String, Object?>{};
  for (final entry in root.entries) {
    if (entry.key == 'collisionShapes') {
      legacy['groundProfile'] = <String, Object?>{'kind': 'flat', 'topY': 224};
      legacy['groundGaps'] = <Object?>[
        <String, Object?>{
          'gapId': 'collision_cleared',
          'type': 'pit',
          'x': 0,
          'width': 600,
        },
      ];
    } else {
      legacy[entry.key] = entry.value;
    }
  }
  return _canonicalJson(legacy);
}

String _canonicalJson(Map<String, Object?> json) =>
    '${const JsonEncoder.withIndent('  ').convert(json)}\n';

PolygonAuthoringMigrationPlan _buildPlan(_RepositoryMigrationFixture fixture) =>
    PolygonAuthoringMigrationPlan.build(
      prefabData: fixture.prefabData,
      prefabSourcePath: PrefabStore.prefabDefsPath,
      prefabSourceSha256: fixture.prefabSourceSha256,
      chunks: fixture.chunks,
      chunkSourcePathByKey: fixture.chunkSourcePaths,
      chunkSourceSha256ByKey: fixture.chunkSourceSha256ByKey,
    );

String _sha(String digit) => List<String>.filled(64, digit).join();

String _repoRootPath() {
  final cwd = p.normalize(Directory.current.path);
  if (p.basename(cwd).toLowerCase() == 'editor' &&
      p.basename(p.dirname(cwd)).toLowerCase() == 'tools') {
    return p.normalize(p.join(cwd, '..', '..'));
  }
  return cwd;
}
