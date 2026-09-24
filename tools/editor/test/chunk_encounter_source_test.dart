import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/encounters/encounter_definition.dart';
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
