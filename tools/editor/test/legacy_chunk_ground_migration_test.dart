import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_store.dart';
import 'package:runner_editor/src/chunks/migration/legacy_chunk_ground_migration.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  test('flat ground without gaps becomes one finite solid polygon', () {
    final result = LegacyChunkGroundMigration.plan(
      chunk: _chunk(),
      sourcePath: 'test/full_ground',
    );

    expect(result.canMigrate, isTrue);
    expect(result.occupiedAreaHalfPixelSquared, BigInt.from(110400));
    expect(result.shapes.map((shape) => shape.shapeId), <String>['ground_001']);
    expect(_vertices(result.shapes.single), const <(int, int)>[
      (0, 448),
      (1200, 448),
      (1200, 540),
      (0, 540),
    ]);
  });

  test('pit gap becomes missing coverage between stable ground shapes', () {
    final result = LegacyChunkGroundMigration.plan(
      chunk: _chunk(
        gaps: const <GroundGapDef>[
          GroundGapDef(gapId: 'pit_001', x: 32, width: 64),
        ],
      ),
      sourcePath: 'test/pit',
    );

    expect(result.canMigrate, isTrue);
    expect(result.shapes.map((shape) => shape.shapeId), <String>[
      'ground_001',
      'ground_002',
    ]);
    expect(_vertices(result.shapes.first), const <(int, int)>[
      (0, 448),
      (64, 448),
      (64, 540),
      (0, 540),
    ]);
    expect(_vertices(result.shapes.last), const <(int, int)>[
      (192, 448),
      (1200, 448),
      (1200, 540),
      (192, 540),
    ]);
  });

  test('multiple and adjacent gaps retain only positive solid spans', () {
    final result = LegacyChunkGroundMigration.plan(
      chunk: _chunk(
        gaps: const <GroundGapDef>[
          GroundGapDef(gapId: 'pit_004', x: 300, width: 100),
          GroundGapDef(gapId: 'pit_002', x: 150, width: 50),
          GroundGapDef(gapId: 'pit_001', x: 100, width: 50),
        ],
      ),
      sourcePath: 'test/multiple_pits',
    );

    expect(result.canMigrate, isTrue);
    expect(result.shapes, hasLength(3));
    expect(
      result.shapes.map(
        (shape) => (
          shape.shapeId,
          shape.vertices.first.xHalfPixels,
          shape.vertices[1].xHalfPixels,
        ),
      ),
      <(String, int, int)>[
        ('ground_001', 0, 200),
        ('ground_002', 400, 600),
        ('ground_003', 800, 1200),
      ],
    );
  });

  test('full-width pit produces an empty valid ground-shape list', () {
    final result = LegacyChunkGroundMigration.plan(
      chunk: _chunk(
        gaps: const <GroundGapDef>[
          GroundGapDef(gapId: 'pit_all', x: 0, width: 600),
        ],
      ),
      sourcePath: 'test/no_ground',
    );

    expect(result.canMigrate, isTrue);
    expect(result.shapes, isEmpty);
    expect(result.occupiedAreaHalfPixelSquared, BigInt.zero);
  });

  test('invalid legacy ground inputs produce sorted blockers', () {
    final result = LegacyChunkGroundMigration.plan(
      chunk: _chunk(
        width: 0,
        height: 0,
        topY: 1,
        groundKind: 'curve',
        gaps: const <GroundGapDef>[
          GroundGapDef(gapId: 'same', x: -1, width: 0, type: 'lava'),
          GroundGapDef(gapId: 'same', x: 0, width: 4),
        ],
      ),
      sourcePath: 'test/invalid',
    );

    expect(result.canMigrate, isFalse);
    expect(result.shapes, isEmpty);
    expect(result.issues.map((issue) => issue.code), <String>[
      'legacy_chunk_dimensions',
      'legacy_ground_gap_bounds',
      'legacy_ground_gap_type',
      'legacy_ground_profile_kind',
      'legacy_ground_top_bounds',
      'legacy_ground_gap_bounds',
      'legacy_ground_gap_duplicate_id',
    ]);
  });

  test('overlapping gaps block while touching gaps remain exact', () {
    final result = LegacyChunkGroundMigration.plan(
      chunk: _chunk(
        gaps: const <GroundGapDef>[
          GroundGapDef(gapId: 'pit_001', x: 100, width: 100),
          GroundGapDef(gapId: 'pit_002', x: 150, width: 100),
        ],
      ),
      sourcePath: 'test/overlap',
    );

    expect(result.canMigrate, isFalse);
    expect(result.issues.map((issue) => issue.code), <String>[
      'legacy_ground_gap_overlap',
    ]);
  });

  test('nested gap cannot hide a later overlap with the outer gap', () {
    final result = LegacyChunkGroundMigration.plan(
      chunk: _chunk(
        gaps: const <GroundGapDef>[
          GroundGapDef(gapId: 'pit_outer', x: 100, width: 100),
          GroundGapDef(gapId: 'pit_nested', x: 150, width: 20),
          GroundGapDef(gapId: 'pit_later', x: 190, width: 20),
        ],
      ),
      sourcePath: 'test/nested_overlap',
    );

    expect(result.canMigrate, isFalse);
    expect(result.issues.map((issue) => issue.code), <String>[
      'legacy_ground_gap_overlap',
      'legacy_ground_gap_overlap',
    ]);
  });

  test('repository audit migrates eight chunks into nine shapes', () async {
    final workspace = EditorWorkspace(rootPath: _repoRootPath());
    final document = await const ChunkStore().load(workspace);
    var shapeCount = 0;
    final blockers = <String>[];
    for (final chunk in document.chunks) {
      final sourcePath =
          document.baselineByChunkKey[chunk.chunkKey]!.sourcePath;
      final result = LegacyChunkGroundMigration.plan(
        chunk: chunk,
        sourcePath: sourcePath,
      );
      shapeCount += result.shapes.length;
      blockers.addAll(
        result.issues.map(
          (issue) => '${chunk.chunkKey}: ${issue.code} ${issue.message}',
        ),
      );
    }

    expect(document.chunks, hasLength(8));
    expect(shapeCount, 9);
    expect(blockers, isEmpty);
  });
}

LevelChunkDef _chunk({
  int width = 600,
  int height = 270,
  int topY = 224,
  String groundKind = groundProfileKindFlat,
  List<GroundGapDef> gaps = const <GroundGapDef>[],
}) => LevelChunkDef(
  chunkKey: 'test_chunk',
  id: 'test_chunk',
  revision: 1,
  levelId: 'forest',
  tileSize: 16,
  width: width,
  height: height,
  difficulty: chunkDifficultyEarly,
  groundProfile: GroundProfileDef(kind: groundKind, topY: topY),
  groundGaps: gaps,
);

List<(int, int)> _vertices(TerrainSourceShapeDef shape) => shape.vertices
    .map((vertex) => (vertex.xHalfPixels, vertex.yHalfPixels))
    .toList(growable: false);

String _repoRootPath() {
  final cwd = p.normalize(Directory.current.path);
  if (p.basename(cwd).toLowerCase() == 'editor' &&
      p.basename(p.dirname(cwd)).toLowerCase() == 'tools') {
    return p.normalize(p.join(cwd, '..', '..'));
  }
  return cwd;
}
