import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/levels/level_assembly.dart' as core_level;
import 'package:runner_core/track/chunk_pattern.dart' as core_track;
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_v2_collision_expansion.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/chunks/chunk_v2_seam_analysis.dart';
import 'package:runner_editor/src/chunks/chunk_v2_models.dart';
import 'package:runner_editor/src/chunks/chunk_v2_validation.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  group('compiled boundary signatures', () {
    test('accepts matching slope endpoints and explicit empty boundaries', () {
      final left = _signature(
        chunkKey: 'left',
        side: ChunkV2BoundarySide.right,
        geometry: _geometry(
          chunkKey: 'left',
          vertices: const <(double, double)>[
            (0, 50),
            (100, 40),
            (100, 100),
            (0, 100),
          ],
        ),
      );
      final right = _signature(
        chunkKey: 'right',
        side: ChunkV2BoundarySide.left,
        geometry: _geometry(
          chunkKey: 'right',
          vertices: const <(double, double)>[
            (0, 40),
            (100, 60),
            (100, 100),
            (0, 100),
          ],
        ),
      );

      final comparison = compareChunkV2Boundaries(left: left, right: right);

      expect(comparison.isCompatible, isTrue);
      expect(
        left.coverageIntervals.single.canonicalRecord,
        'solid:40960..102400',
      );
      expect(left.continuationVertices.map((item) => item.yTicks), <int>[
        40960,
        102400,
      ]);

      final openLeft = _signature(
        chunkKey: 'open_left',
        side: ChunkV2BoundarySide.right,
        geometry: _emptyGeometry(),
      );
      final openRight = _signature(
        chunkKey: 'open_right',
        side: ChunkV2BoundarySide.left,
        geometry: _emptyGeometry(),
      );
      expect(openLeft.isEmpty, isTrue);
      expect(openLeft.canonicalRecord, contains('empty'));
      expect(
        compareChunkV2Boundaries(left: openLeft, right: openRight).isCompatible,
        isTrue,
      );
    });

    test('reports exact coverage and continuation mismatch ticks', () {
      final left = _signature(
        chunkKey: 'left',
        side: ChunkV2BoundarySide.right,
        geometry: _flatGeometry(chunkKey: 'left', topY: 40),
      );
      final right = _signature(
        chunkKey: 'right',
        side: ChunkV2BoundarySide.left,
        geometry: _flatGeometry(chunkKey: 'right', topY: 48),
      );

      final comparison = compareChunkV2Boundaries(left: left, right: right);

      expect(comparison.isCompatible, isFalse);
      expect(comparison.leftOnlyIntervals, hasLength(1));
      expect(comparison.rightOnlyIntervals, hasLength(1));
      expect(comparison.leftOnlyVertices, hasLength(1));
      expect(comparison.rightOnlyVertices, hasLength(1));
      expect(comparison.mismatchYTicks, <int>[40960, 49152, 102400]);
    });

    test('surface mode blocks while material remains advisory evidence', () {
      final left = _signature(
        chunkKey: 'left',
        side: ChunkV2BoundarySide.right,
        geometry: _flatGeometry(
          chunkKey: 'left',
          topY: 40,
          surfaceKind: 'earth',
          materialKey: 'grass_a',
        ),
      );
      final rightMaterial = _signature(
        chunkKey: 'right_material',
        side: ChunkV2BoundarySide.left,
        geometry: _flatGeometry(
          chunkKey: 'right_material',
          topY: 40,
          surfaceKind: 'earth',
          materialKey: 'grass_b',
        ),
      );
      final rightSurface = _signature(
        chunkKey: 'right_surface',
        side: ChunkV2BoundarySide.left,
        geometry: _flatGeometry(
          chunkKey: 'right_surface',
          topY: 40,
          surfaceKind: 'stone',
          materialKey: 'grass_a',
        ),
      );
      final rightMode = _signature(
        chunkKey: 'right_mode',
        side: ChunkV2BoundarySide.left,
        geometry: _flatGeometry(
          chunkKey: 'right_mode',
          topY: 40,
          surfaceKind: 'earth',
          materialKey: 'grass_a',
          collisionMode: TerrainCollisionMode.oneWay,
        ),
      );

      final materialComparison = compareChunkV2Boundaries(
        left: left,
        right: rightMaterial,
      );
      expect(materialComparison.isCompatible, isTrue);
      expect(materialComparison.materialMismatchVertices, hasLength(2));

      final surfaceComparison = compareChunkV2Boundaries(
        left: left,
        right: rightSurface,
      );
      expect(surfaceComparison.isCompatible, isFalse);
      expect(surfaceComparison.leftOnlyVertices, hasLength(2));
      expect(surfaceComparison.rightOnlyVertices, hasLength(2));

      final modeComparison = compareChunkV2Boundaries(
        left: left,
        right: rightMode,
      );
      expect(modeComparison.isCompatible, isFalse);
      expect(modeComparison.leftOnlyIntervals, hasLength(1));
      expect(modeComparison.rightOnlyIntervals, isEmpty);
    });

    test('canonical result does not depend on compiled input order', () {
      final first = const TerrainCompiler().compile(<TerrainPolygonInput>[
        _input('lower', const <(double, double)>[
          (0, 70),
          (100, 70),
          (100, 100),
          (0, 100),
        ]),
        _input('upper', const <(double, double)>[
          (0, 20),
          (100, 20),
          (100, 50),
          (0, 50),
        ]),
      ], geometryVersion: 1);
      final second = const TerrainCompiler().compile(<TerrainPolygonInput>[
        _input('upper', const <(double, double)>[
          (0, 20),
          (100, 20),
          (100, 50),
          (0, 50),
        ]),
        _input('lower', const <(double, double)>[
          (0, 70),
          (100, 70),
          (100, 100),
          (0, 100),
        ]),
      ], geometryVersion: 1);

      final a = _signature(
        chunkKey: 'chunk',
        side: ChunkV2BoundarySide.right,
        geometry: first,
      );
      final b = _signature(
        chunkKey: 'chunk',
        side: ChunkV2BoundarySide.right,
        geometry: second,
      );

      expect(a.canonicalRecord, b.canonicalRecord);
      expect(a.digest, b.digest);
    });
  });

  group('reachable scheduler transitions', () {
    test(
      'enumerates tier fallback, tier boundaries, both orders, and hard tail',
      () {
        final chunks = <ChunkV2FileData>[
          _chunk('early_a', difficulty: chunkDifficultyEarly),
          _chunk('early_b', difficulty: chunkDifficultyEarly),
          _chunk('easy', difficulty: chunkDifficultyEasy),
          _chunk('normal', difficulty: chunkDifficultyNormal),
          _chunk(
            'deprecated_hard',
            difficulty: chunkDifficultyHard,
            status: chunkStatusDeprecated,
          ),
        ];
        final analysis = analyzeChunkV2Seams(
          chunks: chunks,
          levels: <LevelDef>[_level(early: 2, easy: 1, normal: 0)],
          collisionExpansionByChunkKey: _flatExpansions(chunks),
        );

        expect(analysis.issues, isEmpty);
        expect(
          analysis.transitions.map((item) => item.canonicalRecord),
          containsAll(<String>[
            'forest|tier=early:within-window|early_a>early_b',
            'forest|tier=early:within-window|early_b>early_a',
            'forest|tier=early>easy:boundary|early_a>easy',
            'forest|tier=easy>hard:boundary|easy>normal',
            'forest|steady-hard:tier=hard>hard|normal>normal',
          ]),
        );
        expect(
          analysis.transitions.any(
            (item) => item.leftChunkKey == 'deprecated_hard',
          ),
          isFalse,
        );
        expect(analysis.reachableAdjacencyRecord, '''authoring-seams-v1
forest|steady-hard:tier=hard>hard|normal>normal
forest|tier=early:within-window|early_a>early_a
forest|tier=early:within-window|early_a>early_b
forest|tier=early:within-window|early_b>early_a
forest|tier=early:within-window|early_b>early_b
forest|tier=early>easy:boundary|early_a>easy
forest|tier=early>easy:boundary|early_b>easy
forest|tier=easy>hard:boundary|easy>normal''');
        expect(
          analysis.reachableAdjacencyDigest,
          '9681ffb17f61812ec63f1522f9da99340fd1a3ba05b0103f7d8a5f0ffd76393b',
        );
        final golden =
            jsonDecode(_sharedSeamGolden().readAsStringSync())
                as Map<String, Object?>;
        expect(
          analysis.reachableAdjacencyRecord,
          golden['reachableAdjacencyRecord'],
        );
        expect(
          analysis.reachableAdjacencyDigest,
          golden['reachableAdjacencyDigest'],
        );
        expect(
          analysis.transitions.map((item) => item.canonicalRecord),
          (golden['transitions']! as List<Object?>).map((item) {
            final value = item! as Map<String, Object?>;
            return '${value['levelId']}|${value['transitionId']}|'
                '${value['leftChunkKey']}>${value['rightChunkKey']}';
          }),
        );

        final reversed = analyzeChunkV2Seams(
          chunks: chunks.reversed,
          levels: <LevelDef>[_level(early: 2, easy: 1, normal: 0)],
          collisionExpansionByChunkKey: _flatExpansions(chunks.reversed),
        );
        expect(
          reversed.reachableAdjacencyRecord,
          analysis.reachableAdjacencyRecord,
        );
        expect(
          reversed.reachableAdjacencyDigest,
          analysis.reachableAdjacencyDigest,
        );
      },
    );

    test('enumerates distinct within-runs and directed between-run pairs', () {
      final chunks = <ChunkV2FileData>[
        _chunk('a', groupId: 'grove'),
        _chunk('b', groupId: 'grove'),
        _chunk('c', groupId: 'ruins'),
      ];
      final analysis = analyzeChunkV2Seams(
        chunks: chunks,
        levels: <LevelDef>[
          _level(
            early: 0,
            easy: 0,
            normal: 0,
            assembly: const LevelAssemblyDef(
              loopSegments: true,
              segments: <LevelAssemblySegmentDef>[
                LevelAssemblySegmentDef(
                  segmentId: 'grove_run',
                  groupId: 'grove',
                  minChunkCount: 2,
                  maxChunkCount: 2,
                  requireDistinctChunks: true,
                ),
                LevelAssemblySegmentDef(
                  segmentId: 'ruins_run',
                  groupId: 'ruins',
                  minChunkCount: 1,
                  maxChunkCount: 1,
                  requireDistinctChunks: false,
                ),
              ],
            ),
          ),
        ],
        collisionExpansionByChunkKey: _flatExpansions(chunks),
      );

      expect(analysis.issues, isEmpty);
      final pairs = analysis.transitions
          .map((item) => '${item.leftChunkKey}>${item.rightChunkKey}')
          .toSet();
      expect(pairs, <String>{'a>b', 'b>a', 'a>c', 'b>c', 'c>a', 'c>b'});
      expect(pairs, isNot(contains('a>a')));
      expect(pairs, isNot(contains('b>b')));
    });

    test('contains every transition observed from the Core scheduler', () {
      final chunks = <ChunkV2FileData>[
        _chunk('a', groupId: 'grove'),
        _chunk('b', groupId: 'grove'),
        _chunk('c', groupId: 'ruins'),
      ];
      const assembly = LevelAssemblyDef(
        loopSegments: true,
        segments: <LevelAssemblySegmentDef>[
          LevelAssemblySegmentDef(
            segmentId: 'grove_run',
            groupId: 'grove',
            minChunkCount: 1,
            maxChunkCount: 2,
            requireDistinctChunks: true,
          ),
          LevelAssemblySegmentDef(
            segmentId: 'ruins_run',
            groupId: 'ruins',
            minChunkCount: 1,
            maxChunkCount: 1,
            requireDistinctChunks: false,
          ),
        ],
      );
      final analysis = analyzeChunkV2Seams(
        chunks: chunks,
        levels: <LevelDef>[
          _level(early: 0, easy: 0, normal: 0, assembly: assembly),
        ],
        collisionExpansionByChunkKey: _flatExpansions(chunks),
      );
      final structurallyReachable = analysis.transitions
          .map((item) => '${item.leftChunkKey}>${item.rightChunkKey}')
          .toSet();
      final runtime = AssembledChunkPatternSource(
        baseSource: const ChunkPatternListSource(
          easyPatterns: <core_track.ChunkPattern>[],
          normalPatterns: <core_track.ChunkPattern>[
            core_track.ChunkPattern(
              name: 'a',
              chunkKey: 'a',
              assemblyGroupId: 'grove',
            ),
            core_track.ChunkPattern(
              name: 'b',
              chunkKey: 'b',
              assemblyGroupId: 'grove',
            ),
            core_track.ChunkPattern(
              name: 'c',
              chunkKey: 'c',
              assemblyGroupId: 'ruins',
            ),
          ],
        ),
        assembly: const core_level.LevelAssemblyDefinition(
          loopSegments: true,
          segments: <core_level.LevelAssemblySegment>[
            core_level.LevelAssemblySegment(
              segmentId: 'grove_run',
              groupId: 'grove',
              minChunkCount: 1,
              maxChunkCount: 2,
              requireDistinctChunks: true,
            ),
            core_level.LevelAssemblySegment(
              segmentId: 'ruins_run',
              groupId: 'ruins',
              minChunkCount: 1,
              maxChunkCount: 1,
              requireDistinctChunks: false,
            ),
          ],
        ),
      );

      for (var seed = 0; seed < 128; seed += 1) {
        final selected = <String>[];
        for (var index = 0; index < 32; index += 1) {
          selected.add(
            runtime
                .patternFor(
                  seed: seed,
                  chunkIndex: index,
                  tier: ChunkPatternTier.hard,
                )
                .chunkKey!,
          );
        }
        for (var index = 0; index < selected.length - 1; index += 1) {
          expect(
            structurallyReachable,
            contains('${selected[index]}>${selected[index + 1]}'),
            reason: 'seed=$seed index=$index',
          );
        }
      }
    });

    test('blocks every reachable pair with mismatched compiled boundaries', () {
      final chunks = <ChunkV2FileData>[
        _chunk('low', difficulty: chunkDifficultyEarly),
        _chunk('high', difficulty: chunkDifficultyEasy),
      ];
      final analysis = analyzeChunkV2Seams(
        chunks: chunks,
        levels: <LevelDef>[_level(early: 1, easy: 0, normal: 0)],
        collisionExpansionByChunkKey: <String, ChunkV2CollisionExpansionResult>{
          'low': _expansionResult('low', topY: 40),
          'high': _expansionResult('high', topY: 48),
        },
        sourcePathByChunkKey: const <String, String>{'low': 'chunks/low.json'},
      );

      final mismatch = analysis.issues.singleWhere(
        (issue) => issue.code == 'chunk_v2_reachable_seam_mismatch',
      );
      expect(mismatch.sourcePath, 'chunks/low.json');
      expect(mismatch.message, contains('forest'));
      expect(mismatch.message, contains('low[right] -> high[left]'));
      expect(mismatch.message, contains('40'));
      expect(mismatch.message, contains('48'));
      expect(mismatch.message, contains('Expected/right'));
      expect(mismatch.message, contains('actual/left'));
    });

    test('global current validation blocks a reachable mismatch', () {
      final low = _chunk(
        'low',
        difficulty: chunkDifficultyEarly,
        collisionShapes: <TerrainSourceShapeDef>[_sourceGround('ground', 40)],
      );
      final high = _chunk(
        'high',
        difficulty: chunkDifficultyEasy,
        collisionShapes: <TerrainSourceShapeDef>[_sourceGround('ground', 48)],
      );
      final document = ChunkV2Document(
        chunks: <ChunkV2FileData>[low, high],
        sourcePathByChunkKey: const <String, String>{
          'low': 'chunks/low.json',
          'high': 'chunks/high.json',
        },
        baselineContentsByChunkKey: const <String, String>{
          'low': '{}',
          'high': '{}',
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
        levels: <LevelDef>[_level(early: 1, easy: 0, normal: 0)],
        availableLevelIds: const <String>['forest'],
        activeLevelId: 'forest',
      );

      final issues = validateChunkV2Document(document);

      expect(
        issues.where(
          (issue) => issue.code == 'chunk_v2_reachable_seam_mismatch',
        ),
        hasLength(1),
      );
    });

    test('bounds pathological assembled finite windows instead of hanging', () {
      final chunks = <ChunkV2FileData>[_chunk('only')];
      final analysis = analyzeChunkV2Seams(
        chunks: chunks,
        levels: <LevelDef>[
          _level(
            early: 257,
            easy: 0,
            normal: 0,
            assembly: const LevelAssemblyDef(
              segments: <LevelAssemblySegmentDef>[
                LevelAssemblySegmentDef(
                  segmentId: 'default_run',
                  groupId: 'default',
                  minChunkCount: 1,
                  maxChunkCount: 1,
                  requireDistinctChunks: false,
                ),
              ],
            ),
          ),
        ],
        collisionExpansionByChunkKey: _flatExpansions(chunks),
      );

      expect(
        analysis.issues.map((issue) => issue.code),
        contains('chunk_v2_scheduler_analysis_capacity_exceeded'),
      );
      expect(
        analysis.transitions.map((item) => item.transitionId),
        contains('steady-hard:segment=default_run>default_run:between-runs'),
      );
    });
  });
}

