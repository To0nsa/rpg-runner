import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/combat/ai_target_policy.dart';
import 'package:runner_core/encounters/encounter_limits.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_editor/src/chunks/chunk_encounter_edit.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_v2_composition_commit.dart';
import 'package:runner_editor/src/chunks/chunk_v2_composition_operation.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/chunks/chunk_v2_models.dart';
import 'package:runner_editor/src/chunks/chunk_v2_validation.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

ChunkV2FileData _chunk() => ChunkV2FileCodec.decode(
  File('../../docs/examples/rescue_encounter_chunk.json').readAsStringSync(),
);
ChunkV2Document _document(ChunkV2FileData chunk) => ChunkV2Document(
  chunks: [chunk],
  sourcePathByChunkKey: {chunk.chunkKey: 'chunk.json'},
  baselineContentsByChunkKey: {chunk.chunkKey: ChunkV2FileCodec.encode(chunk)},
  prefabData: PrefabV3FileData(slices: [], prefabs: []),
  tileData: PrefabTileFileData(tileSlices: [], platformModules: []),
  visualBoundsByPrefabKey: const {},
  groundTopYByLevelId: const {'field': 224},
  availableLevelIds: const ['field'],
  activeLevelId: 'field',
  levels: const [
    LevelDef(
      levelId: 'field',
      revision: 1,
      displayName: 'Field',
      visualThemeId: 'field',
      cameraCenterY: 135,
      groundTopY: 224,
      earlyPatternChunks: 0,
      easyPatternChunks: 0,
      normalPatternChunks: 0,
      noEnemyChunks: 0,
      enumOrdinal: 0,
      status: levelStatusActive,
    ),
  ],
);

