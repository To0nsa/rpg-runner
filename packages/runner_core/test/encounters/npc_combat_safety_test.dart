import 'package:runner_core/combat/damage.dart';
import 'package:runner_core/combat/damage_credit.dart';
import 'package:runner_core/combat/damage_type.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/combat/status/status.dart';
import 'package:runner_core/ecs/combat_target.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/faction_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/hitbox_store.dart';
import 'package:runner_core/ecs/stores/status/dot_store.dart';
import 'package:runner_core/ecs/stores/status/weaken_store.dart';
import 'package:runner_core/ecs/stores/world_contact_capsule_store.dart';
import 'package:runner_core/ecs/systems/damage_system.dart';
import 'package:runner_core/ecs/systems/npc_combat_lifecycle.dart';
import 'package:runner_core/ecs/systems/projectile_hit_system.dart';
import 'package:runner_core/ecs/systems/status_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/projectiles/spawn_projectile_item.dart';
import 'package:runner_core/weapons/weapon_proc.dart';
import 'package:test/test.dart';

void main() {
  test(
    'player projectile and DoT retain credit after owner destruction and reuse',
    () {
      final f = _Fixture();
      final player = f.actor(Faction.player, x: 0);
      f.world.playerInput.add(player);
      final enemy = f.actor(Faction.enemy);
      f.projectile(player, Faction.player);
      f.world.destroyEntity(player);
      expect(f.actor(Faction.player, x: 0), player);
      // A recycled source's modifiers must never be read by a later DoT pulse.
      f.world.weaken.add(
        player,
        const WeakenDef(ticksLeft: 1000, magnitude: 5000),
      );
      f.hit();
      expect(f.world.damageQueue.credit.single, DamageCredit.player);
      f.apply(1);
      expect(f.credits, [DamageCredit.player]);
      expect(f.world.dot.credit.single.single, DamageCredit.player);
      final hp = f.world.health.hp[f.world.health.indexOf(enemy)];
      for (var i = 0; i < 60; i++) {
        f.status.tickExisting(f.world);
      }
      expect(f.world.damageQueue.sourceEntity.single, isNull);
      expect(f.world.damageQueue.amount100.single, 200);
      f.apply(61);
      expect(f.world.health.hp[f.world.health.indexOf(enemy)], hp - 200);
      expect(f.credits, [DamageCredit.player, DamageCredit.player]);
    },
  );

  test(
    'allied NPC projectiles and their status damage never earn player credit',
    () {
      final f = _Fixture();
      final npc = f.actor(Faction.player, x: 0, npc: true);
      f.actor(Faction.enemy);
      f.projectile(npc, Faction.player);
      f.hit();
      f.apply(0);
      expect(f.credits, [DamageCredit.none]);
      expect(f.world.dot.credit.single.single, DamageCredit.none);
    },
  );

  test(
    'only accepted stronger or equal-duration-extension DoTs replace credit',
    () {
      final f = _Fixture();
      final target = f.actor(Faction.enemy);
      void poison(DamageCredit credit, int tick) {
        f.status.queue(
          StatusRequest(
            target: target,
            profileId: StatusProfileId.poisonOnHit,
            credit: credit,
          ),
        );
        f.status.applyQueued(f.world, currentTick: tick);
      }

      poison(DamageCredit.player, 0);
      poison(DamageCredit.none, 0);
      expect(f.world.dot.credit.single.single, DamageCredit.player);
      f.status.tickExisting(f.world);
      poison(DamageCredit.none, 1);
      expect(f.world.dot.credit.single.single, DamageCredit.none);
      expect(f.world.dot.periodTicksLeft.single.single, 59);
      f.world.dot.dps100[0][0] = 300;
      poison(DamageCredit.player, 2);
      expect(f.world.dot.credit.single.single, DamageCredit.none);
      f.world.dot.dps100[0][0] = 100;
      poison(DamageCredit.player, 3);
      expect(f.world.dot.credit.single.single, DamageCredit.player);
      expect(f.world.dot.periodTicksLeft.single.single, 60);
    },
  );

  test(
    'participation reports actual HP lost and rejects invulnerable hits',
    () {
      final f = _Fixture();
      final target = f.actor(Faction.enemy);
      f.world.invulnerability.add(target);
      f.world.invulnerability.ticksLeft[0] = 1;
      void queue() => f.world.damageQueue.add(
        DamageRequest(
          target: target,
          amount100: 10000,
          credit: DamageCredit.player,
        ),
      );
      queue();
      f.apply(0);
      expect(f.credits, isEmpty);
      f.world.invulnerability.ticksLeft[0] = 0;
      queue();
      f.apply(1);
      expect(f.losses, [5000]);
      queue();
      f.apply(2);
      expect(f.losses, [5000]);
    },
  );

  test('safe survivors reject queued damage and harmful status without absorbing shots', () {
    final f = _Fixture();
    final npc = f.actor(Faction.player, npc: true);
    final enemy = f.actor(Faction.enemy, x: 0);
    f.world.dot.add(
      npc,
      const DotDef(
        damageType: DamageType.poison,
        ticksLeft: 20,
        periodTicks: 1,
        dps100: 12000,
      ),
    );
    f.world.damageQueue.add(DamageRequest(target: npc, amount100: 1000));
    f.status.queue(
      StatusRequest(target: npc, profileId: StatusProfileId.stunOnHit),
    );
    f.status.queue(
      StatusRequest(target: npc, profileId: StatusProfileId.poisonOnHit),
    );
    protectNpc(f.world, npc);
    expect(isLivingCombatActor(f.world, npc), isFalse);
    expect(f.world.worldContactCapsule.has(npc), isTrue);
    f.status.tickExisting(f.world);
    f.apply(0);
    expect(f.world.health.hp[f.world.health.indexOf(npc)], 5000);
    expect(f.world.dot.has(npc), isFalse);
    expect(f.world.controlLock.has(npc), isFalse);
    final shot = f.projectile(enemy, Faction.enemy);
    f.hit();
    expect(f.world.projectile.has(shot), isTrue);
    expect(f.world.damageQueue.length, 0);
    // An active ally in the same position still receives ambient damage.
    final active = f.actor(Faction.player, npc: true);
    f.hit();
    expect(f.world.projectile.has(shot), isFalse);
    expect(f.world.damageQueue.target.single, active);
  });

  test('protection cancels attached attacks and intents, retaining detached effects', () {
    final f = _Fixture();
    final npc = f.actor(Faction.player, npc: true);
    f.world.meleeIntent.add(npc);
    f.world.meleeIntent.tick[0] = 7;
    f.world.activeAbility.add(npc);
    f.world.activeAbility.abilityId[0] = 'grojib.strike';
    int box(HitboxAttachment attachment) {
      final entity = f.world.createEntity();
      f.world.hitbox.add(
        entity,
        HitboxDef(
          owner: npc,
          faction: Faction.player,
          damage100: 100,
          damageType: DamageType.physical,
          attachment: attachment,
          halfX: 10,
          halfY: 5,
          offsetX: 10,
          offsetY: 0,
          dirX: 1,
          dirY: 0,
        ),
      );
      return entity;
    }

    final attached = box(HitboxAttachment.followOwner);
    final detached = box(HitboxAttachment.worldAnchor);
    final shot = f.projectile(npc, Faction.player);
    protectNpc(f.world, npc);
    protectNpc(f.world, npc);
    expect(f.world.meleeIntent.tick[0], -1);
    expect(f.world.activeAbility.abilityId[0], isNull);
    expect(f.world.hitbox.has(attached), isFalse);
    expect(f.world.hitbox.has(detached), isTrue);
    expect(f.world.projectile.has(shot), isTrue);
  });
}

