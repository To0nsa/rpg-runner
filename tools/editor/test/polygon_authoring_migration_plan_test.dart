import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_store.dart';
import 'package:runner_editor/src/migration/polygon_authoring_migration_plan.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/prefabs/store/prefab_store.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';
import 'package:runner_editor/src/workspace/workspace_file_io.dart';

void main() {
  test('repository check plan is complete and blocker-free', () async {
    final fixture = await _loadRepositoryFixture();
    final plan = _buildPlan(fixture);

    expect(plan.hasBlockers, isFalse);
    expect(plan.summary.toJson(), <String, Object>{
      'prefabCount': 99,
      'collisionPrefabCount': 70,
      'decorationPrefabCount': 29,
      'multiColliderPrefabCount': 29,
      'reauthoredPrefabCount': 3,
      'prefabShapeCount': 88,
      'chunkCount': 8,
      'legacyGapCount': 1,
      'groundShapeCount': 9,
      'blockerCount': 0,
    });
    final decoded = jsonDecode(plan.toCanonicalJson()) as Map<String, Object?>;
    expect(decoded['reportVersion'], 1);
    expect(decoded['mode'], 'check');
    expect((decoded['prefabs']! as List<Object?>), hasLength(99));
    expect((decoded['chunks']! as List<Object?>), hasLength(8));
    expect((decoded['blockers']! as List<Object?>), isEmpty);
    expect(WorkspaceFileIo.fingerprint(plan.toCanonicalJson()), 'f2a9c639');
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
      chunks: fixture.chunkDocument.chunks.reversed,
      chunkSourcePathByKey: reversedPaths,
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
      final duplicateChunk = fixture.chunkDocument.chunks.first;
      final plan = PolygonAuthoringMigrationPlan.build(
        prefabData: fixture.prefabData.copyWith(prefabs: retainedPrefabs),
        prefabSourcePath: PrefabStore.prefabDefsPath,
        chunks: <LevelChunkDef>[
          ...fixture.chunkDocument.chunks,
          duplicateChunk,
        ],
        chunkSourcePathByKey: fixture.chunkSourcePaths,
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
    },
  );
}

final class _RepositoryMigrationFixture {
  const _RepositoryMigrationFixture({
    required this.prefabData,
    required this.chunkDocument,
    required this.chunkSourcePaths,
  });

  final PrefabData prefabData;
  final ChunkDocument chunkDocument;
  final Map<String, String> chunkSourcePaths;
}

Future<_RepositoryMigrationFixture> _loadRepositoryFixture() async {
  final root = _repoRootPath();
  final prefabData = await const PrefabStore().load(root);
  final chunkDocument = await const ChunkStore().load(
    EditorWorkspace(rootPath: root),
  );
  return _RepositoryMigrationFixture(
    prefabData: prefabData,
    chunkDocument: chunkDocument,
    chunkSourcePaths: <String, String>{
      for (final entry in chunkDocument.baselineByChunkKey.entries)
        entry.key: entry.value.sourcePath,
    },
  );
}

PolygonAuthoringMigrationPlan _buildPlan(_RepositoryMigrationFixture fixture) =>
    PolygonAuthoringMigrationPlan.build(
      prefabData: fixture.prefabData,
      prefabSourcePath: PrefabStore.prefabDefsPath,
      chunks: fixture.chunkDocument.chunks,
      chunkSourcePathByKey: fixture.chunkSourcePaths,
    );

String _repoRootPath() {
  final cwd = p.normalize(Directory.current.path);
  if (p.basename(cwd).toLowerCase() == 'editor' &&
      p.basename(p.dirname(cwd)).toLowerCase() == 'tools') {
    return p.normalize(p.join(cwd, '..', '..'));
  }
  return cwd;
}
