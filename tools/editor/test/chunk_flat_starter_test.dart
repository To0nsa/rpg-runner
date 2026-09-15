import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_level_target.dart';
import 'package:runner_editor/src/chunks/chunk_v2_lifecycle_commit.dart';
import 'package:runner_editor/src/chunks/chunk_v2_metadata_commit.dart';
import 'package:runner_editor/src/chunks/chunk_v2_models.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/levels/level_domain_plugin.dart';
import 'package:runner_editor/src/playtest/authored_playtest_preparation.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

import 'test_support/chunk_level_fixture.dart';

void main() {
  late EditorWorkspace workspace;
  late ChunkDomainPlugin plugin;
  setUp(() async {
    workspace = await createChunkLevelFixture();
    plugin = ChunkDomainPlugin();
  });

  Future<ChunkV2Document> load({String? groupId, String? chunkKey}) =>
      plugin.loadForLevel(
        workspace,
        target: ChunkLevelTarget(
          'forest',
          groupId: groupId,
          chunkKey: chunkKey,
        ),
      );
  ChunkV2Document create(
    ChunkV2Document document,
    ChunkFlatStarterIntent intent,
  ) => plugin.applyEdit(
    document,
    AuthoringCommand(
      kind: ChunkDomainPlugin.createFlatStarterCommandKind,
      payload: {'intent': intent},
    ),
  ) as ChunkV2Document;

  test(
    'empty authored Level creates and saves one ready early flat chunk',
    () async {
      final document = await load();
      expect(document.chunks, isEmpty);
      expect(document.activeLevelId, 'forest');
      final intent = plugin.flatStarterIntentForLevel(
        document,
        levelId: 'forest',
      );
      final next = create(document, intent);
      final chunk = next.chunks.single;
      expect(chunk.width, 600);
      expect(chunk.height, 270);
      expect(chunk.tileSize, 16);
      expect(chunk.difficulty, 'early');
      expect(chunk.status, 'active');
      expect(chunk.assemblyGroupId, 'default');
      expect(chunk.collisionShapes.single.materialKey, 'grass_dirt');
      expect(chunk.collisionShapes.single.vertices.first.yHalfPixels, 448);
      expect(chunk.prefabs, isEmpty);
      expect(chunk.markers, isEmpty);
      expect(plugin.validate(next), isEmpty);
      final chunkPlay = preparePlaytest(
        await captureChunkPlaytestPreparationInput(
          document: next,
          selectedChunkKey: chunk.chunkKey,
          workspaceRoot: workspace.rootPath,
        ),
      );
      expect(
        chunkPlay.isSuccess,
        isTrue,
        reason: chunkPlay.issues.map((issue) => issue.message).join('\n'),
      );
      final levelDocument = await LevelDomainPlugin().loadFromRepo(
        workspace,
      ) as LevelDefsDocument;
      final levelPlay = preparePlaytest(
        await captureLevelPlaytestPreparationInput(
          document: levelDocument,
          levelId: 'forest',
          contentDocument: next,
          workspaceRoot: workspace.rootPath,
        ),
      );
      expect(
        levelPlay.isSuccess,
        isTrue,
        reason: levelPlay.issues.map((issue) => issue.message).join('\n'),
      );
      expect(create(next, intent), same(next));
      expect(
        (await plugin.exportToRepo(workspace, document: next)).applied,
        isTrue,
      );
      final saved = await load(chunkKey: intent.chunkKey);
      expect(saved.createdChunkKeys, isEmpty);
      expect(saved.chunks.single.revision, 1);
      expect(create(saved, intent), same(saved));
      expect(
        plugin.describePendingChanges(workspace, document: saved).hasChanges,
        isFalse,
      );
      expect(
        plugin.flatStarterIntentForLevel(saved, levelId: 'forest').chunkKey,
        intent.chunkKey,
      );
      expect(
        (plugin.buildEditableScene(saved) as ChunkV2Scene).selectedChunkKey,
        intent.chunkKey,
      );
    },
  );

  test(
    'section design seeds first referenced group and saves incomplete pool',
    () async {
      final level = _level.copyWith(
        chunkThemeGroups: ['default', 'woods'],
        assembly: const LevelAssemblyDef(
          loopSegments: true,
          segments: [
            LevelAssemblySegmentDef(
              segmentId: 'opening',
              groupId: 'woods',
              minChunkCount: 2,
              maxChunkCount: 2,
              requireDistinctChunks: true,
            ),
          ],
        ),
      );
      _write(
        workspace,
        levelDefsSourcePath,
        renderCanonicalLevelDefsJson([level]),
      );
      final document = await load(groupId: 'woods');
      final intent = plugin.flatStarterIntentForLevel(
        document,
        levelId: 'forest',
      );
      expect(intent.groupId, 'woods');
      final next = create(document, intent);
      final issues = plugin.validate(next);
      expect(
        issues.any(
          (issue) => issue.code == 'terrain_connection_schedule_dead_end',
        ),
        isTrue,
      );
      expect(
        issues.any((issue) => issue.blocks(AuthoringOperation.save)),
        isFalse,
      );
      expect(
        issues.any((issue) => issue.blocks(AuthoringOperation.play)),
        isTrue,
      );
      expect(
        issues.any((issue) => issue.blocks(AuthoringOperation.build)),
        isFalse,
      );
      expect(
        (await plugin.exportToRepo(workspace, document: next)).applied,
        isTrue,
      );
      expect((await load()).chunks.single.assemblyGroupId, 'woods');
    },
  );

  test(
    'missing and moved owner or group cannot silently change target',
    () async {
      await expectLater(
        plugin.loadForLevel(
          workspace,
          target: const ChunkLevelTarget('missing'),
        ),
        throwsA(
          isA<ChunkTargetException>().having(
            (e) => e.code,
            'code',
            'chunk_target_level_missing',
          ),
        ),
      );
      await expectLater(
        load(groupId: 'missing'),
        throwsA(isA<ChunkTargetException>()),
      );
      await expectLater(
        load(chunkKey: 'missing'),
        throwsA(isA<ChunkTargetException>()),
      );
    },
  );

  test('missing or invalid source material and non-integral ground reject creation', () async {
    var document = await load();
    final intent = plugin.flatStarterIntentForLevel(
      document,
      levelId: 'forest',
    );
    expect(
      () => create(document.copyWith(availableTerrainMaterialKeys: []), intent),
      throwsA(
        isA<ChunkTargetException>().having(
          (e) => e.code,
          'code',
          'flat_starter_material_unavailable',
        ),
      ),
    );
    expect(
      () => create(
        document.copyWith(levels: [_level.copyWith(groundTopY: 224.5)]),
        intent,
      ),
      throwsA(
        isA<ChunkTargetException>().having(
          (e) => e.code,
          'code',
          'flat_starter_ground_invalid',
        ),
      ),
    );
    File(workspace.resolve('assets/images/level/atlases/test/ground.png'))
        .writeAsStringSync('broken');
    document = await load();
    expect(
      () => create(document, intent),
      throwsA(
        isA<ChunkTargetException>().having(
          (e) => e.issues.map((issue) => issue.code),
          'issues',
          contains('terrain_material_asset_invalid'),
        ),
      ),
    );
  });

  test(
    'empty custom creation uses standard dimensions and requested group',
    () async {
      _write(
        workspace,
        levelDefsSourcePath,
        renderCanonicalLevelDefsJson([
          _level.copyWith(chunkThemeGroups: ['default', 'woods']),
        ]),
      );
      final before = await load(groupId: 'woods');
      final result = const ChunkV2LifecycleCommitPolicy().apply(
        document: before,
        commit: ChunkV2LifecycleCommit(
          before: ChunkV2LifecycleSnapshot.fromDocument(before),
          operation: const ChunkV2CreateOperation(id: 'custom'),
        ),
      );
      expect(
        result.accepted,
        isTrue,
        reason: result.issues.map((i) => i.message).join('\n'),
      );
      final chunk = result.document.chunks.single;
      expect(chunk.status, 'deprecated');
      expect(chunk.collisionShapes, isEmpty);
      expect(chunk.assemblyGroupId, 'woods');
      expect((chunk.width, chunk.height, chunk.tileSize), (600, 270, 16));
      expect(
        (await plugin.exportToRepo(
          workspace,
          document: result.document,
        )).applied,
        isTrue,
      );
    },
  );

  test('moving the final group member remains saveable and identifies runtime blocker', () async {
    _write(
      workspace,
      levelDefsSourcePath,
      renderCanonicalLevelDefsJson([
        _level.copyWith(
          includeInBuild: true,
          chunkThemeGroups: ['default', 'woods'],
          assembly: const LevelAssemblyDef(
            loopSegments: true,
            segments: [
              LevelAssemblySegmentDef(
                segmentId: 'opening',
                groupId: 'woods',
                minChunkCount: 1,
                maxChunkCount: 1,
                requireDistinctChunks: false,
              ),
            ],
          ),
        ),
      ]),
    );
    final initial = await load(groupId: 'woods');
    final intent = plugin.flatStarterIntentForLevel(initial, levelId: 'forest');
    final created = create(initial, intent);
    final chunk = created.chunks.single;
    final moved = plugin.applyEdit(
      created,
      AuthoringCommand(
        kind: ChunkDomainPlugin.commitChunkMetadataCommandKind,
        payload: {
          'chunkKey': chunk.chunkKey,
          'commit': ChunkV2MetadataCommit(
            before: ChunkV2MetadataSnapshot.fromChunk(chunk),
            after: ChunkV2MetadataSnapshot(
              status: chunk.status,
              levelId: chunk.levelId,
              difficulty: chunk.difficulty,
              assemblyGroupId: 'default',
              tags: chunk.tags,
              groundBandZIndex: chunk.groundBandZIndex,
            ),
          ),
        },
      ),
    ) as ChunkV2Document;
    expect(moved.chunks.single.assemblyGroupId, 'default');
    final issue = plugin
        .validate(moved)
        .firstWhere((i) => i.code == 'terrain_connection_schedule_dead_end');
    expect(issue.ownerKey, 'forest');
    expect(issue.blocks(AuthoringOperation.save), isFalse);
    expect(issue.blocks(AuthoringOperation.play), isTrue);
    expect(issue.blocks(AuthoringOperation.build), isTrue);
    await plugin.exportToRepo(workspace, document: moved);
    final reopened = await load();
    expect(
      plugin.flatStarterIntentForLevel(reopened, levelId: 'forest').chunkKey,
      intent.chunkKey,
    );
  });

  test(
    'reserved identity retry preserves saved edits and never duplicates',
    () async {
      final before = await load();
      final intent = plugin.flatStarterIntentForLevel(
        before,
        levelId: 'forest',
      );
      final created = create(before, intent);
      await plugin.exportToRepo(workspace, document: created);
      final persisted = await load();
      final savedEdit = persisted.copyWith(
        chunks: [
          persisted.chunks.single.copyWith(
            id: 'renamed',
            revision: 2,
            tags: ['edited'],
          ),
        ],
      );
      await plugin.exportToRepo(workspace, document: savedEdit);
      final reopened = await load();
      final resumed = create(reopened, intent);
      expect(resumed.chunks.single.id, 'renamed');
      expect(resumed.chunks.single.revision, 2);
      expect(resumed.chunks.single.tags, ['edited']);
      expect(
        plugin.describePendingChanges(workspace, document: resumed).hasChanges,
        isFalse,
      );
    },
  );
}

void _write(EditorWorkspace workspace, String path, String contents) {
  final file = File(p.join(workspace.rootPath, path));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}

const _level = standardChunkFixtureLevel;