class _Fixture {
  final world = EcsWorld();
  final status = StatusSystem(tickHz: 60);
  final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);
  final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 32));
  final credits = <DamageCredit>[];
  final losses = <int>[];

  int actor(Faction faction, {double x = 100, bool npc = false}) {
    final id = world.createEntity();
    world.transform.add(id, posX: x, posY: 100, velX: 0, velY: 0);
    world.health.add(
      id,
      const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
    );
    world.faction.add(id, FactionDef(faction: faction));
    world.colliderAabb.add(id, const ColliderAabbDef(halfX: 4, halfY: 10));
    world.worldContactCapsule.add(
      id,
      WorldContactCapsuleDef(radius: 4, verticalHalfSegment: 6),
    );
    world.statModifier.add(id);
    if (npc) {
      world.npc.add(id, id: NpcId.warrior, chunkStartX: 0, chunkEndX: 600);
    }
    return id;
  }

  int projectile(int owner, Faction faction) => spawnProjectileFromCaster(
    world,
    tickHz: 60,
    projectileId: ProjectileId.fireBolt,
    projectile: const ProjectileCatalog().get(ProjectileId.fireBolt),
    faction: faction,
    owner: owner,
    casterX: 100,
    casterY: 100,
    originOffset: 0,
    dirX: 1,
    dirY: 0,
    fallbackDirX: 1,
    fallbackDirY: 0,
    damage100: 100,
    critChanceBp: 0,
    damageType: DamageType.physical,
    procs: const [
      WeaponProc(
        hook: ProcHook.onHit,
        statusProfileId: StatusProfileId.poisonOnHit,
      ),
    ],
    ballistic: false,
    gravityScale: 0,
  );

  void hit() {
    grid.rebuild(world);
    ProjectileHitSystem().step(world, grid, currentTick: 0);
  }

  void apply(int tick) {
    damage.step(
      world,
      currentTick: tick,
      queueStatus: status.queue,
      onParticipationDamage:
          ({required target, required hpLost100, required credit}) {
            credits.add(credit);
            losses.add(hpLost100);
          },
    );
    status.applyQueued(world, currentTick: tick);
  }
}
