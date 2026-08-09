import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_store.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/chunks/chunk_v2_lifecycle_commit.dart';
import 'package:runner_editor/src/chunks/chunk_v2_staging_models.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  test(
    'v2 save plan is clean or describes one canonical managed-path move',
    () {
      const store = ChunkStore();
      final document = _document();

      expect(store.buildV2StagingSavePlan(document: document).writes, isEmpty);

      final renamed = document.chunks.single.copyWith(
        id: 'forest_renamed',
        revision: 5,
      );
      final edited = document.copyWith(
        chunks: <ChunkV2FileData>[renamed],
        changedChunkKeys: <String>[renamed.chunkKey],
      );
      final plan = store.buildV2StagingSavePlan(document: edited);

      expect(plan.writes, hasLength(1));
      expect(plan.changedChunkKeys, <String>['forest_original']);
      expect(
        plan.writes.single.relativePath.replaceAll('\\', '/'),
        '${ChunkStore.chunksDirectoryPath}/forest/forest_renamed.json',
      );
      expect(
        plan.writes.single.previousRelativePath?.replaceAll('\\', '/'),
        '${ChunkStore.chunksDirectoryPath}/forest/forest_original.json',
      );
      expect(plan.writes.single.beforeContent, isNotNull);
      expect(plan.writes.single.afterContent, contains('"revision": 5'));

      final pending = ChunkDomainPlugin().describePendingChanges(
        EditorWorkspace(rootPath: Directory.current.path),
        document: edited,
      );
      expect(
        pending.fileDiffs.single.unifiedDiff,
        contains(
          'diff --git a/${ChunkStore.chunksDirectoryPath}/forest/'
          'forest_original.json b/${ChunkStore.chunksDirectoryPath}/forest/'
          'forest_renamed.json',
        ),
      );
    },
  );

  test('v2 save plan models explicit creation and baseline deletion', () {
    const store = ChunkStore();
    final document = _document();
    final created = document.chunks.single.copyWith(
      chunkKey: 'forest_created',
      id: 'forest_created',
      revision: 1,
    );
    final createdPath =
        '${ChunkStore.chunksDirectoryPath}/forest/forest_created.json';
    final edited = document.copyWith(
      chunks: <ChunkV2FileData>[created],
      sourcePathByChunkKey: <String, String>{
        ...document.sourcePathByChunkKey,
        created.chunkKey: createdPath,
      },
      createdChunkKeys: <String>[created.chunkKey],
      changedChunkKeys: <String>[created.chunkKey, 'forest_original'],
    );
    final plan = store.buildV2StagingSavePlan(document: edited);

    expect(plan.writes, hasLength(2));
    final creation = plan.writes.singleWhere(
      (write) => write.chunkKey == created.chunkKey,
    );
    final deletion = plan.writes.singleWhere(
      (write) => write.chunkKey == 'forest_original',
    );
    expect(creation.beforeContent, isNull);
    expect(creation.deleteFile, isFalse);
    expect(creation.relativePath.replaceAll('\\', '/'), createdPath);
    expect(deletion.deleteFile, isTrue);
    expect(deletion.beforeContent, isNotNull);
    expect(deletion.afterContent, isEmpty);
  });

  test('v2 save plan rejects missing baselines and source-path reuse', () {
    const store = ChunkStore();
    final document = _document();
    final existing = document.chunks.single;

    expect(
      () => store.buildV2StagingSavePlan(
        document: document.copyWith(
          baselineContentsByChunkKey: const <String, String>{},
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('chunk_v2_source_baseline_missing'),
        ),
      ),
    );

    expect(
      () => store.buildV2StagingSavePlan(
        document: document.copyWith(
          sourcePathByChunkKey: const <String, String>{
            'forest_original': '../outside.json',
          },
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('chunk_v2_source_path_outside_workspace'),
        ),
      ),
    );

    final replacement = existing.copyWith(
      chunkKey: 'forest_replacement',
      revision: 1,
    );
    final reusedPath = document.sourcePathByChunkKey[existing.chunkKey]!;
    expect(
      () => store.buildV2StagingSavePlan(
        document: document.copyWith(
          chunks: <ChunkV2FileData>[replacement],
          sourcePathByChunkKey: <String, String>{
            ...document.sourcePathByChunkKey,
            replacement.chunkKey: reusedPath,
          },
          createdChunkKeys: <String>[replacement.chunkKey],
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('chunk_v2_deleted_source_path_reused'),
        ),
      ),
    );
  });

  test(
    'v2 lifecycle creates a deprecated owner and unsaved delete is no-op',
    () {
      const policy = ChunkV2LifecycleCommitPolicy();
      final document = _document();
      final createCommit = ChunkV2LifecycleCommit(
        before: ChunkV2LifecycleSnapshot.fromDocument(document),
        operation: const ChunkV2CreateOperation(id: 'forest_created'),
      );
      final createdResult = policy.apply(
        document: document,
        commit: createCommit,
      );

      expect(
        createdResult.issues.map((issue) => '${issue.code}: ${issue.message}'),
        isEmpty,
      );
      expect(createdResult.accepted, isTrue);
      expect(createdResult.changed, isTrue);
      final createdDocument = createdResult.document;
      final created = createdDocument.chunks.singleWhere(
        (chunk) => chunk.chunkKey != 'forest_original',
      );
      expect(created.id, 'forest_created');
      expect(created.revision, 1);
      expect(created.status, chunkStatusDeprecated);
      expect(created.collisionShapes, isEmpty);
      expect(createdDocument.createdChunkKeys, <String>['forest_created']);
      expect(
        createdDocument.sourcePathByChunkKey[created.chunkKey]?.replaceAll(
          '\\',
          '/',
        ),
        '${ChunkStore.chunksDirectoryPath}/forest/forest_created.json',
      );

      final dispatched = ChunkDomainPlugin().applyEdit(
        document,
        AuthoringCommand(
          kind: ChunkDomainPlugin.commitChunkLifecycleCommandKind,
          payload: <String, Object?>{'commit': createCommit},
        ),
      );
      expect(dispatched, isA<ChunkV2StagingDocument>());
      expect((dispatched as ChunkV2StagingDocument).chunks, hasLength(2));

      final deleteResult = policy.apply(
        document: createdDocument,
        commit: ChunkV2LifecycleCommit(
          before: ChunkV2LifecycleSnapshot.fromDocument(createdDocument),
          operation: ChunkV2DeleteOperation(chunkKey: created.chunkKey),
        ),
      );
      expect(deleteResult.accepted, isTrue);
      expect(deleteResult.document.chunks, hasLength(1));
      expect(deleteResult.document.createdChunkKeys, isEmpty);
      expect(deleteResult.document.changedChunkKeys, isEmpty);
      expect(
        const ChunkStore()
            .buildV2StagingSavePlan(document: deleteResult.document)
            .writes,
        isEmpty,
      );

      final renamedCreatedResult = policy.apply(
        document: createdDocument,
        commit: ChunkV2LifecycleCommit(
          before: ChunkV2LifecycleSnapshot.fromDocument(createdDocument),
          operation: const ChunkV2RenameOperation(
            chunkKey: 'forest_created',
            nextId: 'forest_created_renamed',
          ),
        ),
      );
      expect(renamedCreatedResult.accepted, isTrue);
      expect(
        renamedCreatedResult.document.sourcePathByChunkKey['forest_created']
            ?.replaceAll('\\', '/'),
        '${ChunkStore.chunksDirectoryPath}/forest/'
        'forest_created_renamed.json',
      );
    },
  );

  test(
    'v2 lifecycle duplicates, renames, and deletes with exact ownership',
    () {
      const policy = ChunkV2LifecycleCommitPolicy();
      final document = _document();
      final duplicatedResult = policy.apply(
        document: document,
        commit: ChunkV2LifecycleCommit(
          before: ChunkV2LifecycleSnapshot.fromDocument(document),
          operation: const ChunkV2DuplicateOperation(
            sourceChunkKey: 'forest_original',
          ),
        ),
      );
      expect(duplicatedResult.accepted, isTrue);
      final duplicate = duplicatedResult.document.chunks.singleWhere(
        (chunk) => chunk.chunkKey != 'forest_original',
      );
      expect(duplicate.id, 'forest_original_copy');
      expect(duplicate.revision, 1);
      expect(duplicate.status, chunkStatusActive);
      expect(duplicate.collisionShapes, document.chunks.single.collisionShapes);

      final renamedResult = policy.apply(
        document: document,
        commit: ChunkV2LifecycleCommit(
          before: ChunkV2LifecycleSnapshot.fromDocument(document),
          operation: const ChunkV2RenameOperation(
            chunkKey: 'forest_original',
            nextId: 'forest_renamed',
          ),
        ),
      );
      expect(renamedResult.accepted, isTrue);
      expect(renamedResult.document.chunks.single.chunkKey, 'forest_original');
      expect(renamedResult.document.chunks.single.id, 'forest_renamed');
      expect(renamedResult.document.chunks.single.revision, 5);
      final renameWrite = const ChunkStore()
          .buildV2StagingSavePlan(document: renamedResult.document)
          .writes
          .single;
      expect(
        renameWrite.previousRelativePath?.replaceAll('\\', '/'),
        '${ChunkStore.chunksDirectoryPath}/forest/forest_original.json',
      );
      expect(
        renameWrite.relativePath.replaceAll('\\', '/'),
        '${ChunkStore.chunksDirectoryPath}/forest/forest_renamed.json',
      );

      final deletedResult = policy.apply(
        document: document,
        commit: ChunkV2LifecycleCommit(
          before: ChunkV2LifecycleSnapshot.fromDocument(document),
          operation: const ChunkV2DeleteOperation(chunkKey: 'forest_original'),
        ),
      );
      expect(deletedResult.accepted, isTrue);
      expect(deletedResult.document.chunks, isEmpty);
      final deletion = const ChunkStore()
          .buildV2StagingSavePlan(document: deletedResult.document)
          .writes
          .single;
      expect(deletion.deleteFile, isTrue);
      expect(deletion.chunkKey, 'forest_original');
    },
  );

  test(
    'v2 lifecycle rejects stale invalid colliding and missing operations',
    () {
      const policy = ChunkV2LifecycleCommitPolicy();
      final document = _document();
      final snapshot = ChunkV2LifecycleSnapshot.fromDocument(document);
      final staleDocument = document.copyWith(
        chunks: <ChunkV2FileData>[document.chunks.single.copyWith(revision: 5)],
      );

      ChunkV2LifecycleCommitResult apply(
        ChunkV2StagingDocument target,
        ChunkV2LifecycleOperation operation,
      ) => policy.apply(
        document: target,
        commit: ChunkV2LifecycleCommit(before: snapshot, operation: operation),
      );

      expect(
        apply(
          staleDocument,
          const ChunkV2CreateOperation(id: 'forest_created'),
        ).document,
        same(staleDocument),
      );
      expect(
        apply(document, const ChunkV2CreateOperation(id: 'Bad ID')).document,
        same(document),
      );
      expect(
        apply(
          document,
          const ChunkV2CreateOperation(id: 'forest_original'),
        ).document,
        same(document),
      );
      expect(
        apply(
          document,
          const ChunkV2DeleteOperation(chunkKey: 'missing'),
        ).document,
        same(document),
      );
      final noOp = apply(
        document,
        const ChunkV2RenameOperation(
          chunkKey: 'forest_original',
          nextId: 'forest_original',
        ),
      );
      expect(noOp.accepted, isTrue);
      expect(noOp.changed, isFalse);
      expect(noOp.document, same(document));
    },
  );

  test('v2 transactional save keeps a clean source tree byte-identical', () {
    const store = ChunkStore();
    final document = _document();
    final fixture = _ChunkFixture.create(document);
    addTearDown(fixture.dispose);
    final plan = store.buildV2StagingSavePlan(document: document);
    final before = fixture.snapshot();

    store.applyV2StagingSavePlan(
      fixture.workspace,
      document: document,
      savePlan: plan,
    );

    expect(plan.hasChanges, isFalse);
    expect(fixture.snapshot(), before);
    expect(fixture.transactionFiles, isEmpty);
  });

  test('v2 managed move applies and reloads byte-identically', () async {
    const store = ChunkStore();
    final document = _document();
    final fixture = _ChunkFixture.create(document);
    addTearDown(fixture.dispose);
    final renamed = document.chunks.single.copyWith(
      id: 'forest_renamed',
      revision: 5,
    );
    final edited = document.copyWith(
      chunks: <ChunkV2FileData>[renamed],
      changedChunkKeys: <String>[renamed.chunkKey],
    );
    final plan = store.buildV2StagingSavePlan(document: edited);

    store.applyV2StagingSavePlan(
      fixture.workspace,
      document: edited,
      savePlan: plan,
    );

    final oldFile = File(
      fixture.workspace.resolve(
        document.sourcePathByChunkKey[renamed.chunkKey]!,
      ),
    );
    final newFile = File(
      fixture.workspace.resolve(plan.writes.single.relativePath),
    );
    expect(oldFile.existsSync(), isFalse);
    expect(newFile.readAsStringSync(), ChunkV2FileCodec.encode(renamed));
    final reloaded = await store.loadV2Staging(fixture.workspace);
    expect(reloaded.sources, hasLength(1));
    expect(
      ChunkV2FileCodec.encode(reloaded.sources.single.data),
      ChunkV2FileCodec.encode(renamed),
    );
    expect(
      reloaded.sources.single.sourcePath.replaceAll('\\', '/'),
      '${ChunkStore.chunksDirectoryPath}/forest/forest_renamed.json',
    );
    expect(fixture.transactionFiles, isEmpty);
  });

  test(
    'v2 create and loaded delete commit as one source-set replacement',
    () async {
      const store = ChunkStore();
      final document = _document();
      final fixture = _ChunkFixture.create(document);
      addTearDown(fixture.dispose);
      final created = document.chunks.single.copyWith(
        chunkKey: 'forest_created',
        id: 'forest_created',
        revision: 1,
      );
      final createdPath =
          '${ChunkStore.chunksDirectoryPath}/forest/forest_created.json';
      final edited = document.copyWith(
        chunks: <ChunkV2FileData>[created],
        sourcePathByChunkKey: <String, String>{
          ...document.sourcePathByChunkKey,
          created.chunkKey: createdPath,
        },
        createdChunkKeys: <String>[created.chunkKey],
        changedChunkKeys: <String>[created.chunkKey, 'forest_original'],
      );
      final plan = store.buildV2StagingSavePlan(document: edited);

      store.applyV2StagingSavePlan(
        fixture.workspace,
        document: edited,
        savePlan: plan,
      );

      final reloaded = await store.loadV2Staging(fixture.workspace);
      expect(reloaded.sources, hasLength(1));
      expect(reloaded.sources.single.data.chunkKey, 'forest_created');
      expect(
        reloaded.sources.single.baselineContents,
        ChunkV2FileCodec.encode(created),
      );
      expect(
        File(
          fixture.workspace.resolve(
            document.sourcePathByChunkKey['forest_original']!,
          ),
        ).existsSync(),
        isFalse,
      );
      expect(fixture.transactionFiles, isEmpty);
    },
  );

  test('v2 transactional save rejects byte and source-set drift', () {
    const store = ChunkStore();
    final document = _document();
    final changed = document.copyWith(
      chunks: <ChunkV2FileData>[document.chunks.single.copyWith(revision: 5)],
      changedChunkKeys: const <String>['forest_original'],
    );

    final byteFixture = _ChunkFixture.create(document);
    addTearDown(byteFixture.dispose);
    final plan = store.buildV2StagingSavePlan(document: changed);
    final sourceFile = byteFixture.sourceFile('forest_original');
    const drift = '{"external":"change"}\n';
    sourceFile.writeAsStringSync(drift);
    expect(
      () => store.applyV2StagingSavePlan(
        byteFixture.workspace,
        document: changed,
        savePlan: plan,
      ),
      throwsA(
        isA<ChunkV2StagingSaveException>().having(
          (error) => error.code,
          'code',
          'chunk_v2_save_source_drift',
        ),
      ),
    );
    expect(sourceFile.readAsStringSync(), drift);

    final setFixture = _ChunkFixture.create(document);
    addTearDown(setFixture.dispose);
    File(
        p.join(
          setFixture.root.path,
          ChunkStore.chunksDirectoryPath,
          'forest',
          'external.json',
        ),
      )
      ..createSync(recursive: true)
      ..writeAsStringSync(ChunkV2FileCodec.encode(document.chunks.single));
    expect(
      () => store.applyV2StagingSavePlan(
        setFixture.workspace,
        document: changed,
        savePlan: plan,
      ),
      throwsA(
        isA<ChunkV2StagingSaveException>().having(
          (error) => error.code,
          'code',
          'chunk_v2_save_source_set_drift',
        ),
      ),
    );
    expect(byteFixture.transactionFiles, isEmpty);
    expect(setFixture.transactionFiles, isEmpty);
  });

  test('v2 transactional save rejects a plan from another snapshot', () {
    const store = ChunkStore();
    final document = _document();
    final fixture = _ChunkFixture.create(document);
    addTearDown(fixture.dispose);
    final first = document.copyWith(
      chunks: <ChunkV2FileData>[document.chunks.single.copyWith(revision: 5)],
      changedChunkKeys: const <String>['forest_original'],
    );
    final second = document.copyWith(
      chunks: <ChunkV2FileData>[document.chunks.single.copyWith(revision: 6)],
      changedChunkKeys: const <String>['forest_original'],
    );
    final firstPlan = store.buildV2StagingSavePlan(document: first);

    expect(
      () => store.applyV2StagingSavePlan(
        fixture.workspace,
        document: second,
        savePlan: firstPlan,
      ),
      throwsA(
        isA<ChunkV2StagingSaveException>().having(
          (error) => error.code,
          'code',
          'chunk_v2_save_plan_stale',
        ),
      ),
    );
    expect(fixture.transactionFiles, isEmpty);
  });
}

