import 'package:runner_core/combat/ai_target_policy.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/combat/damage_credit.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/player/invulnerability_store.dart';
import 'package:runner_core/ecs/systems/active_ability_phase_system.dart';
import 'package:runner_core/ecs/systems/damage_system.dart';
import 'package:runner_core/ecs/systems/ground_enemy_locomotion_system.dart';
import 'package:runner_core/ecs/systems/hitbox_damage_system.dart';
import 'package:runner_core/ecs/systems/hitbox_follow_owner_system.dart';
import 'package:runner_core/ecs/systems/lifetime_system.dart';
import 'package:runner_core/ecs/systems/melee_strike_system.dart';
import 'package:runner_core/ecs/systems/npc_ai_system.dart';
import 'package:runner_core/ecs/systems/projectile_launch_system.dart';
import 'package:runner_core/ecs/systems/status_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/npcs/npc_catalog.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/tuning/ground_enemy_tuning.dart';
import 'package:test/test.dart';

const _stab = 'npc_huntress.stab';
const _slash = 'npc_huntress.slash';
const _throw = 'npc_huntress.throw_spear';

void main() {
  for (final hz in [30, 60]) {
    for (final direction in [-1, 1]) {
      test('stab lands once then slash, ${hz}Hz facing $direction', () {
        final h = _Harness(tickHz: hz, direction: direction)..step();
        expect(h.active, _stab);
        expect(h.hasStabbed(h.enemy), isFalse);
        expect(h.world.stamina.stamina[h.world.stamina.indexOf(h.npc)], 3600);
        h.advanceTo(1 + h.ticks(18));
        expect(h.hp(h.enemy), 99700);
        expect(h.hasStabbed(h.enemy), isTrue);
        final di = h.world.dot.indexOf(h.enemy);
        expect(h.world.dot.dps100[di], [300]);
        expect(h.world.dot.ticksLeft[di], [5 * hz]);
        expect(h.world.dot.credit[di], [DamageCredit.none]);

        h.advanceTo(1 + h.ticks(48));
        expect(h.active, _slash);
        h.advanceTo(1 + h.ticks(48 + 18));
        expect(h.world.dot.ticksLeft[di].single, lessThan(5 * hz));
        expect(h.hasStabbed(h.enemy), isTrue);
        expect(
          h.world.meleeIntent.procs[h.world.meleeIntent.indexOf(h.npc)],
          isEmpty,
        );
      });
    }
  }

  test('throw, stab and slash share cooldown and finish committed attacks', () {
    final h = _Harness(distance: 150)..step();
    expect(h.active, _throw);
    h.move(h.enemy, 340);
    h.advanceTo(37);
    expect(h.active, _throw);
    expect(h.world.projectile.denseEntities, hasLength(1));
    expect(h.hasStabbed(h.enemy), isFalse);
    h.advanceTo(78);
    expect(h.active, isNull);
    h.step();
    expect(h.active, _stab);
    h.advanceTo(97);
    expect(h.hasStabbed(h.enemy), isTrue);
    h.move(h.enemy, 450);
    h.advanceTo(126);
    expect(h.active, isNull);
    h.step();
    expect(h.active, _throw);
    h.advanceTo(204);
    h.move(h.enemy, 340);
    h.step();
    expect(h.active, _slash);
  });

  test('target switches retain separate successful opener histories', () {
    final h = _Harness()..step();
    h.advanceTo(19);
    final second = h.addEnemy(260);
    h.select(second);
    h.advanceTo(48, decide: false);
    h.step();
    expect(h.active, _stab);
    h.advanceTo(67);
    expect(h.hasStabbed(second), isTrue);
    h.select(h.enemy);
    h.advanceTo(96, decide: false);
    h.step();
    expect(h.active, _slash);

    final otherHuntress = h.addNpc();
    h.select(h.enemy, actor: otherHuntress);
    h.step();
    expect(
      h.world.activeAbility.abilityId[h.world.activeAbility.indexOf(
        otherHuntress,
      )],
      _stab,
    );
  });

  test('bleed expiry and absence of a target do not reset opener history', () {
    final h = _Harness()..step();
    h.advanceTo(19);
    h.world.aiTarget.selected[h.world.aiTarget.indexOf(h.npc)] = null;
    h.advanceTo(320);
    expect(h.world.dot.has(h.enemy), isFalse);
    expect(h.hp(h.enemy), 98200);
    h.select(h.enemy);
    h.step();
    expect(h.active, _slash);
  });

  test('a missed stab is retried after its cooldown', () {
    final h = _Harness()..step();
    h.move(h.enemy, 450);
    h.advanceTo(48, decide: false);
    expect(h.hasStabbed(h.enemy), isFalse);
    expect(h.hp(h.enemy), 100000);
    h.move(h.enemy, 340);
    h.step();
    expect(h.active, _stab);
  });

  test('an interrupted stab does not consume the opener', () {
    final h = _Harness()..step();
    h.world.controlLock.addLock(h.npc, LockFlag.stun, 40, 1);
    h.advanceTo(48, decide: false);
    expect(h.hp(h.enemy), 100000);
    expect(h.hasStabbed(h.enemy), isFalse);
    h.step();
    expect(h.active, _stab);
  });

  for (final denial in ['invulnerable', 'canceled', 'zero damage']) {
    test('$denial damage cannot consume the opener', () {
      final h = _Harness();
      if (denial == 'invulnerable') {
        h.world.invulnerability.add(
          h.enemy,
          const InvulnerabilityDef(ticksLeft: 99),
        );
      }
      h.beforeDamage = () {
        for (var i = 0; i < h.world.damageQueue.length; i++) {
          if (denial == 'canceled') h.world.damageQueue.cancel(i);
          if (denial == 'zero damage') h.world.damageQueue.amount100[i] = 0;
        }
      };
      h.advanceTo(48);
      expect(h.hp(h.enemy), 100000);
      expect(h.hasStabbed(h.enemy), isFalse);
      h.step();
      expect(h.active, _stab);
    });
  }

  test('only enemies actually damaged by the stab enter its history', () {
    final h = _Harness()..step();
    final intercepted = h.addEnemy(345);
    h.move(h.enemy, 450);
    h.advanceTo(19);
    expect(h.hasStabbed(h.enemy), isFalse);
    expect(h.hasStabbed(intercepted), isTrue);
  });

  test('destroying a target clears history before its entity ID is reused', () {
    final h = _Harness()..step();
    h.advanceTo(48, decide: false);
    expect(h.hasStabbed(h.enemy), isTrue);
    h.world.destroyEntity(h.enemy);
    final replacement = h.addEnemy(340);
    expect(replacement, h.enemy);
    expect(h.hasStabbed(replacement), isFalse);
    h.select(replacement);
    h.step();
    expect(h.active, _stab);
  });

  test(
    'stabbing a new foe cannot reapply the opener to an overlapping old foe',
    () {
      final h = _Harness()..step();
      h.advanceTo(48, decide: false);
      final second = h.addEnemy(345);
      h.select(second);
      h.advanceTo(67);
      expect(h.hasStabbed(second), isTrue);
      expect(h.hp(h.enemy), 99700);
      expect(h.hp(second), 99700);
      expect(h.world.dot.ticksLeft[h.world.dot.indexOf(h.enemy)], [252]);
      expect(h.world.dot.ticksLeft[h.world.dot.indexOf(second)], [300]);
    },
  );

  test('removing another NPC preserves the surviving Huntress history', () {
    final h = _Harness();
    final second = h.addNpc();
    h.select(h.enemy, actor: second);
    h.world.aiTarget.selected[h.world.aiTarget.indexOf(h.npc)] = null;
    h.advanceTo(19);
    expect(h.world.npc.hasLandedMeleeOpener(second, h.enemy), isTrue);
    h.world.destroyEntity(h.npc);
    expect(h.world.npc.hasLandedMeleeOpener(second, h.enemy), isTrue);
    final replacement = h.addNpc();
    expect(replacement, h.npc);
    expect(h.world.npc.hasLandedMeleeOpener(replacement, h.enemy), isFalse);
  });

  test('vertical separation uses throw even inside horizontal melee range', () {
    final h = _Harness();
    h.world.transform.posY[h.world.transform.indexOf(h.enemy)] = 160;
    h.step();
    expect(h.active, _throw);
  });

  test('unaffordable melee cannot fall back to a ranged attack', () {
    final h = _Harness();
    h.world.stamina.stamina[h.world.stamina.indexOf(h.npc)] = 0;
    h.step();
    expect(h.active, isNull);
    expect(h.hasStabbed(h.enemy), isFalse);
    expect(h.world.projectile.denseEntities, isEmpty);
  });
}

