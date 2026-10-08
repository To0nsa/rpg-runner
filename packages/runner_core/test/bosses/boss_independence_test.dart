import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/collision/terrain/terrain_motion_request.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/systems/active_ability_phase_system.dart';
import 'package:runner_core/ecs/systems/boss_combat_system.dart';
import 'package:runner_core/ecs/systems/boss_utility_system.dart';
import 'package:runner_core/ecs/systems/control_lock_system.dart';
import 'package:runner_core/ecs/systems/cooldown_system.dart';
import 'package:runner_core/ecs/systems/enemy_cast_system.dart';
import 'package:runner_core/ecs/systems/shoggoth_combat_system.dart';
import 'package:runner_core/ecs/systems/voidborn_goddess_combat_system.dart';
import 'package:runner_core/ecs/systems/voidcaller_combat_system.dart';
import 'package:runner_core/ecs/systems/world_motion_authority.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/spawn_service.dart';
import 'package:runner_core/util/vec2.dart';
import 'package:test/test.dart';

void main() {
  for (final id in [
    EnemyId.voidbornGoddess,
    EnemyId.shoggoth,
    EnemyId.voidcaller,
  ]) {
    test(
      '${id.name} system affects only its actors, with separate sequences',
      () {
        final f = _Fixture(60);
        final bosses = <int, EnemyId>{};
        for (final kind in [
          EnemyId.voidbornGoddess,
          EnemyId.shoggoth,
          EnemyId.voidcaller,
        ]) {
          bosses[f.actor(kind, 0)] = kind;
          bosses[f.actor(kind, 20)] = kind;
        }
        final matching = bosses.keys
            .where((actor) => bosses[actor] == id)
            .toList();
        // One instance waits on cooldown; its sibling may commit independently.
        f.world.cooldown.startCooldown(matching.first, 0, 100);
        final BossCombatSystem system = switch (id) {
          EnemyId.voidbornGoddess => VoidbornGoddessCombatSystem(
            tickHz: 60,
            castCommitter: f.casts,
            utilities: f.utilities,
          ),
          EnemyId.shoggoth => ShoggothCombatSystem(
            tickHz: 60,
            castCommitter: f.casts,
            utilities: f.utilities,
          ),
          EnemyId.voidcaller => VoidcallerCombatSystem(
            tickHz: 60,
            castCommitter: f.casts,
            utilities: f.utilities,
          ),
          _ => throw StateError('not a test boss'),
        };
        system.step(f.world, player: f.player, currentTick: 10);
        for (final actor in bosses.keys) {
          final committed = actor == matching.last;
          expect(f.world.activeAbility.hasActiveAbility(actor), committed);
          expect(
            f.world.bossCombat.actionIndex[f.world.bossCombat.indexOf(actor)],
            committed ? 1 : 0,
          );
          if (bosses[actor] != id) {
            expect(f.world.cooldown.isOnCooldown(actor, 0), isFalse);
          }
        }
      },
    );
  }

  for (final hz in [30, 60, 90]) {
    test(
      'Goddess repeats claws and casts without standalone teleports at $hz Hz',
      () {
        final f = _Fixture(hz);
        final boss = f.actor(EnemyId.voidbornGoddess, 400);
        f.world.actorMotionBounds.add(
          boss,
          TerrainHorizontalBounds(minXTicks: 0, maxXTicks: 600 * 1024),
        );
        final system = VoidbornGoddessCombatSystem(
          tickHz: hz,
          castCommitter: f.casts,
          utilities: f.utilities,
        );
        final cooldowns = CooldownSystem();
        final locks = ControlLockSystem();
        const phases = ActiveAbilityPhaseSystem();
        final state = f.world.bossCombat.indexOf(boss);
        final active = f.world.activeAbility.indexOf(boss);
        final actions = <String>[];

        // Exercise real action/cooldown clocks with a stationary close target;
        // terrain placement and barrage execution have separate integration tests.
        for (var tick = 1; tick <= hz * 50; tick++) {
          cooldowns.step(f.world);
          locks.step(f.world, currentTick: tick);
          phases.step(f.world, currentTick: tick);
          final sequence = f.world.bossCombat.actionIndex[state];
          system.step(f.world, player: f.player, currentTick: tick);
          if (f.world.bossCombat.actionIndex[state] == sequence) continue;
          final key = f.world.activeAbility.abilityId[active]!;
          actions.add(key);
          if (actions.length == 1) {
            expect(key, 'goddess.orb');
            // Miss the opening claw opportunity, then enter melee range.
            f.world.transform.setPosXY(f.player, 335, 0);
          }
        }

        expect(
          actions.where((key) => key == 'goddess.claw_combo').length,
          greaterThanOrEqualTo(4),
        );
        expect(actions, containsAll(['goddess.orb', 'goddess.eruption']));
        expect(actions.toSet(), {
          'goddess.claw_combo',
          'goddess.orb',
          'goddess.eruption',
        });
      },
    );

    for (final (distance, height, sequence, expected) in [
      (68.0, 50.0, 3, 'goddess.claw_combo'),
      (68.01, 0.0, 3, 'goddess.eruption'),
      (65.0, 50.01, 3, 'goddess.eruption'),
      (65.0, 0.0, 4, 'goddess.orb'),
    ]) {
      test(
        'Goddess chooses $expected at ($distance, $height), turn $sequence, $hz Hz',
        () {
          final f = _Fixture(hz);
          final boss = f.actor(EnemyId.voidbornGoddess, 400);
          f.world.actorMotionBounds.add(
            boss,
            TerrainHorizontalBounds(minXTicks: 0, maxXTicks: 600 * 1024),
          );
          f.world.transform.setPosXY(f.player, 400 - distance, height);
          f.world.bossCombat.actionIndex[f.world.bossCombat.indexOf(boss)] =
              sequence;
          VoidbornGoddessCombatSystem(
            tickHz: hz,
            castCommitter: f.casts,
            utilities: f.utilities,
          ).step(f.world, player: f.player, currentTick: 10);
          expect(
            f.world.activeAbility.abilityId[f.world.activeAbility.indexOf(
              boss,
            )],
            expected,
          );
        },
      );
    }

    for (final interruption in ['cancelled', 'replaced', 'dead']) {
      test('Goddess cancels a $interruption barrage at $hz Hz', () {
        final motion = _BarrageMotion();
        final f = _Fixture(hz, motion: motion);
        final boss = f.actor(EnemyId.voidbornGoddess, 400);
        f.world.actorMotionBounds.add(
          boss,
          TerrainHorizontalBounds(minXTicks: 0, maxXTicks: 600 * 1024),
        );
        f.world.bossCombat.actionIndex[f.world.bossCombat.indexOf(boss)] = 1;
        final system = VoidbornGoddessCombatSystem(
          tickHz: hz,
          castCommitter: f.casts,
          utilities: f.utilities,
        );
        system.step(f.world, player: f.player, currentTick: 10);
        expect(f.world.goddessBarrage.has(boss), isTrue);
        system.prepareBarrage(f.world, currentTick: 11);
        system.composeMotion(f.world);
        expect(f.world.gravityControl.has(boss), isTrue);
        final ti = f.world.transform.indexOf(boss);
        final cornerX = f.world.transform.posX[ti];
        final cornerY = f.world.transform.posY[ti];
        final firstHand = f
            .world
            .goddessBarrage
            .firstHandTick[f.world.goddessBarrage.indexOf(boss)];
        switch (interruption) {
          case 'cancelled':
            f.world.activeAbility.clear(boss);
          case 'replaced':
            f.world.activeAbility.startTick[f.world.activeAbility.indexOf(
              boss,
            )]++;
          case 'dead':
            f.world.health.hp[f.world.health.indexOf(boss)] = 0;
        }
        system.prepareBarrage(f.world, currentTick: firstHand);
        expect(f.world.goddessBarrage.has(boss), isFalse);
        expect(f.world.gravityControl.has(boss), isFalse);
        expect(
          f.world.targetPointIntent.tick[f.world.targetPointIntent.indexOf(
            boss,
          )],
          -1,
        );
        if (interruption != 'dead') {
          expect(f.world.transform.posX[ti], cornerX);
          expect(f.world.transform.posY[ti], cornerY);
        }
      });
    }

    for (final (id, key) in [
      (EnemyId.shoggoth, 'shoggoth.teleport'),
      (EnemyId.shoggoth, 'shoggoth.summon'),
      (EnemyId.voidcaller, 'voidcaller.summon'),
    ]) {
      for (final replaced in [false, true]) {
        test(
          '$key does not execute a ${replaced ? 'replaced' : 'cancelled'} commit at $hz Hz',
          () {
            final f = _Fixture(hz);
            final boss = f.actor(id, 0);
            f.world.actorMotionBounds.add(
              boss,
              TerrainHorizontalBounds(minXTicks: -1000000, maxXTicks: 1000000),
            );
            expect(
              f.utilities.commit(
                f.world,
                boss: boss,
                ability: AbilityCatalog.shared.resolve(key)!,
                targetX: 300,
                tick: 10,
              ),
              isTrue,
            );
            final state = f.world.bossCombat.indexOf(boss);
            final execute = f.world.bossCombat.executeTick[state];
            if (replaced) {
              // The same ability committed later must not revive an old intent.
              f.world.activeAbility.startTick[f.world.activeAbility.indexOf(
                boss,
              )]++;
            } else {
              f.world.activeAbility.clear(boss);
            }
            f.utilities.prepare(
              f.world,
              player: f.player,
              currentTick: execute,
            );
            f.utilities.executeTeleports(
              f.world,
              player: f.player,
              currentTick: execute,
            );
            expect(f.world.bossCombat.executeTick[state], -1);
            expect(f.world.bossSummon.denseEntities, isEmpty);
            expect(f.world.transform.posX[f.world.transform.indexOf(boss)], 0);
          },
        );
      }
    }
  }
  test('Goddess barrage state is removed before its entity ID is recycled', () {
    final world = EcsWorld(seed: 7);
    final old = world.createEntity();
    final i = world.goddessBarrage.addEntity(old);
    world.goddessBarrage.commitTick[i] = 7;
    world.goddessBarrage.hovering[i] = true;
    world.destroyEntity(old);
    final next = world.createEntity();
    expect(next, old);
    expect(world.goddessBarrage.has(next), isFalse);
  });
}

