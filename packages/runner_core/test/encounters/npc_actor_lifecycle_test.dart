import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/systems/anim/anim_system.dart';
import 'package:runner_core/ecs/systems/death_despawn_system.dart';
import 'package:runner_core/ecs/systems/enemy_death_state_system.dart';
import 'package:runner_core/ecs/systems/health_despawn_system.dart';
import 'package:runner_core/ecs/systems/npc_death_state_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:test/test.dart';

void main() {
  test('invalid NPC placement rejects before allocating any components', () {
    final world = EcsWorld();
    expect(
      () => EntityFactory(world).createNpc(
        npcId: NpcId.warrior,
        posX: 1,
        posY: 50,
        chunkStartX: 0,
        chunkEndX: 500,
      ),
      throwsArgumentError,
    );
    expect(world.health.denseEntities, isEmpty);
    expect(world.createEntity(), EcsWorld().createEntity());
  });
  test('NPC death cancels combat, animates before cleanup, and never awards a kill', () {
    final world = EcsWorld();
    final npc = EntityFactory(world).createNpc(
      npcId: NpcId.warrior,
      posX: 100,
      posY: 50,
      chunkStartX: 0,
      chunkEndX: 500,
    );
    world.collision.grounded[world.collision.indexOf(npc)] = true;
    world.activeAbility.set(
      npc,
      id: 'npc_warrior.slash',
      slot: AbilitySlot.primary,
      commitTick: 1,
      windupTicks: 12,
      activeTicks: 6,
      recoveryTicks: 6,
      facingDir: Facing.right,
    );
    final anim = AnimSystem(
      tickHz: 60,
      enemyCatalog: const EnemyCatalog(),
      playerMovement: MovementTuningDerived.from(
        PlayerCharacterRegistry.eloise.tuning.movement,
        tickHz: 60,
      ),
      playerAnimTuning: AnimTuningDerived.from(
        PlayerCharacterRegistry.eloise.tuning.anim,
        tickHz: 60,
      ),
    );
    anim.step(world, player: -1, currentTick: 1);
    expect(world.animState.anim[world.animState.indexOf(npc)], AnimKey.strike);
    world.health.hp[world.health.indexOf(npc)] = 0;
    HealthDespawnSystem().step(world, player: -1);
    expect(world.npc.has(npc), isTrue);
    final kills = <EnemyId>[];
    EnemyDeathStateSystem(tickHz: 60)
        .step(world, currentTick: 2, outEnemiesKilled: kills);
    NpcDeathStateSystem(tickHz: 60).step(world, currentTick: 2);
    expect(kills, isEmpty);
    expect(world.activeAbility.hasActiveAbility(npc), isFalse);
    anim.step(world, player: -1, currentTick: 2);
    expect(world.animState.anim[world.animState.indexOf(npc)], AnimKey.death);
    final endTick = world.deathState.despawnTick[world.deathState.indexOf(npc)];
    expect(endTick, greaterThan(2));
    DeathDespawnSystem().step(world, currentTick: endTick - 1);
    expect(world.npc.has(npc), isTrue);
    DeathDespawnSystem().step(world, currentTick: endTick);
    expect(world.npc.has(npc), isFalse);
  });

  test(
    'airborne NPC death retains gravity until impact or bounded deadline',
    () {
      final world = EcsWorld();
      final npc = EntityFactory(world).createNpc(
        npcId: NpcId.warrior,
        posX: 100,
        posY: 50,
        chunkStartX: 0,
        chunkEndX: 500,
      );
      final ti = world.transform.indexOf(npc);
      world.transform.velX[ti] = 100;
      world.transform.velY[ti] = 50;
      world.health.hp[world.health.indexOf(npc)] = 0;
      final death = NpcDeathStateSystem(tickHz: 60);
      death.step(world, currentTick: 1);
      expect(world.transform.velX[ti], 0);
      expect(world.transform.velY[ti], 50);
      death.step(world, currentTick: 180);
      expect(
        world.deathState.deathStartTick[world.deathState.indexOf(npc)],
        -1,
      );
      death.step(world, currentTick: 181);
      expect(
        world.deathState.deathStartTick[world.deathState.indexOf(npc)],
        181,
      );
      expect(world.transform.velY[ti], 0);
    },
  );
}
