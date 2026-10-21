import 'package:replay_validator/src/replay_simulation.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/tuning/collectible_tuning.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:runner_core/tuning/restoration_item_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';
import 'package:test/test.dart';

void main() {
  test('easy gem bonus survives startup streaming and protocol replay', () {
    final direct = _buildCore();
    final replayed = _buildCore();
    final base = _buildCore(bonusBp: 0);
    expect(_gems(direct).length, greaterThan(_gems(base).length));
    expect(_gems(replayed), _gems(direct));
    final initialTerrainVersion = direct
        .buildSnapshot()
        .stagedTerrainRenderSnapshot!
        .geometryVersion;

    final frames = <ReplayCommandFrameV1>[];
    for (var tick = 1; tick <= 240; tick++) {
      frames.add(ReplayCommandFrameV1(tick: tick, moveAxis: 1, pressedMask: 0));
      direct.applyCommands([MoveAxisCommand(tick: tick, axis: 1)]);
      direct.stepOneTick();
      expect(direct.gameOver, isFalse, reason: 'tick $tick');
    }
    expect(
      direct.buildSnapshot().stagedTerrainRenderSnapshot!.geometryVersion,
      greaterThan(initialTerrainVersion),
    );
    final result = runReplaySimulation(
      core: replayed,
      totalTicks: direct.tick,
      commandStream: frames,
    );
    expect(result.runEnded, isNull);
    expect(_gems(replayed), _gems(direct));
    final actual = replayed.buildSnapshot().hud;
    final expected = direct.buildSnapshot().hud;
    expect(
      [actual.hp, actual.mana, actual.stamina],
      [expected.hp, expected.mana, expected.stamina],
    );
    expect(replayed.playerPosX, direct.playerPosX);
  });
}

GameCore _buildCore({int bonusBp = 2000}) => GameCore(
  seed: 42,
  levelDefinition: LevelRegistry.byId(LevelId.field).copyWith(
    clearAssembly: true,
    clearFirstChunkKey: true,
    earlyPatternChunks: 0,
    easyPatternChunks: 80,
    noEnemyChunks: 1000,
    chunkPatternSource: const ChunkPatternListSource(
      easyPatterns: [
        ChunkPattern(name: 'flat_easy', chunkKey: 'field_default_easy_004'),
      ],
    ),
    tuning: CoreTuning(
      track: const TrackTuning(spawnAheadMargin: 3000),
      collectible: const CollectibleTuning(enabled: false),
      restorationItem: RestorationItemTuning(
        spawnEveryChunks: 1,
        spawnStartChunkIndex: 0,
        easySpawnRateBonusBp: bonusBp,
      ),
    ),
  ),
  playerCharacter: PlayerCharacterRegistry.eloise,
);

List<Object> _gems(GameCore core) => [
  for (final entity in core.buildSnapshot().entities)
    if (entity.kind == EntityKind.pickup &&
        entity.pickupVariant != PickupVariant.collectible)
      (entity.id, entity.pos.x, entity.pos.y, entity.pickupVariant),
];
