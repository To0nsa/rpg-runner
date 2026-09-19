import 'package:runner_core/levels/level_assembly.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:test/test.dart';

void main() {
  final sections = [
    ('default', ChunkPatternTier.early),
    for (final tier in [
      ChunkPatternTier.easy,
      ChunkPatternTier.normal,
      ChunkPatternTier.hard,
    ])
      for (final group in ['grove', 'ruins', 'camp']) (group, tier),
  ];
  List<ChunkPattern> pool(ChunkPatternTier tier) => [
    for (final section in sections.where((s) => s.$2 == tier))
      for (var i = 0; i < 3; i++)
        ChunkPattern(
          name: '${section.$1}_${tier.name}_$i',
          chunkKey: '${section.$1}_${tier.name}_$i',
          assemblyGroupId: section.$1,
        ),
  ];
  AssembledChunkPatternSource source({bool loop = true}) =>
      AssembledChunkPatternSource(
        baseSource: ChunkPatternListSource(
          earlyPatterns: pool(ChunkPatternTier.early),
          easyPatterns: pool(ChunkPatternTier.easy),
          normalPatterns: pool(ChunkPatternTier.normal),
          hardPatterns: pool(ChunkPatternTier.hard),
        ),
        assembly: LevelAssemblyDefinition(
          loopSegments: loop,
          segments: [
            for (final (group, tier) in sections)
              LevelAssemblySegment(
                segmentId: '${group}_${tier.name}',
                groupId: group,
                difficulty: tier,
                minChunkCount: 3,
                maxChunkCount: 3,
                requireDistinctChunks: true,
              ),
          ],
        ),
      );

  test(
    'composes all difficulty passes with three unique chunks per section',
    () {
      for (final seed in [1, 7, 99]) {
        final runtime = source();
        final keys = <String>[];
        for (
          var occurrence = 0;
          occurrence < sections.length * 2;
          occurrence++
        ) {
          final section = sections[occurrence % sections.length];
          final selected = [
            for (var offset = 0; offset < 3; offset++)
              runtime.selectionFor(
                seed: seed,
                chunkIndex: occurrence * 3 + offset,
                // Deliberately crosses unrelated global difficulty boundaries.
                tier: ChunkPatternTier.values[offset],
              ),
          ];
          expect(selected.map((s) => s.pattern.chunkKey).toSet(), hasLength(3));
          expect(
            selected.map((s) => s.pattern.assemblyGroupId),
            everyElement(section.$1),
          );
          expect(
            selected.map((s) => s.assembly!.difficulty),
            everyElement(section.$2),
          );
          expect(selected.map((s) => s.tier), everyElement(section.$2));
          expect(
            selected.map((s) => s.pattern.name),
            everyElement(startsWith('${section.$1}_${section.$2.name}_')),
          );
          keys.addAll(selected.map((s) => s.pattern.chunkKey!));
        }
        final replay = source();
        // Querying backwards must yield the same choices as streaming forwards.
        for (var i = keys.length - 1; i >= 0; i--) {
          expect(
            replay
                .patternFor(
                  seed: seed,
                  chunkIndex: i,
                  tier: ChunkPatternTier.hard,
                )
                .chunkKey,
            keys[i],
          );
        }
      }
    },
  );

  test(
    'continuing the final section retains its difficulty and resets uniqueness',
    () {
      final runtime = source(loop: false);
      for (var start = 30; start < 39; start += 3) {
        final selected = [
          for (var i = start; i < start + 3; i++)
            runtime.selectionFor(
              seed: 7,
              chunkIndex: i,
              tier: ChunkPatternTier.early,
            ),
        ];
        expect(selected.map((s) => s.pattern.chunkKey).toSet(), hasLength(3));
        expect(
          selected.map((s) => s.assembly!.segmentId),
          everyElement('camp_hard'),
        );
        expect(
          selected.map((s) => s.assembly!.repeatsFinalSegment),
          everyElement(isTrue),
        );
      }
    },
  );

  test(
    'explicit sections reject missing and insufficient pools without fallback',
    () {
      for (final difficulty in [ChunkPatternTier.easy, ChunkPatternTier.hard]) {
        final runtime = AssembledChunkPatternSource(
          baseSource: const ChunkPatternListSource(
            easyPatterns: [
              ChunkPattern(name: 'only_easy', assemblyGroupId: 'grove'),
            ],
            normalPatterns: [
              ChunkPattern(name: 'normal_a', assemblyGroupId: 'grove'),
              ChunkPattern(name: 'normal_b', assemblyGroupId: 'grove'),
              ChunkPattern(name: 'normal_c', assemblyGroupId: 'grove'),
            ],
          ),
          assembly: LevelAssemblyDefinition(
            segments: [
              LevelAssemblySegment(
                segmentId: 'grove',
                groupId: 'grove',
                difficulty: difficulty,
                minChunkCount: 3,
                maxChunkCount: 3,
                requireDistinctChunks: true,
              ),
            ],
          ),
        );
        expect(
          () => runtime.patternFor(
            seed: 7,
            chunkIndex: 0,
            tier: ChunkPatternTier.normal,
          ),
          throwsStateError,
        );
      }
    },
  );
}