void main() {
  test(
    'group and member edits preserve identity and explicit override intent',
    () {
      final original = _chunk().encounters.single;
      final member = original.enemies.single;
      final edited = replaceEncounterMember(
        original,
        editEncounterEnemy(
          member,
          x: 450,
          targetPolicy: AiTargetPolicy.playerOnly,
        ),
      );
      expect(edited.id, original.id);
      expect(edited.enemies.single.id, member.id);
      expect(edited.enemies.single.targetPolicy, AiTargetPolicy.playerOnly);
      final inherited = replaceEncounterMember(
        edited,
        editEncounterEnemy(edited.enemies.single, useEncounterPolicy: true),
      );
      expect(inherited.enemies.single.targetPolicy, isNull);
      final overridden = editEncounter(
        inherited,
        name: 'Renamed',
        pointsPerNpc: EncounterLimits.defaultPointsPerNpc,
      );
      expect(overridden.pointsPerNpc, EncounterLimits.defaultPointsPerNpc);
      expect(editEncounter(overridden, pointsPerNpc: 0).pointsPerNpc, 0);
      expect(
        editEncounter(overridden, useDefaultPoints: true).pointsPerNpc,
        isNull,
      );
      expect(overridden.id, original.id);
      expect(original.enemies.single.x, isNot(450));
    },
  );

  for (final npcId in [NpcId.huntress, NpcId.huntress2]) {
    test('adding and duplicating ${npcId.name} after Warrior commits', () {
      final chunk = _chunk();
      final original = chunk.encounters.single;
      final member = editEncounterNpc(
        original.npcs.single,
        id: npcId.name,
        npcId: npcId,
        x: 320,
      );
      final added = addEncounterMember(original, member);
      final duplicated = addEncounterMember(
        added,
        duplicateEncounterMember(added, member),
      );
      for (final candidate in [added, duplicated]) {
        final commit = ChunkV2CompositionOperation.replace(
          chunk: chunk,
          target: ChunkV2CompositionTarget.encounters,
          sourceIndex: 0,
        ).buildEncounter(candidate: candidate)!;
        final result = const ChunkV2CompositionCommitPolicy().apply(
          document: _document(chunk),
          chunkIndex: 0,
          commit: commit,
        );
        expect(result.accepted, isTrue, reason: result.issues.toString());
        expect(result.chunk.revision, chunk.revision + 1);
        expect(result.chunk.encounters.single.npcs.map((m) => m.id), [
          npcId.name,
          if (identical(candidate, duplicated)) '${npcId.name}_2',
          'warrior',
        ]);
        expect(
          encounterDefinitionsToJson(
            ChunkV2FileCodec.decode(ChunkV2FileCodec.encode(result.chunk))
                .encounters,
          ),
          encounterDefinitionsToJson(result.chunk.encounters),
        );
      }
      expect(original.npcs.single.id, 'warrior');
      expect(added.npcs, hasLength(2));
    });
  }

  test('duplicating an earlier enemy preserves canonical source order', () {
    final chunk = _chunk();
    final original = chunk.encounters.single;
    final withEnemy = addEncounterMember(
      original,
      editEncounterEnemy(original.enemies.single, id: 'enemy', x: 480),
    );
    final candidate = addEncounterMember(
      withEnemy,
      duplicateEncounterMember(withEnemy, original.enemies.single),
    );
    final commit = ChunkV2CompositionOperation.replace(
      chunk: chunk,
      target: ChunkV2CompositionTarget.encounters,
      sourceIndex: 0,
    ).buildEncounter(candidate: candidate)!;
    final result = const ChunkV2CompositionCommitPolicy().apply(
      document: _document(chunk),
      chunkIndex: 0,
      commit: commit,
    );
    expect(result.accepted, isTrue, reason: result.issues.toString());
    expect(result.chunk.encounters.single.enemies.map((m) => m.id), [
      'ambusher',
      'ambusher_2',
      'enemy',
    ]);
    expect(withEnemy.enemies.map((m) => m.id), ['ambusher', 'enemy']);
    expect(original.enemies.single.id, 'ambusher');
  });

  test('duplicate groups and members allocate separate local identities', () {
    final chunk = _chunk();
    final original = chunk.encounters.single;
    final copy = duplicateChunkEncounter(original, chunk.encounters);
    expect(copy.id, isNot(original.id));
    expect(copy.npcs.single.id, original.npcs.single.id);
    final duplicate = duplicateEncounterMember(original, original.npcs.single);
    final group = addEncounterMember(original, duplicate);
    expect(group.npcs.map((e) => e.id).toSet(), hasLength(2));
    final commit = ChunkV2CompositionOperation.add(
      chunk: chunk,
      target: ChunkV2CompositionTarget.encounters,
    ).buildEncounter(candidate: copy)!;
    final result = const ChunkV2CompositionCommitPolicy().apply(
      document: _document(chunk),
      chunkIndex: 0,
      commit: commit,
    );
    expect(result.accepted, isTrue);
    expect(result.chunk.revision, chunk.revision + 1);
    expect(
      ChunkV2FileCodec.decode(ChunkV2FileCodec.encode(result.chunk)).encounters,
      hasLength(2),
    );
    final long = List.filled(64, 'a').join();
    final fresh = nextEncounterSourceId(long, [long]);
    expect(fresh.length, 64);
    expect(fresh.endsWith('_2'), isTrue);
  });

  test(
    'delete group is atomic, no-op is history-neutral, stale rename rejects',
    () {
      final chunk = _chunk();
      final group = chunk.encounters.single;
      final replace = ChunkV2CompositionOperation.replace(
        chunk: chunk,
        target: ChunkV2CompositionTarget.encounters,
        sourceIndex: 0,
      );
      expect(replace.buildEncounter(candidate: editEncounter(group)), isNull);
      final rename = replace.buildEncounter(
        candidate: editEncounter(group, name: 'Rescue'),
      )!;
      final result = const ChunkV2CompositionCommitPolicy().apply(
        document: _document(chunk.copyWith(revision: chunk.revision + 1)),
        chunkIndex: 0,
        commit: rename,
      );
      expect(result.accepted, isFalse);
      final deletion = ChunkV2CompositionOperation.delete(
        chunk: chunk,
        target: ChunkV2CompositionTarget.encounters,
        sourceIndex: 0,
      ).buildEncounter()!;
      expect(deletion.before.encounters.single.npcs, isNotEmpty);
      expect(deletion.after.encounters, isEmpty);
      expect(deletion.after.markers, chunk.markers);
      expect(deletion.after.prefabs, chunk.prefabs);
    },
  );

  test(
    'removing the last required member is a saveable incomplete command',
    () {
      final chunk = _chunk();
      final group = chunk.encounters.single;
      final commit =
          ChunkV2CompositionOperation.replace(
            chunk: chunk,
            target: ChunkV2CompositionTarget.encounters,
            sourceIndex: 0,
          ).buildEncounter(
            candidate: removeEncounterMember(group, group.enemies.single.id),
          )!;
      final result = const ChunkV2CompositionCommitPolicy().apply(
        document: _document(chunk),
        chunkIndex: 0,
        commit: commit,
      );
      expect(result.accepted, isTrue);
      expect(
        result.issues.where((e) => e.blocks(AuthoringOperation.save)),
        isEmpty,
      );
      expect(
        result.issues.where((e) => e.code == 'encounter_incomplete'),
        hasLength(1),
      );
      expect(
        () => removeEncounterMember(group, 'missing'),
        throwsArgumentError,
      );
    },
  );

  test('editor export and shared materialization preserve the same encounter facts', () {
    final original = _chunk();
    final source = ChunkV2FileCodec.encode(original);
    final copied = original.copyWith(chunkKey: 'copy', id: 'copy', revision: 2);
    expect(copied.encounters.single.id, original.encounters.single.id);
    final decoded = ChunkV2FileCodec.decode(source);
    final compiled = decodePolygonTerrainChunk(source);
    expect(
      encounterDefinitionsToJson(compiled.encounters),
      encounterDefinitionsToJson(decoded.encounters),
    );
    expect(ChunkV2FileCodec.encode(decoded), source);
    expect(() => decoded.encounters.clear(), throwsUnsupportedError);
    expect(
      () => decoded.encounters.single.enemies.clear(),
      throwsUnsupportedError,
    );
    expect(
      ChunkV2FileCodec.encode(original.copyWith(encounters: [])),
      isNot(contains('"encounters"')),
    );
  });
  test('all unrelated composition operations retain encounters and detect stale snapshots', () {
    final chunk = _chunk().copyWith(
      markers: [const PlacedMarkerDef(markerId: 'grojib', x: 400, y: 0)],
    );
    final markerEdit = ChunkV2CompositionOperation.delete(
      chunk: chunk,
      target: ChunkV2CompositionTarget.markers,
      sourceIndex: 0,
    ).buildMarker()!;
    final layerEdit = ChunkV2CompositionOperation.add(
      chunk: chunk,
      target: ChunkV2CompositionTarget.tileLayers,
    ).buildTileLayer(candidate: const TileLayerDef(id: 'back'))!;
    for (final edit in [markerEdit, layerEdit]) {
      expect(edit.before.encounters, chunk.encounters);
      expect(edit.after.encounters, chunk.encounters);
    }
    final changed = chunk.copyWith(encounters: []);
    final result = const ChunkV2CompositionCommitPolicy().apply(
      document: _document(changed),
      chunkIndex: 0,
      commit: markerEdit,
    );
    expect(result.accepted, isFalse);
    expect(result.issues.single.code, 'chunk_v2_composition_commit_stale');
  });
  test('incomplete encounter commits once and remains saveable with runtime diagnostics', () {
    final chunk = _chunk();
    final e = chunk.encounters.single;
    final after = ChunkV2CompositionSnapshot(
      tileLayers: chunk.tileLayers,
      prefabs: chunk.prefabs,
      markers: chunk.markers,
      encounters: [
        EncounterDefinition(
          id: e.id,
          name: e.name,
          trigger: e.trigger,
          npcs: e.npcs,
          pointsPerNpc: 0,
        ),
      ],
    );
    final commit = ChunkV2CompositionCommit(
      expectedChunkKey: chunk.chunkKey,
      expectedRevision: chunk.revision,
      before: ChunkV2CompositionSnapshot.fromChunk(chunk),
      after: after,
    );
    final plugin = ChunkDomainPlugin();
    final document = _document(chunk);
    final edited = plugin.applyEdit(
      document,
      AuthoringCommand(
        kind: ChunkDomainPlugin.commitChunkCompositionCommandKind,
        payload: {'chunkKey': chunk.chunkKey, 'commit': commit},
      ),
    ) as ChunkV2Document;
    expect(edited, isNot(same(document)));
    expect(edited.chunks.single.revision, chunk.revision + 1);
    final issues = validateChunkV2Document(edited);
    expect(issues.where((i) => i.blocks(AuthoringOperation.save)), isEmpty);
    final incomplete = issues.singleWhere(
      (i) => i.code == 'encounter_incomplete',
    );
    expect(incomplete.blocks(AuthoringOperation.play), isTrue);
    expect(incomplete.blocks(AuthoringOperation.build), isTrue);
    expect(incomplete.elementId, e.id);
    final source = ChunkV2FileCodec.encode(edited.chunks.single);
    expect(ChunkV2FileCodec.decode(source).encounters.single.pointsPerNpc, 0);
    final pending = plugin.describePendingChanges(
      EditorWorkspace(rootPath: Directory.current.path),
      document: edited,
    );
    expect(pending.fileDiffs.single.unifiedDiff, contains('pointsPerNpc'));
  });
  test('points absence, explicit default and zero remain distinct in semantic equality', () {
    final chunk = _chunk();
    ChunkV2CompositionSnapshot withPoints(int? points) {
      final json = chunk.toJson();
      final e = (json['encounters'] as List).single as Map<String, Object>;
      if (points != null) e['pointsPerNpc'] = points;
      return ChunkV2CompositionSnapshot.fromChunk(
        ChunkV2FileCodec.decode(jsonEncode(json)),
      );
    }

    expect(
      chunkCompositionSnapshotsEqual(withPoints(null), withPoints(0)),
      isFalse,
    );
    expect(
      chunkCompositionSnapshotsEqual(withPoints(null), withPoints(250)),
      isFalse,
    );
    expect(
      chunkCompositionSnapshotsEqual(withPoints(250), withPoints(250)),
      isTrue,
    );
  });
}
