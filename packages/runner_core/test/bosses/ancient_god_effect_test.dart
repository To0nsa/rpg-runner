import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/combat/ai_cast_aim_policy.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/world_contact_capsule_store.dart';
import 'package:runner_core/ecs/systems/enemy_cast_system.dart';
import 'package:runner_core/ecs/systems/hitbox_damage_system.dart';
import 'package:runner_core/ecs/systems/hitbox_follow_owner_system.dart';
import 'package:runner_core/ecs/systems/target_point_impact_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/util/vec2.dart';
import 'package:test/test.dart';

import '../test_support/combat_pose.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    for (final (id, key, warningFrames) in [
      (EnemyId.voidbornGoddess, 'goddess.eruption', 10),
      (EnemyId.voidcaller, 'voidcaller.vertical_beam', 5),
      (EnemyId.voidcaller, 'voidcaller.diagonal_beam', 5),
    ]) {
      test('$key captures terrain, warns and hits once at $hz Hz', () {
        final world = EcsWorld(seed: 7);
        final factory = EntityFactory(world);
        int actor(EnemyId id, double x) {
          final a = const EnemyCatalog().get(id);
          final collider = id == EnemyId.grojib
              ? const ColliderAabbDef(halfX: 8, halfY: 24)
              : a.collider;
          final entity = factory.createEnemy(
            enemyId: id,
            posX: x,
            posY: 0,
            velX: 0,
            velY: 0,
            facing: Facing.right,
            body: a.body,
            collider: collider,
            health: a.health,
            mana: a.mana,
            stamina: a.stamina,
          );
          world.worldContactCapsule.add(
            entity,
            WorldContactCapsuleDef.fromAabb(collider),
          );
          return entity;
        }

        final caster = actor(id, 0), player = actor(EnemyId.grojib, 300);
        world.faction.faction[world.faction.indexOf(player)] = Faction.player;
        final ability = AbilityCatalog.shared.resolve(key)!;
        final committer = AiCastCommitter(
          tickHz: hz,
          projectiles: const ProjectileCatalog(),
          surfaceTarget: (x, y) => Vec2(x, 24),
        );
        expect(
          committer.commit(
            world,
            actor: caster,
            castAbility: ability,
            sourceX: 0,
            sourceY: 0,
            targetX: 300,
            targetY: 0,
            targetVelX: 0,
            targetVelY: 0,
            aimPolicy: AiCastAimPolicy.targetCenter,
            casterOriginOffset: 0,
            currentTick: 10,
          ),
          isTrue,
        );
        final intents = world.targetPointIntent, ii = intents.indexOf(caster);
        final tick = intents.tick[ii], step = intents.frameStepTicks[ii];
        world.transform.setPosXY(player, 400, -100);
        TargetPointImpactSystem().step(world, currentTick: tick);
        final hitbox = world.hitbox.denseEntities.single;
        final ti = world.transform.indexOf(hitbox);
        expect(world.transform.posX[ti], 300);
        expect(world.transform.posY[ti], 24);
        final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 64));
        void hit(int tick) {
          resolveCombatPoses(world, tick, tickHz: hz);
          HitboxFollowOwnerSystem(tickHz: hz).step(world, currentTick: tick);
          grid.rebuild(world);
          HitboxDamageSystem().step(world, grid, currentTick: tick);
        }

        world.transform.setPosXY(player, 300, 0);
        for (var t = tick; t < tick + warningFrames * step; t++) {
          hit(t);
          expect(
            world.damageQueue.length,
            0,
            reason: 'harmless warning tick $t',
          );
        }
        final damageTick = tick + warningFrames * step;
        world.transform.setPosXY(player, 400, 0);
        hit(damageTick);
        expect(world.damageQueue.length, 0);
        world.transform.setPosXY(player, 300, 0);
        hit(damageTick);
        expect(world.damageQueue.target, [player]);
        expect(world.damageQueue.amount100, [700]);
        hit(damageTick + 1);
        expect(world.damageQueue.length, 1);
      });
    }
  }
}
