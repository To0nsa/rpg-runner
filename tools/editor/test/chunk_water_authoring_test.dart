import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/terrain/water_region.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_water_edit_draft.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/chunks/chunk_v2_models.dart';
import 'package:runner_editor/src/chunks/chunk_water_commit.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';

import 'test_support/chunk_level_fixture.dart';

void main() {
  test(
    'plugin commits water once and includes it in the normal Save diff',
    () async {
      final workspace = await createChunkLevelFixture();
      final chunk = _example().copyWith(levelId: 'forest', waterRegions: []);
      final path =
          'assets/authoring/level/chunks/forest/water_pool_example.json';
      final file = File(workspace.resolve(path));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(ChunkV2FileCodec.encode(chunk));
      final plugin = ChunkDomainPlugin();
      final document = await plugin.loadV2FromRepo(workspace);
      final pool = WaterRegionData(
        id: 'pool',
        x: 128,
        y: 224,
        width: 320,
        height: 64,
        materialKey: 'grass_dirt',
      );
      final commit = ChunkWaterCommit(
        expectedRevision: chunk.revision,
        regions: [pool],
      );
      final command = AuthoringCommand(
        kind: ChunkDomainPlugin.commitChunkWaterCommandKind,
        payload: {'chunkKey': chunk.chunkKey, 'commit': commit},
      );
      final next = plugin.applyEdit(document, command) as ChunkV2Document;
      expect(next.chunks.single.revision, chunk.revision + 1);
      expect(next.chunks.single.waterRegions, [pool]);
      expect(
        plugin.applyEdit(next, command),
        same(next),
        reason: 'Stale edits are rejected.',
      );
      final pending = plugin.describePendingChanges(workspace, document: next);
      expect(pending.fileDiffs.single.unifiedDiff, contains('waterRegions'));
      final encoded = ChunkV2FileCodec.encode(next.chunks.single);
      expect(ChunkV2FileCodec.decode(encoded).waterRegions, [pool]);
      expect(
        next.chunks.single
            .copyWith(chunkKey: 'copy', id: 'copy', revision: 1)
            .waterRegions,
        [pool],
      );
      expect(
        ChunkWaterCommit(
          expectedRevision: next.chunks.single.revision,
          regions: [pool],
        ).apply(next.chunks.single),
        same(next.chunks.single),
      );
    },
  );

  test('inline water metadata and dimensions validate and commit together', () {
    final chunk = _example();
    final draft = ChunkWaterEditDraft(chunk, chunk.waterRegions.single);
    draft.nameInput = 'new_pool';
    draft.materialKey = 'grass_dirt';
    expect(draft.hasMetadataChanges, isTrue);
    expect(
      draft.buildCommit(
        xHalfPixels: 256,
        bottomYHalfPixels: 576,
        widthHalfPixels: 1800,
        heightHalfPixels: 128,
      ),
      isNull,
    );
    expect(draft.error, contains('must fit inside'));
    final commit = draft.buildCommit(
      xHalfPixels: 256,
      bottomYHalfPixels: 576,
      widthHalfPixels: 640,
      heightHalfPixels: 128,
    )!;
    final next = commit.apply(chunk);
    expect(next.revision, chunk.revision + 1);
    expect(next.waterRegions.single.id, 'new_pool');
    expect(next.waterRegions.single.materialKey, 'grass_dirt');
    expect(commit.apply(next), same(next));
    draft.nameInput = 'INVALID';
    expect(draft.nameError, isNotNull);
    draft.discard();
    expect(draft.hasMetadataChanges, isFalse);
    expect(draft.nameError, isNull);
    expect(
      draft.buildCommit(
        xHalfPixels: 257,
        bottomYHalfPixels: 576,
        widthHalfPixels: 640,
        heightHalfPixels: 128,
      ),
      isNull,
    );
  });
}

ChunkV2FileData _example() => ChunkV2FileCodec.decode(
  File('../../docs/examples/water_pool_chunk.json').readAsStringSync(),
);
