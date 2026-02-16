import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/combat/damage_type.dart';
import 'package:rpg_runner/core/combat/faction.dart';
import 'package:rpg_runner/core/combat/status/status.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';
import 'package:rpg_runner/core/ecs/spatial/broadphase_grid.dart';
import 'package:rpg_runner/core/ecs/spatial/grid_index_2d.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/faction_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/systems/active_ability_phase_system.dart';
import 'package:rpg_runner/core/ecs/systems/mobility_impact_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/events/game_event.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/tuning/spatial_grid_tuning.dart';

void main() {
  test('roll contact queues stun once per target during one activation', () {
    final world = EcsWorld();
    final player = _spawnPlayer(world);
    final enemy = _spawnEnemy(world);
    final phaseSystem = ActiveAbilityPhaseSystem();
    final impactSystem = MobilityImpactSystem(
      abilities: const AbilityCatalog(),
    );
    final broadphase = BroadphaseGrid(
      index: GridIndex2D(
        cellSize: const SpatialGridTuning().broadphaseCellSize,
      ),
    );
    final queuedStatus = <StatusRequest>[];

    world.activeAbility.set(
      player,
      id: 'eloise.roll',
      slot: AbilitySlot.mobility,
      commitTick: 1,
      windupTicks: 0,
      activeTicks: 8,
      recoveryTicks: 0,
      facingDir: Facing.right,
    );

    phaseSystem.step(world, currentTick: 1);
    broadphase.rebuild(world);
    impactSystem.step(
      world,
      broadphase,
      currentTick: 1,
      queueStatus: queuedStatus.add,
    );

    expect(queuedStatus.length, equals(1));
    expect(queuedStatus.single.target, equals(enemy));
    expect(queuedStatus.single.profileId, equals(StatusProfileId.stunOnHit));

    phaseSystem.step(world, currentTick: 2);
    broadphase.rebuild(world);
    impactSystem.step(
      world,
      broadphase,
      currentTick: 2,
      queueStatus: queuedStatus.add,
    );

    expect(queuedStatus.length, equals(1));
  });

  test('roll contact can reapply on a new activation', () {
    final world = EcsWorld();
    final player = _spawnPlayer(world);
    final enemy = _spawnEnemy(world);
    final phaseSystem = ActiveAbilityPhaseSystem();
    final impactSystem = MobilityImpactSystem(
      abilities: const AbilityCatalog(),
    );
    final broadphase = BroadphaseGrid(
      index: GridIndex2D(
        cellSize: const SpatialGridTuning().broadphaseCellSize,
      ),
    );
    final queuedStatus = <StatusRequest>[];

    world.activeAbility.set(
      player,
      id: 'eloise.roll',
      slot: AbilitySlot.mobility,
      commitTick: 1,
      windupTicks: 0,
      activeTicks: 8,
      recoveryTicks: 0,
      facingDir: Facing.right,
    );
    phaseSystem.step(world, currentTick: 1);
    broadphase.rebuild(world);
    impactSystem.step(
      world,
      broadphase,
      currentTick: 1,
      queueStatus: queuedStatus.add,
    );
    expect(queuedStatus.length, equals(1));

    world.activeAbility.set(
      player,
      id: 'eloise.roll',
      slot: AbilitySlot.mobility,
      commitTick: 20,
      windupTicks: 0,
      activeTicks: 8,
      recoveryTicks: 0,
      facingDir: Facing.right,
    );
    phaseSystem.step(world, currentTick: 20);
    broadphase.rebuild(world);
    impactSystem.step(
      world,
      broadphase,
      currentTick: 20,
      queueStatus: queuedStatus.add,
    );

    expect(queuedStatus.length, equals(2));
    expect(queuedStatus.last.target, equals(enemy));
    expect(queuedStatus.last.profileId, equals(StatusProfileId.stunOnHit));
  });

  test('dash has no authored mobility contact effects', () {
    final world = EcsWorld();
    final player = _spawnPlayer(world);
    _spawnEnemy(world);
    final phaseSystem = ActiveAbilityPhaseSystem();
    final impactSystem = MobilityImpactSystem(
      abilities: const AbilityCatalog(),
    );
    final broadphase = BroadphaseGrid(
      index: GridIndex2D(
        cellSize: const SpatialGridTuning().broadphaseCellSize,
      ),
    );
    final queuedStatus = <StatusRequest>[];

    world.activeAbility.set(
      player,
      id: 'eloise.dash',
      slot: AbilitySlot.mobility,
      commitTick: 1,
      windupTicks: 0,
      activeTicks: 8,
      recoveryTicks: 0,
      facingDir: Facing.right,
    );
    phaseSystem.step(world, currentTick: 1);
    broadphase.rebuild(world);
    impactSystem.step(
      world,
      broadphase,
      currentTick: 1,
      queueStatus: queuedStatus.add,
    );

    expect(queuedStatus, isEmpty);
    expect(world.damageQueue.length, equals(0));
  });

  test('mobility impact can queue damage for future dash-attack abilities', () {
    final world = EcsWorld();
    final player = _spawnPlayer(world);
    final enemy = _spawnEnemy(world);
    final phaseSystem = ActiveAbilityPhaseSystem();
    final impactSystem = MobilityImpactSystem(
      abilities: const _TestAbilities(),
    );
    final broadphase = BroadphaseGrid(
      index: GridIndex2D(
        cellSize: const SpatialGridTuning().broadphaseCellSize,
      ),
    );

    world.activeAbility.set(
      player,
      id: 'test.mobility_ram',
      slot: AbilitySlot.mobility,
      commitTick: 1,
      windupTicks: 0,
      activeTicks: 8,
      recoveryTicks: 0,
      facingDir: Facing.right,
    );

    phaseSystem.step(world, currentTick: 1);
    broadphase.rebuild(world);
    impactSystem.step(world, broadphase, currentTick: 1);

    expect(world.damageQueue.length, equals(1));
    expect(world.damageQueue.target.single, equals(enemy));
    expect(world.damageQueue.amount100.single, equals(750));
    expect(world.damageQueue.damageType.single, equals(DamageType.physical));
    expect(
      world.damageQueue.sourceKind.single,
      equals(DeathSourceKind.meleeHitbox),
    );

    phaseSystem.step(world, currentTick: 2);
    broadphase.rebuild(world);
    impactSystem.step(world, broadphase, currentTick: 2);

    expect(world.damageQueue.length, equals(1));
  });
}

