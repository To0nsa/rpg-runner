import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/levels/level_assembly.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/util/deterministic_rng.dart' show mix32;

void main() {
  test('ChunkPatternListSource preserves deterministic selection behavior', () {
    const early = <ChunkPattern>[
      ChunkPattern(name: 'early-0'),
      ChunkPattern(name: 'early-1'),
    ];
    const easy = <ChunkPattern>[
      ChunkPattern(name: 'easy-0'),
      ChunkPattern(name: 'easy-1'),
      ChunkPattern(name: 'easy-2'),
    ];
    const normal = <ChunkPattern>[
      ChunkPattern(name: 'normal-0'),
      ChunkPattern(name: 'normal-1'),
      ChunkPattern(name: 'normal-2'),
    ];
    const hard = <ChunkPattern>[
      ChunkPattern(name: 'hard-0'),
      ChunkPattern(name: 'hard-1'),
    ];
    const source = ChunkPatternListSource(
      earlyPatterns: early,
      easyPatterns: easy,
      normalPatterns: normal,
      hardPatterns: hard,
    );
    const seed = 1337;
    const requestedTiers = <ChunkPatternTier>[
      ChunkPatternTier.early,
      ChunkPatternTier.easy,
      ChunkPatternTier.normal,
      ChunkPatternTier.hard,
    ];

    for (
      var chunkIndex = 0;
      chunkIndex < requestedTiers.length;
      chunkIndex += 1
    ) {
      final tier = requestedTiers[chunkIndex];
      final selected = source.patternFor(
        seed: seed,
        chunkIndex: chunkIndex,
        tier: tier,
      );

      final pool = switch (tier) {
        ChunkPatternTier.early => early,
        ChunkPatternTier.easy => easy,
        ChunkPatternTier.normal => normal,
        ChunkPatternTier.hard => hard,
      };
      final expectedIndex =
          mix32(seed ^ (chunkIndex * 0x9e3779b9) ^ 0x27d4eb2d) % pool.length;
      expect(selected.name, pool[expectedIndex].name);
    }
  });

  test(
    'ChunkPatternListSource falls back across tiers when requested pool is empty',
    () {
      const source = ChunkPatternListSource(
        easyPatterns: <ChunkPattern>[ChunkPattern(name: 'easy')],
        hardPatterns: <ChunkPattern>[ChunkPattern(name: 'hard')],
      );

      expect(
        source
            .patternFor(seed: 1, chunkIndex: 0, tier: ChunkPatternTier.early)
            .name,
        'easy',
      );
      expect(
        source
            .patternFor(seed: 1, chunkIndex: 1, tier: ChunkPatternTier.normal)
            .name,
        'easy',
      );
      expect(
        source
            .patternFor(seed: 1, chunkIndex: 2, tier: ChunkPatternTier.hard)
            .name,
        'hard',
      );
    },
  );

  test('ChunkPatternListSource throws when every tier is empty', () {
    const source = ChunkPatternListSource(easyPatterns: <ChunkPattern>[]);

    expect(
      () => source.patternFor(
        seed: 1,
        chunkIndex: 0,
        tier: ChunkPatternTier.easy,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains('tier=easy'),
        ),
      ),
    );
  });

  test('AssembledChunkPatternSource follows authored segment order', () {
    final source = AssembledChunkPatternSource(
      baseSource: const ChunkPatternListSource(
        easyPatterns: <ChunkPattern>[
          ChunkPattern(name: 'cemetery_a', assemblyGroupId: 'cemetery'),
          ChunkPattern(name: 'cemetery_b', assemblyGroupId: 'cemetery'),
          ChunkPattern(name: 'none_a', assemblyGroupId: 'none'),
          ChunkPattern(name: 'village_a', assemblyGroupId: 'village'),
          ChunkPattern(name: 'village_b', assemblyGroupId: 'village'),
        ],
      ),
      assembly: const LevelAssemblyDefinition(
        loopSegments: true,
        segments: <LevelAssemblySegment>[
          LevelAssemblySegment(
            segmentId: 'cemetery_run',
            groupId: 'cemetery',
            minChunkCount: 2,
            maxChunkCount: 2,
            requireDistinctChunks: true,
          ),
          LevelAssemblySegment(
            segmentId: 'none_run',
            groupId: 'none',
            minChunkCount: 1,
            maxChunkCount: 1,
            requireDistinctChunks: false,
          ),
          LevelAssemblySegment(
            segmentId: 'village_run',
            groupId: 'village',
            minChunkCount: 2,
            maxChunkCount: 2,
            requireDistinctChunks: true,
          ),
        ],
      ),
    );

    final selections = <ChunkPatternSelection>[
      for (var chunkIndex = 0; chunkIndex < 6; chunkIndex += 1)
        source.selectionFor(
          seed: 7,
          chunkIndex: chunkIndex,
          tier: ChunkPatternTier.easy,
        ),
    ];

    expect(
      selections.take(2).map((selection) => selection.pattern.name).toSet(),
      <String>{'cemetery_a', 'cemetery_b'},
    );
    expect(selections[2].pattern.name, 'none_a');
    expect(
      selections
          .skip(3)
          .take(2)
          .map((selection) => selection.pattern.name)
          .toSet(),
      <String>{'village_a', 'village_b'},
    );
    expect(selections[5].pattern.assemblyGroupId, 'cemetery');
  });

  test(
    'AssembledChunkPatternSource draws deterministic run lengths inside authored ranges',
    () {
      final source = AssembledChunkPatternSource(
        baseSource: const ChunkPatternListSource(
          easyPatterns: <ChunkPattern>[
            ChunkPattern(name: 'cemetery_a', assemblyGroupId: 'cemetery'),
            ChunkPattern(name: 'cemetery_b', assemblyGroupId: 'cemetery'),
            ChunkPattern(name: 'cemetery_c', assemblyGroupId: 'cemetery'),
            ChunkPattern(name: 'none_a', assemblyGroupId: 'none'),
            ChunkPattern(name: 'none_b', assemblyGroupId: 'none'),
            ChunkPattern(name: 'none_c', assemblyGroupId: 'none'),
            ChunkPattern(name: 'none_d', assemblyGroupId: 'none'),
          ],
        ),
        assembly: const LevelAssemblyDefinition(
          loopSegments: false,
          segments: <LevelAssemblySegment>[
            LevelAssemblySegment(
              segmentId: 'cemetery_run',
              groupId: 'cemetery',
              minChunkCount: 2,
              maxChunkCount: 4,
              requireDistinctChunks: false,
            ),
            LevelAssemblySegment(
              segmentId: 'none_run',
              groupId: 'none',
              minChunkCount: 4,
              maxChunkCount: 6,
              requireDistinctChunks: false,
            ),
          ],
        ),
      );

      final first = <String>[];
      final second = <String>[];
      for (var chunkIndex = 0; chunkIndex < 14; chunkIndex += 1) {
        first.add(
          source
              .selectionFor(
                seed: 99,
                chunkIndex: chunkIndex,
                tier: ChunkPatternTier.easy,
              )
              .pattern
              .assemblyGroupId,
        );
        second.add(
          source
              .selectionFor(
                seed: 99,
                chunkIndex: chunkIndex,
                tier: ChunkPatternTier.easy,
              )
              .pattern
              .assemblyGroupId,
        );
      }

      expect(second, first);
      final firstNoneIndex = first.indexOf('none');
      expect(firstNoneIndex, inInclusiveRange(2, 4));
      expect(first.take(firstNoneIndex), everyElement('cemetery'));
      expect(first.skip(firstNoneIndex), everyElement('none'));
    },
  );
}
