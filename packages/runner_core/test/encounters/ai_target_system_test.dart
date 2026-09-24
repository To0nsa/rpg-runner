import 'package:runner_core/combat/ai_target_policy.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/ecs/combat_target.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/stores/body_store.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/faction_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/mana_store.dart';
import 'package:runner_core/ecs/stores/stamina_store.dart';
import 'package:runner_core/ecs/systems/ai_target_system.dart';
import 'package:runner_core/ecs/systems/enemy_cast_system.dart';
import 'package:runner_core/ecs/systems/enemy_engagement_system.dart';
import 'package:runner_core/ecs/systems/enemy_melee_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/tuning/flying_enemy_tuning.dart';
import 'package:runner_core/tuning/ground_enemy_tuning.dart';
import 'package:test/test.dart';

int actor(EcsWorld world, double x, {Faction faction = Faction.player}) {
  final id = world.createEntity();
  world.transform.add(id, posX: x, posY: 0, velX: 0, velY: 0);
  world.health.add(
    id,
    const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
  );
  world.faction.add(id, FactionDef(faction: faction));
  return id;
}

void main() {
  test('ground engagement and committed melee share the selected actor', () {
    final world = EcsWorld();
    final enemy = _enemy(world, EnemyId.grojib);
    final player = actor(world, -200);
    final npc = actor(world, 12);
    world.aiTarget.configure(
      enemy,
      targetPolicy: AiTargetPolicy.preferEncounterNpcs,
      candidates: [npc],
    );
    AiTargetSystem().step(world, player: player);
    final tuning = GroundEnemyTuningDerived.from(
      const GroundEnemyTuning(),
      tickHz: 60,
    );
    final engagement = EnemyEngagementSystem(groundEnemyTuning: tuning);
    world.navIntent.navTargetX[world.navIntent.indexOf(enemy)] = 12;
    engagement.step(world, player: player, currentTick: 1);
    engagement.step(world, player: player, currentTick: 2);
    EnemyMeleeSystem(groundEnemyTuning: tuning)
        .step(world, player: player, currentTick: 2);
    final intent = world.meleeIntent.indexOf(enemy);
    expect(world.meleeIntent.abilityId[intent], isNotNull);
    expect(world.meleeIntent.dirX[intent], greaterThan(0));
  });
  test(
    'owned roster excludes foreign allies and preserves a same-tier target',
    () {
      final world = EcsWorld();
      final enemy = actor(world, 0, faction: Faction.enemy);
      final player = actor(world, 1);
      final first = actor(world, 20);
      final second = actor(world, -20);
      actor(world, 0.5); // A nearby NPC owned by another encounter.
      world.aiTarget.configure(
        enemy,
        targetPolicy: AiTargetPolicy.preferEncounterNpcs,
        candidates: [second, first],
      );
      final selector = AiTargetSystem();
      selector.step(world, player: player);
      expect(
        combatTarget(world, enemy, player),
        first,
      ); // Stable ID breaks the tie.
      world.transform.posX[world.transform.indexOf(second)] = 2;
      selector.step(world, player: player);
      expect(combatTarget(world, enemy, player), first);
      world.health.hp[world.health.indexOf(first)] = 0;
      selector.step(world, player: player);
      expect(combatTarget(world, enemy, player), second);
      world.health.hp[world.health.indexOf(second)] = 0;
      selector.step(world, player: player);
      expect(combatTarget(world, enemy, player), player);
    },
  );

  test(
    'policy overrides, preferred tier preemption and explicit no-target',
    () {
      final world = EcsWorld();
      final enemy = actor(world, 0, faction: Faction.enemy);
      final player = actor(world, 50);
      final npc = actor(world, 5);
      final selector = AiTargetSystem();
      world.aiTarget.configure(
        enemy,
        targetPolicy: AiTargetPolicy.playerOnly,
        candidates: [npc],
      );
      selector.step(world, player: player);
      expect(combatTarget(world, enemy, player), player);
      world.aiTarget.configure(
        enemy,
        targetPolicy: AiTargetPolicy.nearestOpponent,
        candidates: [npc],
      );
      selector.step(world, player: player);
      expect(combatTarget(world, enemy, player), npc);
      world.aiTarget.configure(
        enemy,
        targetPolicy: AiTargetPolicy.preferEncounterNpcs,
        candidates: [npc],
        perceptionRange: 10,
      );
      world.transform.posX[world.transform.indexOf(npc)] = 20;
      selector.step(world, player: player);
      expect(combatTarget(world, enemy, player), player);
      world.transform.posX[world.transform.indexOf(npc)] = 5;
      selector.step(world, player: player);
      expect(combatTarget(world, enemy, player), npc);
      world.aiTarget.configure(
        enemy,
        targetPolicy: AiTargetPolicy.nearestOpponent,
        candidates: [],
        playerFallback: false,
      );
      selector.step(world, player: player);
      expect(combatTarget(world, enemy, player), isNull);
    },
  );

  test('destruction invalidates references before entity ID reuse', () {
    final world = EcsWorld();
    final enemy = actor(world, 0, faction: Faction.enemy);
    final player = actor(world, 100);
    final npc = actor(world, 10);
    world.aiTarget.configure(
      enemy,
      targetPolicy: AiTargetPolicy.preferEncounterNpcs,
      candidates: [npc],
    );
    final selector = AiTargetSystem()..step(world, player: player);
    world.destroyEntity(npc);
    expect(actor(world, 1), npc);
    selector.step(world, player: player);
    expect(combatTarget(world, enemy, player), player);
    world.aiTarget.removeEntity(
      enemy,
    ); // Encounter release restores ordinary AI.
    expect(combatTarget(world, enemy, player), player);
  });

  test('blocked-route evidence is local and expires on target movement', () {
    final world = EcsWorld();
    final a = actor(world, 0, faction: Faction.enemy);
    final b = actor(world, 0, faction: Faction.enemy);
    final player = actor(world, 100);
    final npc = actor(world, 10);
    for (final enemy in [a, b]) {
      world.aiTarget.configure(
        enemy,
        targetPolicy: AiTargetPolicy.preferEncounterNpcs,
        candidates: [npc],
      );
    }
    world.aiTarget.unreachable[world.aiTarget.indexOf(a)][npc] =
        targetNavigationEvidence(world, a, npc);
    final selector = AiTargetSystem()..step(world, player: player);
    expect(combatTarget(world, a, player), player);
    expect(combatTarget(world, b, player), npc);
    world.transform.posX[world.transform.indexOf(npc)] += 1;
    selector.step(world, player: player);
    expect(combatTarget(world, a, player), npc);
  });

  for (final type in [EnemyId.unocoDemon, EnemyId.derf]) {
    test('$type aims at its selected NPC and preserves the committed cast', () {
      final world = EcsWorld();
      final enemy = _enemy(world, type);
      final player = actor(world, -100);
      final npc = actor(world, 100);
      world.aiTarget.configure(
        enemy,
        targetPolicy: AiTargetPolicy.preferEncounterNpcs,
        candidates: [npc],
      );
      final selector = AiTargetSystem()..step(world, player: player);
      final casts = EnemyCastSystem(
        unocoDemonTuning: UnocoDemonTuningDerived.from(
          const UnocoDemonTuning(),
          tickHz: 60,
        ),
        enemyCatalog: const EnemyCatalog(),
        projectiles: const ProjectileCatalog(),
      );
      casts.step(world, player: player, currentTick: 1);
      double aim() => type == EnemyId.derf
          ? world.targetPointIntent.targetX[world.targetPointIntent.indexOf(
              enemy,
            )]
          : world.projectileIntent.dirX[world.projectileIntent.indexOf(enemy)];
      int executeAt() => type == EnemyId.derf
          ? world.targetPointIntent.tick[world.targetPointIntent.indexOf(enemy)]
          : world.projectileIntent.tick[world.projectileIntent.indexOf(enemy)];
      expect(aim(), greaterThan(0));
      final executeTick = executeAt();
      world.health.hp[world.health.indexOf(npc)] = 0;
      selector.step(world, player: player);
      casts.step(world, player: player, currentTick: 2);
      expect(combatTarget(world, enemy, player), player);
      expect(aim(), greaterThan(0));
      expect(executeAt(), executeTick);
    });
  }
}

int _enemy(EcsWorld world, EnemyId type) => EntityFactory(world).createEnemy(
  enemyId: type,
  posX: 0,
  posY: 0,
  velX: 0,
  velY: 0,
  facing: Facing.left,
  body: const BodyDef(isKinematic: true, useGravity: false),
  collider: const ColliderAabbDef(halfX: 8, halfY: 8),
  health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
  mana: const ManaDef(mana: 10000, manaMax: 10000, regenPerSecond100: 0),
  stamina: const StaminaDef(
    stamina: 10000,
    staminaMax: 10000,
    regenPerSecond100: 0,
  ),
);
