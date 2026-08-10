import 'package:runner_core/collision/terrain/terrain_authoring_scheduler.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:test/test.dart';

void main() {
  test('tier reachability preserves the reviewed seam signature', () {
    final chunks = <TerrainAuthoringSchedulerChunk>[
      _chunk('early_a', ChunkPatternTier.early),
      _chunk('early_b', ChunkPatternTier.early),
      _chunk('easy', ChunkPatternTier.easy),
      _chunk('normal', ChunkPatternTier.normal),
      _chunk('deprecated_hard', ChunkPatternTier.hard, isActive: false),
    ];
    final level = TerrainAuthoringSchedulerLevel(
      levelId: 'forest',
      earlyPatternChunks: 2,
      easyPatternChunks: 1,
      normalPatternChunks: 0,
    );

    final result = enumerateTerrainAuthoringReachability(
      chunks: chunks,
      levels: <TerrainAuthoringSchedulerLevel>[level],
    );

    expect(result.issues, isEmpty);
    expect(result.signature.canonicalRecord, '''authoring-seams-v1
forest|steady-hard:tier=hard>hard|normal>normal
forest|tier=early:within-window|early_a>early_a
forest|tier=early:within-window|early_a>early_b
forest|tier=early:within-window|early_b>early_a
forest|tier=early:within-window|early_b>early_b
forest|tier=early>easy:boundary|early_a>easy
forest|tier=early>easy:boundary|early_b>easy
forest|tier=easy>hard:boundary|easy>normal''');
    expect(
      result.signature.digest,
      '9681ffb17f61812ec63f1522f9da99340fd1a3ba05b0103f7d8a5f0ffd76393b',
    );
    expect(
      result.transitions.any(
        (transition) => transition.leftChunkKey == 'deprecated_hard',
      ),
      isFalse,
    );

    final reversed = enumerateTerrainAuthoringReachability(
      chunks: chunks.reversed,
      levels: <TerrainAuthoringSchedulerLevel>[level],
    );
    expect(reversed.signature.digest, result.signature.digest);
    expect(
      reversed.transitions.map((transition) => transition.description),
      result.transitions.map((transition) => transition.description),
    );
  });

  test(
    'assembly reachability enforces distinct runs and directed boundaries',
    () {
      final result = enumerateTerrainAuthoringReachability(
        chunks: <TerrainAuthoringSchedulerChunk>[
          _chunk('a', ChunkPatternTier.normal, groupId: 'grove'),
          _chunk('b', ChunkPatternTier.normal, groupId: 'grove'),
          _chunk('c', ChunkPatternTier.normal, groupId: 'ruins'),
        ],
        levels: <TerrainAuthoringSchedulerLevel>[
          TerrainAuthoringSchedulerLevel(
            levelId: 'forest',
            earlyPatternChunks: 0,
            easyPatternChunks: 0,
            normalPatternChunks: 0,
            assembly: TerrainAuthoringSchedulerAssembly(
              loopSegments: true,
              segments: const <TerrainAuthoringSchedulerSegment>[
                TerrainAuthoringSchedulerSegment(
                  segmentId: 'grove_run',
                  groupId: 'grove',
                  minChunkCount: 2,
                  maxChunkCount: 2,
                  requireDistinctChunks: true,
                ),
                TerrainAuthoringSchedulerSegment(
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
      );

      expect(result.issues, isEmpty);
      expect(
        result.transitions
            .map(
              (transition) =>
                  '${transition.leftChunkKey}>${transition.rightChunkKey}',
            )
            .toSet(),
        <String>{'a>b', 'b>a', 'a>c', 'b>c', 'c>a', 'c>b'},
      );
    },
  );

  test('missing pools and excessive finite windows fail closed', () {
    final result = enumerateTerrainAuthoringReachability(
      chunks: <TerrainAuthoringSchedulerChunk>[
        _chunk('only', ChunkPatternTier.normal, groupId: 'grove'),
      ],
      levels: <TerrainAuthoringSchedulerLevel>[
        TerrainAuthoringSchedulerLevel(
          levelId: 'forest',
          earlyPatternChunks: maxTerrainAuthoringFiniteWindowChunks + 1,
          easyPatternChunks: 0,
          normalPatternChunks: 0,
          assembly: TerrainAuthoringSchedulerAssembly(
            loopSegments: false,
            segments: const <TerrainAuthoringSchedulerSegment>[
              TerrainAuthoringSchedulerSegment(
                segmentId: 'missing_run',
                groupId: 'missing',
                minChunkCount: 2,
                maxChunkCount: 2,
                requireDistinctChunks: true,
              ),
            ],
          ),
        ),
      ],
    );

    expect(
      result.issues.map((issue) => issue.code),
      containsAll(<String>{
        'terrain_authoring_scheduler_analysis_capacity_exceeded',
        'terrain_authoring_scheduler_pool_empty',
      }),
    );
    expect(result.transitions, isEmpty);
  });
}

TerrainAuthoringSchedulerChunk _chunk(
  String chunkKey,
  ChunkPatternTier tier, {
  String groupId = 'default',
  bool isActive = true,
}) => TerrainAuthoringSchedulerChunk(
  chunkKey: chunkKey,
  levelId: 'forest',
  tier: tier,
  assemblyGroupId: groupId,
  isActive: isActive,
);