ChunkV2StagingDocument _document() {
  final chunk = ChunkV2FileData(
    chunkKey: 'forest_original',
    id: 'forest_original',
    revision: 4,
    status: chunkStatusActive,
    levelId: 'forest',
    tileSize: 16,
    width: 100,
    height: 50,
    difficulty: chunkDifficultyNormal,
    assemblyGroupId: defaultChunkAssemblyGroupId,
    tags: const <String>['forest'],
    tileLayers: const <TileLayerDef>[],
    prefabs: const <PlacedPrefabDef>[],
    markers: const <PlacedMarkerDef>[],
    groundBandZIndex: 0,
    collisionShapes: const [],
  );
  final sourcePath =
      '${ChunkStore.chunksDirectoryPath}/forest/forest_original.json';
  return ChunkV2StagingDocument(
    chunks: <ChunkV2FileData>[chunk],
    sourcePathByChunkKey: <String, String>{chunk.chunkKey: sourcePath},
    baselineContentsByChunkKey: <String, String>{
      chunk.chunkKey: ChunkV2FileCodec.encode(chunk),
    },
    prefabData: PrefabV3FileData(
      slices: const <AtlasSliceDef>[],
      prefabs: const <PrefabV3Def>[],
    ),
    tileData: PrefabTileFileData(
      tileSlices: const <AtlasSliceDef>[],
      platformModules: const <TileModuleDef>[],
    ),
    visualBoundsByPrefabKey: const {},
    groundTopYByLevelId: const <String, double>{'forest': 10},
    levels: const <LevelDef>[_forestLevel],
    availableLevelIds: const <String>['forest'],
    activeLevelId: 'forest',
  );
}

