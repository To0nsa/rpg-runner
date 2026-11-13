import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/finite_chunk_pattern_source.dart';
import 'package:test/test.dart';

void main() {
  test(
    'keeps exact order, tiers and repeated mission chunks for every seed',
    () {
      final route = FiniteChunkPatternSource([
        _missionChunk('grove_entrance', 'forest_grove_easy_001'),
        _missionChunk(
          'camp',
          'forest_camp_normal_001',
          ChunkPatternTier.normal,
        ),
        _missionChunk('grove_return', 'forest_grove_easy_001'),
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
          expect(choices.map((c) => c.missionChunkId), [
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
    },
  );

  test('captures caller-owned lists before editing can change a route', () {
    final markers = <SpawnMarker>[
      const SpawnMarker(
        enemyId: EnemyId.derf,
        x: 150,
        chancePercent: 100,
        salt: 0,
      ),
    ];
    final missionChunks = [
      FiniteMissionChunk(
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
    final route = FiniteChunkPatternSource(missionChunks);
    markers.clear();
    missionChunks.clear();
    expect(route.length, 1);
    expect(
      route.missionChunks.single.pattern.spawnMarkers.single.enemyId,
      EnemyId.derf,
    );
    expect(() => route.missionChunks.clear(), throwsUnsupportedError);
    expect(
      () => route.missionChunks.single.pattern.spawnMarkers.clear(),
      throwsUnsupportedError,
    );
  });

  test(
    'rejects empty routes, duplicate mission chunk IDs and missing identities',
    () {
      expect(() => FiniteChunkPatternSource([]), throwsArgumentError);
      expect(
        () => FiniteChunkPatternSource([
          _missionChunk('same', 'first'),
          _missionChunk('same', 'second'),
        ]),
        throwsArgumentError,
      );
      for (final value in ['', ' ', ' leading', 'trailing ']) {
        expect(() => _missionChunk(value, 'chunk'), throwsArgumentError);
        expect(() => _missionChunk('id', value), throwsArgumentError);
        expect(
          () => FiniteMissionChunk(
            id: 'id',
            sourceLevelId: value,
            pattern: const ChunkPattern(name: 'chunk', chunkKey: 'chunk'),
            tier: ChunkPatternTier.easy,
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => FiniteMissionChunk(
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

FiniteMissionChunk _missionChunk(
  String id,
  String key, [
  ChunkPatternTier tier = ChunkPatternTier.easy,
]) => FiniteMissionChunk(
  id: id,
  sourceLevelId: 'forest',
  pattern: ChunkPattern(name: key, chunkKey: key),
  tier: tier,
);
