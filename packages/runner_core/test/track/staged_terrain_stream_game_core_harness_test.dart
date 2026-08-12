import 'package:runner_core/commands/command.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:test/test.dart';

void main() {
  test('stream harness republishes one deterministic terrain world', () {
    GameCore build() => GameCore.stagedTerrainStreamHarness(
      seed: 9127,
      levelDefinition: LevelRegistry.byId(
        LevelId.field,
      ).copyWith(noEnemyChunks: 9999),
      playerCharacter: PlayerCharacterRegistry.eloise,
    );

    final first = build();
    final second = build();
    final initialVersion = _expectSameTerrainWorld(first, second);
    expect(initialVersion, 1);
    expect(first.playerGrounded, isTrue);

    for (var nextTick = 1; nextTick <= 900; nextTick++) {
      final commands = <Command>[MoveAxisCommand(tick: nextTick, axis: 1)];
      first.applyCommands(commands);
      second.applyCommands(commands);
      first.stepOneTick();
      second.stepOneTick();
      expect(first.gameOver, isFalse, reason: 'first tick $nextTick');
      expect(second.gameOver, isFalse, reason: 'second tick $nextTick');
      if (nextTick % 30 == 0) {
        _expectSameTerrainWorld(first, second);
        expect(first.playerGrounded, isTrue, reason: 'tick $nextTick');
      }
    }

    expect(_expectSameTerrainWorld(first, second), greaterThan(initialVersion));
  });

  test('terrain publication precedes markers and both pickup policies', () {
    var enemyCount = 0;
    var collectibleCount = 0;
    var restorationCount = 0;
    final level = LevelRegistry.byId(LevelId.forest).copyWith(
      earlyPatternChunks: 0,
      easyPatternChunks: 100,
      normalPatternChunks: 0,
      noEnemyChunks: 0,
    );

    for (var seed = 0; seed < 8; seed++) {
      final core = GameCore.stagedTerrainStreamHarness(
        seed: seed,
        levelDefinition: level,
        playerCharacter: PlayerCharacterRegistry.eloise,
      );
      core.applyCommands(const <Command>[]);
      core.stepOneTick();
      expect(core.gameOver, isFalse, reason: 'seed $seed');
      expect(core.playerGrounded, isTrue, reason: 'seed $seed');
      final entities = core.buildSnapshot().entities;
      final enemies = entities.where(
        (entity) => entity.kind == EntityKind.enemy,
      );
      expect(enemies, everyElement(_isGroundedEntity));
      enemyCount += enemies.length;
      collectibleCount += entities
          .where(
            (entity) =>
                entity.kind == EntityKind.pickup &&
                entity.pickupVariant == PickupVariant.collectible,
          )
          .length;
      restorationCount += entities
          .where(
            (entity) =>
                entity.kind == EntityKind.pickup &&
                entity.pickupVariant != PickupVariant.collectible,
          )
          .length;
    }

    expect(enemyCount, greaterThan(0));
    expect(collectibleCount, greaterThan(0));
    expect(restorationCount, greaterThan(0));
  });

  test('stream harness retains the terrain fall-death policy', () {
    final core = GameCore.stagedTerrainStreamHarness(
      seed: 19,
      levelDefinition: LevelRegistry.byId(LevelId.field),
      playerCharacter: PlayerCharacterRegistry.eloise,
    );
    core.setPlayerPosXYUnsafeForTest(core.playerPosX, 2000);

    core.applyCommands(const <Command>[]);
    core.stepOneTick();

    expect(core.gameOver, isTrue);
    expect(core.playerGrounded, isFalse);
  });
}

bool _isGroundedEntity(EntityRenderSnapshot entity) => entity.grounded;

int _expectSameTerrainWorld(GameCore first, GameCore second) {
  final firstRender = first.buildSnapshot().stagedTerrainRenderSnapshot;
  final secondRender = second.buildSnapshot().stagedTerrainRenderSnapshot;
  final firstDebug = first.buildTerrainPlayerDebugSnapshot();
  final secondDebug = second.buildTerrainPlayerDebugSnapshot();
  expect(firstRender, isNotNull);
  expect(secondRender, isNotNull);
  expect(firstDebug, isNotNull);
  expect(secondDebug, isNotNull);
  expect(secondRender!.geometryVersion, firstRender!.geometryVersion);
  expect(firstDebug!.geometryVersion, firstRender.geometryVersion);
  expect(secondDebug!.geometryVersion, secondRender.geometryVersion);
  expect(
    secondRender.polygons.map((polygon) => polygon.sourceId),
    orderedEquals(firstRender.polygons.map((polygon) => polygon.sourceId)),
  );
  expect(
    secondRender.edges.map((edge) => edge.id),
    orderedEquals(firstRender.edges.map((edge) => edge.id)),
  );
  expect(secondDebug.supportEdgeId, firstDebug.supportEdgeId);
  return firstRender.geometryVersion;
}
