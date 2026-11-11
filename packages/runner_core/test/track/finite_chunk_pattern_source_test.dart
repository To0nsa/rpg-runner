import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/finite_chunk_pattern_source.dart';
import 'package:test/test.dart';

void main() {
  test('keeps exact order, tiers and repeated occurrences for every seed', () {
    final route = FiniteChunkPatternSource([
      _occurrence('grove_entrance', 'forest_grove_easy_001'),
      _occurrence('camp', 'forest_camp_normal_001', ChunkPatternTier.normal),
      _occurrence('grove_return', 'forest_grove_easy_001'),
    ]);
    for (final seed in [7, 42, 2026]) {
      for (final tier in ChunkPatternTier.values) {
        final choices = List.generate(
          route.length,
          (index) =>
              route.selectionFor(seed: seed, chunkIndex: index, tier: tier),
        );
        expect(choices.map((c) => c.pattern.chunkKey), [
          'forest_grove_easy_001',
          'forest_camp_normal_001',
          'forest_grove_easy_001',
        ]);
        expect(choices.map((c) => c.occurrenceId), [
          'grove_entrance',
          'camp',
          'grove_return',
        ]);
        expect(choices.map((c) => c.tier), [
          ChunkPatternTier.easy,
          ChunkPatternTier.normal,
          ChunkPatternTier.easy,
        ]);
        expect(choices.every((c) => c.assembly == null), isTrue);
      }
    }
    for (final index in [-1, 3, 100]) {
      expect(
        () => route.selectionFor(
          seed: 42,
          chunkIndex: index,
          tier: ChunkPatternTier.hard,
        ),
        throwsRangeError,
      );
    }
  });

  test('captures caller-owned lists before editing can change a route', () {
    final markers = <SpawnMarker>[
      const SpawnMarker(
        enemyId: EnemyId.derf,
        x: 150,
        chancePercent: 100,
        salt: 0,
      ),
    ];
    final occurrences = [
      FiniteChunkOccurrence(
        id: 'entrance',
        sourceLevelId: 'forest',
        pattern: ChunkPattern(
          name: 'grove',
          chunkKey: 'forest_grove_easy_001',
          spawnMarkers: markers,
        ),
        tier: ChunkPatternTier.easy,
      ),
    ];
    final route = FiniteChunkPatternSource(occurrences);
    markers.clear();
    occurrences.clear();
    expect(route.length, 1);
    expect(
      route.occurrences.single.pattern.spawnMarkers.single.enemyId,
      EnemyId.derf,
    );
    expect(() => route.occurrences.clear(), throwsUnsupportedError);
    expect(
      () => route.occurrences.single.pattern.spawnMarkers.clear(),
      throwsUnsupportedError,
    );
  });

  test(
    'rejects empty routes, duplicate occurrence IDs and missing identities',
    () {
      expect(() => FiniteChunkPatternSource([]), throwsArgumentError);
      expect(
        () => FiniteChunkPatternSource([
          _occurrence('same', 'first'),
          _occurrence('same', 'second'),
        ]),
        throwsArgumentError,
      );
      for (final value in ['', ' ', ' leading', 'trailing ']) {
        expect(() => _occurrence(value, 'chunk'), throwsArgumentError);
        expect(() => _occurrence('id', value), throwsArgumentError);
        expect(
          () => FiniteChunkOccurrence(
            id: 'id',
            sourceLevelId: value,
            pattern: const ChunkPattern(name: 'chunk', chunkKey: 'chunk'),
            tier: ChunkPatternTier.easy,
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => FiniteChunkOccurrence(
          id: 'id',
          sourceLevelId: 'forest',
          pattern: const ChunkPattern(name: 'chunk'),
          tier: ChunkPatternTier.easy,
        ),
        throwsArgumentError,
      );
    },
  );
}

FiniteChunkOccurrence _occurrence(
  String id,
  String key, [
  ChunkPatternTier tier = ChunkPatternTier.easy,
]) => FiniteChunkOccurrence(
  id: id,
  sourceLevelId: 'forest',
  pattern: ChunkPattern(name: key, chunkKey: key),
  tier: tier,
);
