import 'package:runner_core/bosses/boss_arena_definition.dart';
import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/finite_chunk_pattern_source.dart';
import 'package:runner_core/track/track_streamer.dart';
import 'package:runner_core/tuning/track_tuning.dart';
import 'package:test/test.dart';

void main() {
  test('publishes all occurrences once and retains them on return travel', () {
    final streamer = _streamer();
    final requests = <SpawnEnemyRequest>[];
    final projected = streamer.selectionForStep(
      cameraLeft: 0,
      cameraRight: 600,
    );
    expect(streamer.activeChunks, isEmpty);
    expect(projected.map((c) => c.occurrenceId), [
      'entrance',
      'camp',
      'return',
    ]);
    final upcoming = streamer.upcomingSelections(viewWidth: 600, count: 12);
    expect(upcoming, hasLength(1));
    expect(upcoming.single.map(_record), projected.map(_record));
    expect(() => upcoming.clear(), throwsUnsupportedError);

    final first = streamer.step(
      cameraLeft: 0,
      cameraRight: 600,
      spawnEnemy: requests.add,
    );
    expect(first.changed, isTrue);
    expect(first.spawnedChunks.map((c) => c.occurrenceId), [
      'entrance',
      'camp',
      'return',
    ]);
    expect(first.spawnedChunks.map((c) => c.tier), [
      ChunkPatternTier.easy,
      ChunkPatternTier.normal,
      ChunkPatternTier.easy,
    ]);
    expect(streamer.activeChunks.map(_record), projected.map(_record));
    expect(streamer.activeChunks.map((c) => c.startX), [0, 600, 1200]);
    expect(streamer.activeChunks.last.endX, 1800);
    // Hashash uses its authored position here, not the runner's edge spawn.
    expect(requests.map((r) => r.x), [120, 280, 720, 880, 1320, 1480]);
    expect(
      requests.every((r) => r.source == EnemySpawnRequestSource.authoredMarker),
      isTrue,
    );
    expect(streamer.dynamicVisualSprites.map((s) => s.x), [40, 640, 1240]);
    final initial = streamer.activeChunks;
    for (final left in [600.0, 1200.0, 24000.0, 600.0, 0.0, -600.0, 1200.0]) {
      expect(
        streamer.selectionForStep(cameraLeft: left, cameraRight: left + 600),
        same(initial),
      );
      final step = streamer.step(
        cameraLeft: left,
        cameraRight: left + 600,
        spawnEnemy: requests.add,
      );
      expect(step.changed, isFalse);
      expect(step.spawnedChunks, isEmpty);
      expect(streamer.activeChunks, same(initial));
      expect(streamer.upcomingSelections(viewWidth: 600, count: 12), isEmpty);
    }
    expect(requests, hasLength(6));
    expect(streamer.difficultyAtWorldX(-1), isNull);
    expect(streamer.difficultyAtWorldX(600), ChunkPatternTier.normal);
    expect(streamer.difficultyAtWorldX(1800), isNull);
  });

  test(
    'preserves encounter and boss metadata without filtering copied content',
    () {
      final encounter = EncounterDefinition(
        id: 'rescue',
        name: 'Rescue',
        trigger: EncounterTrigger(x: 10, y: 10, width: 20, height: 20),
      );
      final arena = BossArenaDefinition(
        id: 'arena',
        enemyId: EnemyId.bringerOfDeath,
        spawnX: 400,
        minX: 0,
        maxX: 600,
      );
      final streamer = _streamer(
        pattern: ChunkPattern(
          name: 'retained_content',
          chunkKey: 'forest_test_normal_001',
          encounters: [encounter],
          bossArena: arena,
        ),
      );
      streamer.step(cameraLeft: 0, cameraRight: 600, spawnEnemy: (_) {});
      for (final chunk in streamer.activeChunks) {
        expect(chunk.encounters.single, same(encounter));
        expect(chunk.bossArena, same(arena));
        expect(() => chunk.encounters.clear(), throwsUnsupportedError);
      }
    },
  );

  test('projections never consume marker rolls or spawn requests', () {
    for (final seed in [7, 42, 2026]) {
      final observed = _streamer(seed: seed);
      final control = _streamer(seed: seed);
      final actual = <SpawnEnemyRequest>[];
      final expected = <SpawnEnemyRequest>[];
      for (var i = 0; i < 3; i++) {
        observed.upcomingSelections(viewWidth: 600, count: 12);
        observed.selectionForStep(
          cameraLeft: i * 600,
          cameraRight: (i + 1) * 600,
        );
      }
      observed.step(
        cameraLeft: 1200,
        cameraRight: 1800,
        spawnEnemy: actual.add,
      );
      control.step(cameraLeft: 0, cameraRight: 600, spawnEnemy: expected.add);
      expect(
        actual.map((r) => (r.enemyId, r.x, r.source)),
        expected.map((r) => (r.enemyId, r.x, r.source)),
      );
      expect(
        observed.activeChunks.map(_record),
        control.activeChunks.map(_record),
      );
    }
  });

  test('finite routes reject implicit opening encounter suppression', () {
    expect(() => _streamer(noEnemyChunks: 1), throwsArgumentError);
  });

  test('disabled streaming has no finite-route side effects', () {
    final streamer = _streamer(enabled: false);
    final requests = <SpawnEnemyRequest>[];
    expect(streamer.selectionForStep(cameraLeft: 0, cameraRight: 600), isEmpty);
    expect(streamer.upcomingSelections(viewWidth: 600, count: 12), isEmpty);
    final step = streamer.step(
      cameraLeft: 0,
      cameraRight: 600,
      spawnEnemy: requests.add,
    );
    expect(step.changed, isFalse);
    expect(requests, isEmpty);
    expect(streamer.activeChunks, isEmpty);
  });
}

Object _record(ActiveTrackChunkSnapshot c) =>
    (c.index, c.occurrenceId, c.chunkKey, c.startX, c.endX, c.tier);

TrackStreamer _streamer({
  int seed = 42,
  int noEnemyChunks = 0,
  bool enabled = true,
  ChunkPattern? pattern,
}) {
  const repeated = ChunkPattern(
    name: 'fixture',
    chunkKey: 'forest_fixture_easy_001',
    spawnMarkers: [
      SpawnMarker(enemyId: EnemyId.derf, x: 120, chancePercent: 100, salt: 0),
      SpawnMarker(
        enemyId: EnemyId.hashash,
        x: 280,
        chancePercent: 100,
        salt: 1,
      ),
    ],
    visualSprites: [
      ChunkVisualSpriteRel(
        assetPath: 'fixture.png',
        srcX: 0,
        srcY: 0,
        srcWidth: 10,
        srcHeight: 10,
        x: 40,
        y: 100,
        width: 10,
        height: 10,
      ),
    ],
  );
  return TrackStreamer(
    seed: seed,
    tuning: TrackTuning(
      enabled: enabled,
      spawnAheadMargin: 0,
      cullBehindMargin: 0,
    ),
    groundTopY: 224,
    earlyPatternChunks: 0,
    noEnemyChunks: noEnemyChunks,
    patternSource: FiniteChunkPatternSource([
      for (final (id, tier) in [
        ('entrance', ChunkPatternTier.easy),
        ('camp', ChunkPatternTier.normal),
        ('return', ChunkPatternTier.easy),
      ])
        FiniteChunkOccurrence(
          id: id,
          sourceLevelId: 'forest',
          pattern: pattern ?? repeated,
          tier: tier,
        ),
    ]),
  );
}
