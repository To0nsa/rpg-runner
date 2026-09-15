import 'package:runner_core/collision/terrain/terrain_authoring_scheduler.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:test/test.dart';
import 'package:runner_core/collision/terrain/terrain_connection_schedule.dart';

void main() {
  test(
    'explicit sections validate exact pools and only composed boundaries',
    () {
      final chunks = [
        _chunk('grove_easy_a', ChunkPatternTier.easy, groupId: 'grove'),
        _chunk('grove_easy_b', ChunkPatternTier.easy, groupId: 'grove'),
        _chunk('grove_hard', ChunkPatternTier.hard, groupId: 'grove'),
        _chunk('ruins_normal', ChunkPatternTier.normal, groupId: 'ruins'),
      ];
      TerrainAuthoringSchedulerResult enumerate({
        int count = 2,
        ChunkPatternTier tier = ChunkPatternTier.easy,
      }) => _enumerate(
        chunks: chunks,
        levels: [
          TerrainAuthoringSchedulerLevel(
            levelId: 'forest',
            earlyPatternChunks: 300,
            easyPatternChunks: 0,
            normalPatternChunks: 0,
            assembly: TerrainAuthoringSchedulerAssembly(
              loopSegments: false,
              segments: [
                TerrainAuthoringSchedulerSegment(
                  segmentId: 'grove',
                  groupId: 'grove',
                  difficulty: tier,
                  minChunkCount: count,
                  maxChunkCount: count,
                  requireDistinctChunks: true,
                ),
                const TerrainAuthoringSchedulerSegment(
                  segmentId: 'ruins',
                  groupId: 'ruins',
                  difficulty: ChunkPatternTier.normal,
                  minChunkCount: 1,
                  maxChunkCount: 1,
                  requireDistinctChunks: true,
                ),
              ],
            ),
          ),
        ],
      );
      final result = enumerate();
      expect(result.issues, isEmpty);
      expect(
        result.transitions
            .map((t) => '${t.leftChunkKey}>${t.rightChunkKey}')
            .toSet(),
        {
          'grove_easy_a>grove_easy_b',
          'grove_easy_b>grove_easy_a',
          'grove_easy_a>ruins_normal',
          'grove_easy_b>ruins_normal',
          'ruins_normal>ruins_normal',
        },
      );
      expect(
        enumerate(count: 3).issues.map((i) => i.code),
        contains('terrain_connection_schedule_dead_end'),
      );
      expect(
        enumerate(tier: ChunkPatternTier.early).issues.map((i) => i.code),
        contains('terrain_connection_schedule_dead_end'),
      );
    },
  );

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

    final result = _enumerate(
      chunks: chunks,
      levels: <TerrainAuthoringSchedulerLevel>[level],
    );

    expect(result.issues, isEmpty);
    expect(
      result.transitions
          .map((t) => '${t.leftChunkKey}>${t.rightChunkKey}')
          .toSet(),
      {
        'normal>normal',
        'early_a>early_a',
        'early_a>early_b',
        'early_b>early_a',
        'early_b>early_b',
        'early_a>easy',
        'early_b>easy',
        'easy>normal',
      },
    );
    expect(result.schedules['forest']!.contractDigest, hasLength(64));
    expect(
      result.transitions.any(
        (transition) => transition.leftChunkKey == 'deprecated_hard',
      ),
      isFalse,
    );

    final reversed = _enumerate(
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
      final result = _enumerate(
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
    final result = _enumerate(
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
      }),
    );
    expect(result.transitions, isEmpty);
  });

  test('first chunk must belong to the first resolved scheduler pool', () {
    final chunks = <TerrainAuthoringSchedulerChunk>[
      _chunk('opening', ChunkPatternTier.early),
      _chunk('later', ChunkPatternTier.easy, groupId: 'ruins'),
      _chunk('retired', ChunkPatternTier.early, isActive: false),
    ];
    TerrainAuthoringSchedulerResult enumerate(String firstChunkKey) =>
        _enumerate(
          chunks: chunks,
          levels: <TerrainAuthoringSchedulerLevel>[
            TerrainAuthoringSchedulerLevel(
              levelId: 'forest',
              earlyPatternChunks: 1,
              easyPatternChunks: 1,
              normalPatternChunks: 0,
              firstChunkKey: firstChunkKey,
            ),
          ],
        );

    expect(enumerate('opening').issues, isEmpty);
    expect(
      enumerate('later').issues.single.code,
      'terrain_authoring_first_chunk_ineligible',
    );
    expect(
      enumerate('retired').issues.single.code,
      'terrain_authoring_first_chunk_inactive',
    );
    expect(
      enumerate('missing').issues.single.code,
      'terrain_authoring_first_chunk_missing',
    );
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

TerrainAuthoringSchedulerResult _enumerate({
  required Iterable<TerrainAuthoringSchedulerChunk> chunks,
  required Iterable<TerrainAuthoringSchedulerLevel> levels,
}) => enumerateTerrainAuthoringReachability(
  chunks: chunks,
  levels: levels,
  connections: {
    for (final chunk in chunks)
      chunk.chunkKey: const TerrainChunkConnection(
        entrance: 'flat',
        exit: 'flat',
      ),
  },
);
