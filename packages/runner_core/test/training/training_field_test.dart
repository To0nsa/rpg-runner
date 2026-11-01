import 'package:runner_core/commands/command.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/training/authored_training_field.dart';
import 'package:runner_core/training/training_field_placement.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:test/test.dart';

import '../test_support/level_enemy_traversal.dart';

GameCore _field() => GameCore.trainingField(
  definition: trainingFieldDefinition,
  playerCharacter: PlayerCharacterRegistry.eloise,
  equippedLoadout: const EquippedLoadoutDef(),
);

void main() {
  test('layout admits player and all regular enemies on terrain', () {
    expect(
      () => validateTrainingFieldPlacement(trainingFieldDefinition),
      returnsNormally,
    );
  });
  test('idle field has zero camera advance and no procedural spawns', () {
    final core = _field();
    final before = core.buildSnapshot();
    for (var i = 0; i < 600; i++) {
      core.stepOneTick();
    }
    // The ordinary follow camera initially frames the player's front edge.
    // Once settled it must remain there, with no automatic runner advance.
    final settledCamera = core.buildSnapshot().camera.centerX;
    for (var i = 0; i < 600; i++) {
      core.stepOneTick();
    }
    final after = core.buildSnapshot();
    expect(after.gameOver, isFalse);
    expect(after.camera.centerX, closeTo(settledCamera, 0.000001));
    expect(after.playerEntity!.pos.x, before.playerEntity!.pos.x);
    expect(after.entities.where((e) => e.kind != EntityKind.player), isEmpty);
    expect(after.hud.hp, before.hud.hp);
  });
  test(
    'continuous player movement crosses three repetitions without wrapping',
    () {
      final core = _field();
      var previousX = core.buildSnapshot().playerEntity!.pos.x;
      final startCamera = core.buildSnapshot().camera.centerX;
      final seen = <int, String>{};
      for (var i = 0; i < 1500 && previousX < 3601; i++) {
        core.applyCommands([MoveAxisCommand(tick: core.tick + 1, axis: 1)]);
        core.stepOneTick();
        final snapshot = core.buildSnapshot();
        expect(snapshot.gameOver, isFalse);
        final x = snapshot.playerEntity!.pos.x;
        expect(x, inInclusiveRange(previousX, previousX + 10));
        previousX = x;
        for (final p in snapshot.stagedTerrainRenderSnapshot!.polygons) {
          seen[p.sourceId.chunkIndex] = p.sourceId.chunkKey;
        }
      }
      expect(previousX, greaterThan(3600));
      expect(core.buildSnapshot().camera.centerX, greaterThan(startCamera));
      for (final entry in seen.entries) {
        expect(entry.value, 'training_field_${entry.key % 2 + 1}');
      }
    },
  );
  for (final id in EnemyId.values.where((id) => !id.isArenaOnly)) {
    test('${id.name} spawns once at next marked chunk and None clears it', () {
      final core = _field();
      core.selectTrainingEnemy(id);
      core.stepOneTick();
      final enemy = core
          .buildSnapshot()
          .entities
          .where((e) => e.kind == EntityKind.enemy)
          .single;
      expect(enemy.enemyId, id);
      expect(enemy.pos.x, closeTo(900, 5));
      core.selectTrainingEnemy(null);
      core.stepOneTick();
      for (var i = 0; i < 180; i++) {
        core.stepOneTick();
      }
      expect(
        core.buildSnapshot().entities.where((e) => e.kind == EntityKind.enemy),
        isEmpty,
      );
    });
  }
  test('replacement never leaves two enemies and bosses are rejected', () {
    final core = _field();
    core.selectTrainingEnemy(EnemyId.derf);
    core.stepOneTick();
    core.selectTrainingEnemy(EnemyId.grojib);
    core.stepOneTick();
    expect(
      core
          .buildSnapshot()
          .entities
          .where((e) => e.kind == EntityKind.enemy)
          .map((e) => e.enemyId),
      [EnemyId.grojib],
    );
    expect(
      () => core.selectTrainingEnemy(EnemyId.bringerOfDeath),
      throwsArgumentError,
    );
    expect(
      _field().buildSnapshot().entities.where(
        (e) => e.kind == EntityKind.enemy,
      ),
      isEmpty,
    );
  });
  // Finite route: four chunks, both loop joins twice, seed 1, real catalog
  // capabilities, continuous actor state, and a fifth continuation chunk.
  for (final id in EnemyId.values.where((id) => !id.isArenaOnly)) {
    test('${id.name} continuously traverses the two-chunk loop twice', () {
      final field = trainingFieldDefinition;
      final source = field.buildLevel().chunkPatternSource;
      final route = LevelTraversalRoute.chunks(
        level: field.buildLevel(),
        seed: 1,
        catalog: field.terrainCatalog,
        chunkKeys: [
          for (var i = 0; i < 4; i++)
            source
                .selectionFor(
                  seed: 1,
                  chunkIndex: i,
                  tier: ChunkPatternTier.easy,
                )
                .pattern
                .chunkKey!,
        ],
        continuationChunkKey: field.chunks.first.chunkKey!,
      );
      final harness = EnemyTraversalHarness(route, id);
      expect(harness.traverse(), isNull);
      expect(harness.enemyX, greaterThanOrEqualTo(harness.finishX));
      expect(harness.visitedChunks, containsAll([0, 1, 2, 3]));
    });
  }
}
