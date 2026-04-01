import 'package:flutter_test/flutter_test.dart';

import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_validation.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';

void main() {
  test('validateChunkDocument reports structural and level-context errors', () {
    const invalidChunk = LevelChunkDef(
      chunkKey: 'chunk_a',
      id: 'chunk_a',
      revision: 1,
      schemaVersion: 1,
      levelId: 'forest',
      tileSize: 15,
      width: 590,
      height: 150,
      entrySocket: 'in',
      exitSocket: 'out',
      difficulty: 'nightmare',
      groundProfile: GroundProfileDef(kind: 'slope', topY: 3),
      groundGaps: <GroundGapDef>[
        GroundGapDef(gapId: 'gap_1', type: 'pit', x: 16, width: 80),
        GroundGapDef(gapId: 'gap_1', type: 'pit', x: 64, width: 64),
      ],
    );
    const document = ChunkDocument(
      chunks: <LevelChunkDef>[invalidChunk],
      baselineByChunkKey: <String, ChunkSourceBaseline>{},
      availableLevelIds: <String>['field'],
      activeLevelId: 'field',
      levelOptionSource: 'test',
      runtimeGridSnap: 16.0,
      runtimeChunkWidth: 600.0,
    );

    final issues = validateChunkDocument(document);
    final codes = issues.map((issue) => issue.code).toSet();

    expect(codes, contains('unknown_level_id'));
    expect(codes, contains('active_level_mismatch'));
    expect(codes, contains('chunk_width_mismatch'));
    expect(codes, contains('chunk_grid_snap_violation'));
    expect(codes, contains('invalid_difficulty'));
    expect(codes, contains('invalid_ground_profile_kind'));
    expect(codes, contains('ground_profile_snap_violation'));
    expect(codes, contains('duplicate_gap_id'));
    expect(codes, contains('overlapping_gaps'));
  });

  test('reports required-field and revision/schema failures', () {
    const missingFields = LevelChunkDef(
      chunkKey: '',
      id: '',
      revision: 0,
      schemaVersion: 0,
      levelId: '',
      tileSize: 0,
      width: 0,
      height: 0,
      entrySocket: '',
      exitSocket: '',
      difficulty: chunkDifficultyNormal,
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 0),
    );
    const document = ChunkDocument(
      chunks: <LevelChunkDef>[missingFields],
      baselineByChunkKey: <String, ChunkSourceBaseline>{},
      availableLevelIds: <String>[],
      activeLevelId: null,
      levelOptionSource: 'test',
      runtimeGridSnap: 16.0,
      runtimeChunkWidth: 600.0,
    );

    final codes = validateChunkDocument(document).map((i) => i.code).toSet();
    expect(codes, contains('missing_level_options'));
    expect(codes, contains('missing_active_level'));
    expect(codes, contains('missing_chunk_key'));
    expect(codes, contains('missing_chunk_id'));
    expect(codes, contains('invalid_schema_version'));
    expect(codes, contains('missing_level_id'));
    expect(codes, contains('invalid_revision'));
    expect(codes, contains('invalid_tile_size'));
    expect(codes, contains('invalid_chunk_dimensions'));
    expect(codes, contains('missing_socket'));
  });

  test('reports malformed chunkKey and duplicate chunk ids', () {
    const malformed = LevelChunkDef(
      chunkKey: 'Chunk Bad',
      id: 'chunk_1',
      revision: 1,
      schemaVersion: 1,
      levelId: 'field',
      tileSize: 16,
      width: 600,
      height: 160,
      entrySocket: 'in',
      exitSocket: 'out',
      difficulty: chunkDifficultyNormal,
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 0),
    );
    const duplicateId = LevelChunkDef(
      chunkKey: 'chunk_2',
      id: 'chunk_1',
      revision: 1,
      schemaVersion: 1,
      levelId: 'field',
      tileSize: 16,
      width: 600,
      height: 160,
      entrySocket: 'in',
      exitSocket: 'out',
      difficulty: chunkDifficultyNormal,
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 0),
    );
    const document = ChunkDocument(
      chunks: <LevelChunkDef>[malformed, duplicateId],
      baselineByChunkKey: <String, ChunkSourceBaseline>{},
      availableLevelIds: <String>['field'],
      activeLevelId: 'field',
      levelOptionSource: 'test',
      runtimeGridSnap: 16.0,
      runtimeChunkWidth: 600.0,
    );

    final codes = validateChunkDocument(document).map((i) => i.code).toSet();
    expect(codes, contains('malformed_chunk_key'));
    expect(codes, contains('duplicate_chunk_id'));
  });

  test('reports operation precondition failures through operationIssues', () {
    const chunk = LevelChunkDef(
      chunkKey: 'chunk_a',
      id: 'chunk_a',
      revision: 1,
      schemaVersion: 1,
      levelId: 'field',
      tileSize: 16,
      width: 600,
      height: 160,
      entrySocket: 'in',
      exitSocket: 'out',
      difficulty: chunkDifficultyNormal,
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 0),
    );
    const document = ChunkDocument(
      chunks: <LevelChunkDef>[chunk],
      baselineByChunkKey: <String, ChunkSourceBaseline>{},
      availableLevelIds: <String>['field'],
      activeLevelId: 'field',
      levelOptionSource: 'test',
      runtimeGridSnap: 16.0,
      runtimeChunkWidth: 600.0,
      operationIssues: <ValidationIssue>[
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'create_chunk_id_collision',
          message: 'Collision',
        ),
      ],
    );

    final codes = validateChunkDocument(document).map((i) => i.code).toSet();
    expect(codes, contains('create_chunk_id_collision'));
  });

  test('reports prefab placement identity and snap violations', () {
    const chunk = LevelChunkDef(
      chunkKey: 'chunk_prefab',
      id: 'chunk_prefab',
      revision: 1,
      schemaVersion: 1,
      levelId: 'field',
      tileSize: 16,
      width: 600,
      height: 160,
      entrySocket: 'in',
      exitSocket: 'out',
      difficulty: chunkDifficultyNormal,
      prefabs: <PlacedPrefabDef>[
        PlacedPrefabDef(prefabId: '', prefabKey: '', x: 10, y: 32),
      ],
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 0),
    );
    const document = ChunkDocument(
      chunks: <LevelChunkDef>[chunk],
      baselineByChunkKey: <String, ChunkSourceBaseline>{},
      availableLevelIds: <String>['field'],
      activeLevelId: 'field',
      levelOptionSource: 'test',
      runtimeGridSnap: 16.0,
      runtimeChunkWidth: 600.0,
    );

    final codes = validateChunkDocument(document).map((i) => i.code).toSet();
    expect(codes, contains('missing_prefab_ref'));
    expect(codes, contains('prefab_snap_violation'));
  });
}