File _sharedSeamGolden() {
  final candidates = <File>[
    File('../../test/fixtures/polygon_terrain_generator/reachable_seams.json'),
    File('test/fixtures/polygon_terrain_generator/reachable_seams.json'),
  ];
  return candidates.firstWhere(
    (candidate) => candidate.existsSync(),
    orElse: () => throw StateError(
      'Cannot locate the shared polygon terrain seam golden from '
      '${Directory.current.path}.',
    ),
  );
}

ChunkV2BoundarySignature _signature({
  required String chunkKey,
  required ChunkV2BoundarySide side,
  required TerrainGeometry geometry,
}) => buildChunkV2BoundarySignature(
  chunkKey: chunkKey,
  chunkWidth: 100,
  geometry: geometry,
  side: side,
);

TerrainGeometry _emptyGeometry() =>
    TerrainGeometry(version: 1, polygons: const [], edges: const []);

TerrainGeometry _flatGeometry({
  required String chunkKey,
  required double topY,
  String? surfaceKind,
  String? materialKey,
  TerrainCollisionMode collisionMode = TerrainCollisionMode.solid,
}) => _geometry(
  chunkKey: chunkKey,
  vertices: <(double, double)>[(0, topY), (100, topY), (100, 100), (0, 100)],
  surfaceKind: surfaceKind,
  materialKey: materialKey,
  collisionMode: collisionMode,
);