const LevelDef _forestLevel = LevelDef(
  levelId: 'forest',
  revision: 1,
  displayName: 'Forest',
  visualThemeId: 'forest',
  cameraCenterY: 25,
  groundTopY: 10,
  earlyPatternChunks: 0,
  easyPatternChunks: 0,
  normalPatternChunks: 0,
  noEnemyChunks: 0,
  enumOrdinal: 1,
  status: levelStatusActive,
);

final class _ChunkFixture {
  _ChunkFixture._({required this.root, required this.document});

  factory _ChunkFixture.create(ChunkV2StagingDocument document) {
    final root = Directory.systemTemp.createTempSync('chunk_v2_save_plan_');
    final workspace = EditorWorkspace(rootPath: root.path);
    for (final entry in document.baselineContentsByChunkKey.entries) {
      final sourcePath = document.sourcePathByChunkKey[entry.key]!;
      File(workspace.resolve(sourcePath))
        ..createSync(recursive: true)
        ..writeAsStringSync(entry.value);
    }
    return _ChunkFixture._(root: root, document: document);
  }

  final Directory root;
  final ChunkV2StagingDocument document;

  EditorWorkspace get workspace => EditorWorkspace(rootPath: root.path);

  File sourceFile(String chunkKey) =>
      File(workspace.resolve(document.sourcePathByChunkKey[chunkKey]!));

  List<String> get transactionFiles => root
      .listSync(recursive: true)
      .whereType<File>()
      .map((file) => p.basename(file.path))
      .where((name) => name.contains('.authoring-'))
      .toList(growable: false);

  Map<String, List<int>> snapshot() => <String, List<int>>{
    for (final file
        in root.listSync(recursive: true).whereType<File>().toList()
          ..sort((left, right) => left.path.compareTo(right.path)))
      p.relative(file.path, from: root.path): file.readAsBytesSync(),
  };

  void dispose() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}