/// Fixed positions isolate attack decisions; production timing, hit, status and
/// damage systems still run in tick order. Terrain traversal is tested elsewhere.
class _Harness {
  _Harness({this.tickHz = 60, int direction = 1, double distance = 40}) {
    ai = NpcAiSystem(
      tickHz: tickHz,
      locomotion: GroundEnemyLocomotionSystem(
        groundEnemyTuning: GroundEnemyTuningDerived.from(
          const GroundEnemyTuning(),
          tickHz: tickHz,
        ),
      ),
    );
    status = StatusSystem(tickHz: tickHz);
    launch = ProjectileLaunchSystem(
      projectiles: const ProjectileCatalog(),
      tickHz: tickHz,
    );
    npc = addNpc();
    enemy = addEnemy(300 + direction * distance);
    select(enemy);
  }

  final int tickHz;
  final world = EcsWorld();
  late final NpcAiSystem ai;
  late final StatusSystem status;
  late final ProjectileLaunchSystem launch;
  final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 7);
  final hits = HitboxDamageSystem();
  final follow = HitboxFollowOwnerSystem();
  final lifetime = LifetimeSystem();
  final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 64));
  late final int npc, enemy;
  int tick = 0;
  void Function()? beforeDamage;

  String? get active =>
      world.activeAbility.abilityId[world.activeAbility.indexOf(npc)];
  int ticks(int authoredTicks) => (authoredTicks * tickHz / 60).ceil();
  int hp(int actor) => world.health.hp[world.health.indexOf(actor)];
  bool hasStabbed(int target) => world.npc.hasLandedMeleeOpener(npc, target);
  void move(int target, double x) =>
      world.transform.posX[world.transform.indexOf(target)] = x;

  int addNpc() {
    final actor = EntityFactory(world).createNpc(
      npcId: NpcId.huntress,
      posX: 300,
      posY: 100,
      chunkStartX: 0,
      chunkEndX: 1000,
    );
    world.worldContactCapsule.add(
      actor,
      const NpcCatalog().terrainContactProfile(NpcId.huntress).capsule,
    );
    world.collision.grounded[world.collision.indexOf(actor)] = true;
    return actor;
  }

  int addEnemy(double x) {
    final def = const EnemyCatalog().get(EnemyId.grojib);
    final actor = EntityFactory(world).createEnemy(
      enemyId: EnemyId.grojib,
      posX: x,
      posY: 100,
      velX: 0,
      velY: 0,
      facing: Facing.left,
      body: def.body,
      collider: def.collider,
      health: const HealthDef(hp: 100000, hpMax: 100000, regenPerSecond100: 0),
      mana: def.mana,
      stamina: def.stamina,
    );
    world.worldContactCapsule.add(
      actor,
      const EnemyCatalog().terrainContactProfile(EnemyId.grojib).capsule,
    );
    return actor;
  }

  void select(int target, {int? actor}) {
    actor ??= npc;
    world.aiTarget.configure(
      actor,
      targetPolicy: AiTargetPolicy.nearestOpponent,
      candidates: [target],
      playerFallback: false,
    );
    world.aiTarget.selected[world.aiTarget.indexOf(actor)] = target;
  }

  void advanceTo(int end, {bool decide = true}) {
    while (tick < end) {
      step(decide: decide);
    }
  }

  void step({bool decide = true}) {
    tick++;
    world.cooldown.tickAll();
    const ActiveAbilityPhaseSystem().step(world, currentTick: tick);
    if (decide) ai.step(world, currentTick: tick, dtSeconds: 1 / tickHz);
    MeleeStrikeSystem().step(world, currentTick: tick);
    launch.step(world, currentTick: tick);
    follow.step(world);
    grid.rebuild(world);
    hits.step(world, grid, currentTick: tick);
    status.tickExisting(world);
    beforeDamage?.call();
    damage.step(world, currentTick: tick, queueStatus: status.queue);
    status.applyQueued(world, currentTick: tick);
    lifetime.step(world);
  }
}
