import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/collision/terrain/terrain_motion_request.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/systems/boss_combat_system.dart';
import 'package:runner_core/ecs/systems/boss_utility_system.dart';
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
    for (final (id, key) in [
      (EnemyId.voidbornGoddess, 'goddess.teleport'),
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
}

class _Fixture {
  _Fixture(int hz) {
    player = actor(EnemyId.grojib, 300);
    world.faction.faction[world.faction.indexOf(player)] = Faction.player;
    casts = AiCastCommitter(
      tickHz: hz,
      projectiles: const ProjectileCatalog(),
      surfaceTarget: (x, y) => Vec2(x, 24),
    );
    utilities = BossUtilitySystem(
      tickHz: hz,
      motion: _ForbiddenMotion(),
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
