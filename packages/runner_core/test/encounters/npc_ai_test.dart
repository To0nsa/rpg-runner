import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/combat/ai_target_policy.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/combat/damage_credit.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/faction_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/world_contact_capsule_store.dart';
import 'package:runner_core/ecs/systems/ai_target_system.dart';
import 'package:runner_core/ecs/systems/enemy_melee_system.dart';
import 'package:runner_core/ecs/systems/ground_enemy_locomotion_system.dart';
import 'package:runner_core/ecs/systems/hitbox_damage_system.dart';
import 'package:runner_core/ecs/systems/hitbox_follow_owner_system.dart';
import 'package:runner_core/ecs/systems/melee_strike_system.dart';
import 'package:runner_core/ecs/systems/npc_ai_system.dart';
import 'package:runner_core/ecs/systems/npc_combat_lifecycle.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/npcs/npc_catalog.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/tuning/ground_enemy_tuning.dart';
import 'package:test/test.dart';

void main() {
  test('NPC commits one paid timed strike through ordinary hit detection', () {
    final world = EcsWorld();
    final npc = _npc(world);
    final enemy = world.createEntity();
    world.transform.add(enemy, posX: 140, posY: 50, velX: 0, velY: 0);
    world.health.add(
      enemy,
      const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
    );
    world.faction.add(enemy, const FactionDef(faction: Faction.enemy));
    const collider = ColliderAabbDef(halfX: 10, halfY: 25);
    world.colliderAabb.add(enemy, collider);
    world.worldContactCapsule.add(
      enemy,
      WorldContactCapsuleDef.fromAabb(collider),
    );
    world.aiTarget.configure(
      npc,
      targetPolicy: AiTargetPolicy.nearestOpponent,
      candidates: [enemy],
      playerFallback: false,
    );
    AiTargetSystem().step(world, player: -1);
    // Rooting movement must not suppress an otherwise valid attack.
    world.controlLock.addLock(npc, LockFlag.move, 30, 0);
    final ai = NpcAiSystem(
      tickHz: 60,
      locomotion: GroundEnemyLocomotionSystem(
        groundEnemyTuning: GroundEnemyTuningDerived.from(
          const GroundEnemyTuning(),
          tickHz: 60,
        ),
      ),
    );
    ai.step(world, currentTick: 10, dtSeconds: 1 / 60);
    ai.step(world, currentTick: 10, dtSeconds: 1 / 60);
    expect(world.stamina.stamina[world.stamina.indexOf(npc)], 3600);
    expect(world.meleeIntent.tick[world.meleeIntent.indexOf(npc)], 22);
    MeleeStrikeSystem().step(world, currentTick: 21);
    expect(world.hitbox.denseEntities, isEmpty);
    MeleeStrikeSystem().step(world, currentTick: 22);
    MeleeStrikeSystem().step(world, currentTick: 22);
    expect(world.hitbox.denseEntities, hasLength(1));
    HitboxFollowOwnerSystem().step(world);
    final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 64))
      ..rebuild(world);
    HitboxDamageSystem().step(world, grid, currentTick: 22);
    expect(world.damageQueue.target.single, enemy);
    expect(world.damageQueue.amount100.single, 400);
    expect(world.damageQueue.credit.single, DamageCredit.none);
  });

  for (final reason in [
    'stun',
    'strike lock',
    'cooldown',
    'stamina',
    'dead',
    'protected',
  ]) {
    test('shared AI melee commit rejects $reason without side effects', () {
      final world = EcsWorld();
      final npc = _npc(world);
      final ability = AbilityCatalog.shared.resolve('npc_warrior.slash')!;
      switch (reason) {
        case 'stun':
          world.controlLock.addLock(npc, LockFlag.stun, 20, 0);
        case 'strike lock':
          world.controlLock.addLock(npc, LockFlag.strike, 20, 0);
        case 'cooldown':
          world.cooldown.startCooldown(
            npc,
            ability.effectiveCooldownGroup(AbilitySlot.primary),
            20,
          );
        case 'stamina':
          world.stamina.stamina[world.stamina.indexOf(npc)] = 399;
        case 'dead':
          world.health.hp[world.health.indexOf(npc)] = 0;
        case 'protected':
          protectNpc(world, npc);
      }
      final before = world.stamina.stamina[world.stamina.indexOf(npc)];
      expect(
        const AiMeleeCommitter(tickHz: 60).commit(
          world,
          actor: npc,
          abilityId: ability.id,
          targetX: 140,
          currentTick: 1,
        ),
        isNull,
      );
      expect(world.activeAbility.hasActiveAbility(npc), isFalse);
      expect(world.stamina.stamina[world.stamina.indexOf(npc)], before);
      expect(world.meleeIntent.tick[world.meleeIntent.indexOf(npc)], -1);
    });
  }
}

int _npc(EcsWorld world) {
  final npc = EntityFactory(world).createNpc(
    npcId: NpcId.warrior,
    posX: 100,
    posY: 50,
    chunkStartX: 0,
    chunkEndX: 500,
  );
  world.collision.grounded[world.collision.indexOf(npc)] = true;
  world.worldContactCapsule.add(
    npc,
    const NpcCatalog().terrainContactProfile(NpcId.warrior).capsule,
  );
  return npc;
}