TerrainGeometry _geometry({
  required String chunkKey,
  required List<(double, double)> vertices,
  String? surfaceKind,
  String? materialKey,
  TerrainCollisionMode collisionMode = TerrainCollisionMode.solid,
}) => const TerrainCompiler().compile(<TerrainPolygonInput>[
  TerrainPolygonInput.fromWorld(
    sourcePath: 'chunks/$chunkKey.json',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: chunkKey,
      shapeId: 'ground',
    ),
    vertices: vertices,
    surfaceKind: surfaceKind,
    materialKey: materialKey,
    collisionMode: collisionMode,
  ),
], geometryVersion: 1);

TerrainPolygonInput _input(String shapeId, List<(double, double)> vertices) =>
    TerrainPolygonInput.fromWorld(
      sourcePath: 'chunks/chunk.json#$shapeId',
      identity: TerrainSourceIdentity(
        chunkIndex: 0,
        chunkKey: 'chunk',
        shapeId: shapeId,
      ),
      vertices: vertices,
    );

ChunkV2FileData _chunk(
  String chunkKey, {
  String difficulty = chunkDifficultyNormal,
  String groupId = defaultChunkAssemblyGroupId,
  String status = chunkStatusActive,
  Iterable<TerrainSourceShapeDef> collisionShapes = const [],
}) => ChunkV2FileData(
  chunkKey: chunkKey,
  id: chunkKey,
  revision: 1,
  status: status,
  levelId: 'forest',
  tileSize: 16,
  width: 100,
  height: 100,
  difficulty: difficulty,
  assemblyGroupId: groupId,
  tags: const <String>[],
  tileLayers: const <TileLayerDef>[],
  prefabs: const <PlacedPrefabDef>[],
  markers: const <PlacedMarkerDef>[],
  groundBandZIndex: 0,
  collisionShapes: collisionShapes,
);

