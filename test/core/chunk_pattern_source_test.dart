import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_pool.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/util/deterministic_rng.dart' show mix32;

void main() {
  test('ChunkPatternPoolSource preserves deterministic selection behavior', () {
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
    const source = ChunkPatternPoolSource(
      ChunkPatternPool(
        earlyPatterns: early,
        easyPatterns: easy,
        normalPatterns: normal,
        hardPatterns: hard,
      ),
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
    'ChunkPatternPoolSource falls back across tiers when requested pool is empty',
    () {
      const source = ChunkPatternPoolSource(
        ChunkPatternPool(
          easyPatterns: <ChunkPattern>[ChunkPattern(name: 'easy')],
          hardPatterns: <ChunkPattern>[ChunkPattern(name: 'hard')],
        ),
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

  test('ChunkPatternPoolSource throws when every tier is empty', () {
    const source = ChunkPatternPoolSource(
      ChunkPatternPool(easyPatterns: <ChunkPattern>[]),
    );

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
}
