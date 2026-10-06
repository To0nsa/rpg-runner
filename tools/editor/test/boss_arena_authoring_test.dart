import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/bosses/boss_arena_definition.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_metadata_commit.dart';

void main() {
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