int _spawnPlayer(EcsWorld world) {
  return EntityFactory(world).createPlayer(
    posX: 100,
    posY: 100,
    velX: 0,
    velY: 0,
    facing: Facing.right,
    grounded: true,
    body: const BodyDef(isKinematic: true, useGravity: false),
    collider: const ColliderAabbDef(halfX: 8, halfY: 8),
    health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
    mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
    stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
  );
}

int _spawnEnemy(EcsWorld world) {
  final enemy = world.createEntity();
  world.transform.add(enemy, posX: 100, posY: 100, velX: 0, velY: 0);
  world.colliderAabb.add(enemy, const ColliderAabbDef(halfX: 8, halfY: 8));
  world.health.add(
    enemy,
    const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
  );
  world.faction.add(enemy, const FactionDef(faction: Faction.enemy));
  return enemy;
}

class _TestAbilities extends AbilityCatalog {
  const _TestAbilities();

  @override
  AbilityDef? resolve(AbilityKey key) {
    if (key == 'test.mobility_ram') {
      return AbilityDef(
        id: 'test.mobility_ram',
        category: AbilityCategory.mobility,
        allowedSlots: {AbilitySlot.mobility},
        inputLifecycle: AbilityInputLifecycle.tap,
        windupTicks: 0,
        activeTicks: 8,
        recoveryTicks: 0,
        cooldownTicks: 30,
        mobilityImpact: const MobilityImpactDef(
          hitPolicy: HitPolicy.oncePerTarget,
          damage100: 750,
          damageType: DamageType.physical,
        ),
        animKey: AnimKey.dash,
      );
    }
    return super.resolve(key);
  }
}