class _Fixture {
  _Fixture(int hz, {WorldMotionAuthority? motion}) {
    player = actor(EnemyId.grojib, 300);
    world.faction.faction[world.faction.indexOf(player)] = Faction.player;
    casts = AiCastCommitter(
      tickHz: hz,
      projectiles: const ProjectileCatalog(),
      surfaceTarget: (x, y) => Vec2(x, 24),
    );
    utilities = BossUtilitySystem(
      tickHz: hz,
      motion: motion ?? _ForbiddenMotion(),
      spawns: _ForbiddenSpawns(),
      groundTopY: 24,
    );
  }
  final world = EcsWorld(seed: 7);
  late final int player;
  late final AiCastCommitter casts;
  late final BossUtilitySystem utilities;

  int actor(EnemyId id, double x) {
    final a = const EnemyCatalog().get(id);
    return EntityFactory(world).createEnemy(
      enemyId: id,
      posX: x,
      posY: 0,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      body: a.body,
      collider: a.collider,
      health: a.health,
      mana: a.mana,
      stamina: a.stamina,
    );
  }
}

// These tests must reject stale intents before querying placement or spawning.
class _ForbiddenMotion implements WorldMotionAuthority {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected terrain mutation/query');
}

class _ForbiddenSpawns implements SpawnService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected spawn');
}

// Lifecycle tests record teleport commits; real terrain is covered by the
// GameCore barrage integration test.
class _BarrageMotion extends _ForbiddenMotion {
  @override
  WorldBodyPlacementOrigin beginBodyTeleport(EcsWorld world, int entity) {
    final ti = world.transform.indexOf(entity);
    return WorldBodyPlacementOrigin(
      bodyX: world.transform.posX[ti],
      bodyY: world.transform.posY[ti],
      facing: Facing.left,
    );
  }

  @override
  bool tryCommitBodyTeleport(
    EcsWorld world,
    int entity, {
    required double bodyX,
    required double bodyY,
    required Facing facing,
  }) {
    world.transform.setPosXY(entity, bodyX, bodyY);
    return true;
  }
}
