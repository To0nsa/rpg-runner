import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:runner_core/bosses/boss_arena_definition.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_metadata_commit.dart';
import 'package:runner_editor/src/chunks/chunk_v2_models.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_v2_owner_form.dart';

void main() {
  testWidgets('boss selector commits identity and reports a dirty draft', (
    tester,
  ) async {
    final chunk = ChunkV2FileCodec.decode(
      File(
        '../../assets/authoring/level/chunks/forest/forest_boss_easy_001.json',
      ).readAsStringSync(),
    ).copyWith(assemblyGroupId: defaultChunkAssemblyGroupId);
    final document = ChunkV2Document(
      chunks: [chunk],
      sourcePathByChunkKey: {chunk.chunkKey: 'chunk.json'},
      baselineContentsByChunkKey: {
        chunk.chunkKey: ChunkV2FileCodec.encode(chunk),
      },
      prefabData: PrefabV3FileData(slices: [], prefabs: []),
      tileData: PrefabTileFileData(tileSlices: [], platformModules: []),
      visualBoundsByPrefabKey: const {},
      levels: const [],
      availableLevelIds: const ['forest'],
      activeLevelId: 'forest',
    );
    final key = GlobalKey<ChunkV2OwnerFormState>();
    ChunkV2OwnerFormValue? saved;
    var dirty = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChunkV2OwnerForm(
              key: key,
              document: document,
              chunk: chunk,
              onSubmit: (value) {
                saved = value;
                return true;
              },
              onCancel: () {},
              submitKey: const ValueKey('boss_test_submit'),
              onDirtyChanged: (value) => dirty = value,
            ),
          ),
        ),
      ),
    );
    expect(key.currentState!.isDirty, isFalse);
    final selector = find.byKey(const ValueKey('chunk_boss_enemy'));
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    expect(find.text('Voidborn Goddess'), findsOneWidget);
    expect(find.text('Shoggoth'), findsOneWidget);
    expect(find.text('Voidcaller'), findsOneWidget);
    await tester.tap(find.text('Voidborn Goddess'));
    await tester.pumpAndSettle();
    expect(dirty, isTrue);
    final submit = find.byKey(const ValueKey('boss_test_submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(saved!.bossArena!.enemyId, EnemyId.voidbornGoddess);
    expect(saved!.bossArena!.spawnX, chunk.bossArena!.spawnX);
  });
  test('boss data survives canonical Save and ordinary composition edits', () {
    final chunk = ChunkV2FileCodec.decode(
      File(
        '../../assets/authoring/level/chunks/forest/forest_boss_easy_001.json',
      ).readAsStringSync(),
    );
    expect(chunk.bossArena!.enemyId, EnemyId.bringerOfDeath);
    final saved = ChunkV2FileCodec.decode(
      ChunkV2FileCodec.encode(chunk.copyWith(revision: chunk.revision + 1)),
    );
    expect(saved.bossArena, chunk.bossArena);
    expect(saved.prefabs.length, chunk.prefabs.length);
    for (final id in bossEnemyIds) {
      final arena = BossArenaDefinition(
        id: '${id.name.toLowerCase()}_arena',
        enemyId: id,
        spawnX: 440,
        minX: 24,
        maxX: 576,
      );
      final saved = ChunkV2FileCodec.decode(
        ChunkV2FileCodec.encode(chunk.copyWith(bossArena: arena)),
      );
      expect(saved.bossArena, arena);
    }
  });
  test('arena edit and removal use the metadata revision guard', () {
    final chunk = ChunkV2FileCodec.decode(
      File(
        '../../assets/authoring/level/chunks/forest/forest_boss_easy_001.json',
      ).readAsStringSync(),
    );
    final before = ChunkV2MetadataSnapshot.fromChunk(chunk);
    final after = ChunkV2MetadataSnapshot(
      status: chunk.status,
      levelId: chunk.levelId,
      difficulty: chunk.difficulty,
      assemblyGroupId: chunk.assemblyGroupId,
      tags: chunk.tags,
      groundBandZIndex: chunk.groundBandZIndex,
      bossArena: BossArenaDefinition(
        id: chunk.bossArena!.id,
        enemyId: EnemyId.bringerOfDeath,
        spawnX: 460,
        minX: 24,
        maxX: 576,
      ),
    );
    final result = const ChunkV2MetadataCommitPolicy().apply(
      chunk: chunk,
      commit: ChunkV2MetadataCommit(before: before, after: after),
      knownLevelIds: ['forest'],
      allowedAssemblyGroupIdsByLevelId: {
        'forest': [chunk.assemblyGroupId],
      },
    );
    expect(result.accepted, isTrue);
    expect(result.chunk.bossArena!.spawnX, 460);
    expect(result.chunk.revision, chunk.revision + 1);
    final stale = const ChunkV2MetadataCommitPolicy().apply(
      chunk: result.chunk,
      commit: ChunkV2MetadataCommit(before: before, after: after),
      knownLevelIds: ['forest'],
      allowedAssemblyGroupIdsByLevelId: {
        'forest': [chunk.assemblyGroupId],
      },
    );
    expect(stale.accepted, isFalse);
    expect(result.chunk.copyWith(clearBossArena: true).bossArena, isNull);
  });
}
