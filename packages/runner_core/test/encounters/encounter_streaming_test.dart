import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/npcs/npc_catalog.dart';
import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/encounters/encounter_instance.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/track_streamer.dart';
import 'package:runner_core/tuning/track_tuning.dart';
import 'package:test/test.dart';
import 'package:runner_core/commands/command.dart';

void main() {
  for (final id in NpcId.values) {
    test(
      '${id.name} publishes typed health, motion and animation snapshots',
      () {
        final core = _core(npcId: id);
        core.stepOneTick();
        final actor = core.buildSnapshot().entities.singleWhere(
          (e) => e.npcId == id,
        );
        expect(actor.kind, EntityKind.npc);
        expect(actor.enemyId, isNull);
        expect(actor.artFacingDir, Facing.right);
        expect(actor.npcHealth!.hp100, const NpcCatalog().get(id).health.hp);
        expect(actor.npcHealth!.protected, isFalse);
        expect(actor.size!.y, 54);
        expect(actor.animFrame, isNotNull);
      },
    );
  }

  test('real player and warrior damage resolve a streamed rescue once', () {
    final core = _core(enemyId: EnemyId.grojib);
    core.stepOneTick();
    core.setPlayerPosXYUnsafeForTest(460, core.playerPosY);
    final outcomes = <EncounterOutcome>[];
    for (var i = 0; i < 300 && !core.gameOver; i++) {
      core.applyCommands([StrikePressedCommand(tick: core.tick + 1)]);
      core.stepOneTick();
      outcomes.addAll(
        core.drainEvents().whereType<EncounterResolvedEvent>().map(
          (e) => e.outcome,
        ),
      );
      if (outcomes.any((e) => e.key.chunkIndex == 0)) break;
    }
    final rescued = outcomes.singleWhere((e) => e.key.chunkIndex == 0);
    expect(rescued.reason, EncounterEndReason.rescued);
    expect(rescued.survivors, 1);
    expect(rescued.points, 250);
    core.giveUp();
    final endedEvents = core.drainEvents();
    final stats = endedEvents.whereType<RunEndedEvent>().single.stats;
    expect(stats.rescuedNpcs, 1);
    expect(stats.rescuePoints, 250);
    expect(
      endedEvents.whereType<EncounterResolvedEvent>().where(
        (e) => e.outcome.key.chunkIndex == 0,
      ),
      isEmpty,
    );
  });
  test('Core activates one complete roster per entered repeated chunk', () {
    final core = _core();
    expect(
      core.buildSnapshot().entities.where((e) => e.enemyId != null),
      isEmpty,
    );
    core.stepOneTick();
    expect(
      core.buildSnapshot().entities.where((e) => e.enemyId != null),
      hasLength(1),
    );
    core.stepOneTick();
    expect(
      core.buildSnapshot().entities.where((e) => e.enemyId != null),
      hasLength(1),
    );
    core.setPlayerPosXYUnsafeForTest(750, core.playerPosY);
    core.stepOneTick();
    expect(
      core.buildSnapshot().entities.where((e) => e.enemyId != null),
      hasLength(2),
    );
    core.giveUp();
    final outcomes = core
        .drainEvents()
        .whereType<EncounterResolvedEvent>()
        .map((e) => e.outcome)
        .toList();
    expect(outcomes.where((o) => o.key.chunkIndex == 0), hasLength(1));
    expect(outcomes.where((o) => o.key.chunkIndex == 1), hasLength(1));
    expect(
      outcomes.every(
        (o) => o.reason == EncounterEndReason.runEnded && o.points == 0,
      ),
      isTrue,
    );
  });

  test('opening suppression skips the whole roster and invalid placement is atomic', () {
    final suppressed = _core(noEnemyChunks: 2);
    suppressed.stepOneTick();
    expect(
      suppressed.buildSnapshot().entities.where((e) => e.enemyId != null),
      isEmpty,
    );
    expect(
      suppressed.drainEvents().whereType<EncounterResolvedEvent>().where(
        (e) => e.outcome.reason == EncounterEndReason.openingSuppression,
      ),
      hasLength(2),
    );
    final invalid = _core(npcX: 1);
    invalid.stepOneTick();
    expect(
      invalid.buildSnapshot().entities.where((e) => e.enemyId != null),
      isEmpty,
    );
    final outcome = invalid
        .drainEvents()
        .whereType<EncounterResolvedEvent>()
        .single
        .outcome;
    expect(outcome.reason, EncounterEndReason.invalidSpawn);
    expect(outcome.points, 0);
  });

  test('stream retention delays teardown until the owner releases a chunk', () {
    final streamer = TrackStreamer(
      seed: 1,
      tuning: const TrackTuning(
        chunkWidth: 600,
        spawnAheadMargin: 0,
        cullBehindMargin: 0,
      ),
      groundTopY: 200,
      patternSource: _source(),
      earlyPatternChunks: 0,
      noEnemyChunks: 0,
    );
    streamer.step(cameraLeft: 0, cameraRight: 600, spawnEnemy: (_) {});
    streamer.step(
      cameraLeft: 601,
      cameraRight: 1201,
      spawnEnemy: (_) {},
      retainChunk: (i) => i == 0,
    );
    expect(streamer.activeChunks.first.index, 0);
    expect(streamer.activeChunks.first.encounters.single.id, 'rescue');
    streamer.step(
      cameraLeft: 1200,
      cameraRight: 1800,
      spawnEnemy: (_) {},
      retainChunk: (_) => false,
    );
    expect(streamer.activeChunks.first.index, 1);
  });
}

ChunkPatternSource _source({
  NpcId npcId = NpcId.warrior,
  double npcX = 430,
  EnemyId enemyId = EnemyId.hashash,
}) => ChunkPatternListSource(
  easyPatterns: const [],
  normalPatterns: [
    ChunkPattern(
      name: 'field_default_normal_001',
      chunkKey: 'field_default_normal_001',
      encounters: [
        EncounterDefinition(
          id: 'rescue',
          name: 'Rescue',
          trigger: EncounterTrigger(x: 0, y: -1000, width: 600, height: 2000),
          npcs: [EncounterNpcPlacement(id: 'warrior', npcId: npcId, x: npcX)],
          enemies: [
            EncounterEnemyPlacement(id: 'foe', enemyId: enemyId, x: 480),
          ],
        ),
      ],
    ),
  ],
);

GameCore _core({
  int noEnemyChunks = 0,
  NpcId npcId = NpcId.warrior,
  double npcX = 430,
  EnemyId enemyId = EnemyId.hashash,
}) => GameCore(
  seed: 7,
  playerCharacter: PlayerCharacterRegistry.eloise,
  levelDefinition: LevelRegistry.byId(LevelId.field).copyWith(
    noEnemyChunks: noEnemyChunks,
    earlyPatternChunks: 0,
    clearAssembly: true,
    clearFirstChunkKey: true,
    chunkPatternSource: _source(npcId: npcId, npcX: npcX, enemyId: enemyId),
  ),
);