TerrainSourceShapeDef _sourceGround(String shapeId, int topY) =>
    TerrainSourceShapeDef(
      shapeId: shapeId,
      vertices: <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: topY * 2),
        TerrainSourceVertexDef(xHalfPixels: 200, yHalfPixels: topY * 2),
        const TerrainSourceVertexDef(xHalfPixels: 200, yHalfPixels: 200),
        const TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 200),
      ],
    );

LevelDef _level({
  required int early,
  required int easy,
  required int normal,
  LevelAssemblyDef? assembly,
}) => LevelDef(
  levelId: 'forest',
  revision: 1,
  displayName: 'Forest',
  visualThemeId: 'forest',
  chunkThemeGroups: const <String>['default', 'grove', 'ruins'],
  cameraCenterY: 50,
  groundTopY: 40,
  earlyPatternChunks: early,
  easyPatternChunks: easy,
  normalPatternChunks: normal,
  noEnemyChunks: 0,
  enumOrdinal: 1,
  status: levelStatusActive,
  assembly: assembly,
);

Map<String, ChunkV2CollisionExpansionResult> _flatExpansions(
  Iterable<ChunkV2FileData> chunks,
) => <String, ChunkV2CollisionExpansionResult>{
  for (final chunk in chunks)
    if (chunk.status == chunkStatusActive)
      chunk.chunkKey: _expansionResult(chunk.chunkKey, topY: 40),
};

ChunkV2CollisionExpansionResult _expansionResult(
  String chunkKey, {
  required double topY,
}) => ChunkV2CollisionExpansionResult(
  expansion: ChunkV2CollisionExpansion(
    chunkKey: chunkKey,
    geometry: _flatGeometry(chunkKey: chunkKey, topY: topY),
    directShapeCount: 1,
    expandedPrefabShapes: const [],
  ),
  issues: const [],
);
