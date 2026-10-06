import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/stores/death_state_store.dart';
import 'package:runner_core/ecs/systems/anim/anim_system.dart';
import 'package:runner_core/ecs/stores/enemies/derf_phase_store.dart';
import 'package:runner_core/ecs/systems/control_lock_system.dart';
import 'package:runner_core/ecs/systems/derf_transformation_system.dart';
import 'package:runner_core/ecs/systems/enemy_cast_system.dart';
import 'package:runner_core/ecs/systems/enemy_engagement_system.dart';
import 'package:runner_core/ecs/systems/enemy_melee_system.dart';
import 'package:runner_core/ecs/systems/target_point_impact_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/enemies/death_behavior.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/tuning/flying_enemy_tuning.dart';
import 'package:runner_core/tuning/ground_enemy_tuning.dart';
import 'package:test/test.dart';

void main() {
  for (final hz in [30, 60, 120]) {
    test(
      'caster transforms once and releases only melee afterward at $hz Hz',
      () {
        final f = _Fixture();
        final transformation = DerfTransformationSystem(tickHz: hz);
        final caster = _castSystem(hz);
        void step(int tick, {bool visible = false}) {
          ControlLockSystem().step(f.world, currentTick: tick);
          transformation.step(
            f.world,
            currentTick: tick,
            cameraLeft: visible ? -150 : 200,
            cameraRight: visible ? 150 : 500,
            cameraTop: -100,
            cameraBottom: 100,
          );
        }

        step(1);
        caster.step(f.world, player: f.target, currentTick: 1);
        expect(f.phase, DerfPhase.caster);
        expect(
          f.world.activeAbility.abilityId[f.world.activeAbility.indexOf(
            f.derf,
          )],
          'derf.fire_explosion',
        );
        expect(f.world.controlLock.isLocked(f.derf, LockFlag.move, 1), isTrue);
        final releaseTick = f
            .world
            .targetPointIntent
            .tick[f.world.targetPointIntent.indexOf(f.derf)];
        final health = f.world.health.hp[f.world.health.indexOf(f.derf)];
        final mana = f.world.mana.mana[f.world.mana.indexOf(f.derf)];

        step(2, visible: true);
        expect(f.phase, DerfPhase.transforming);
        expect(f.world.activeAbility.hasActiveAbility(f.derf), isFalse);
        expect(
          f.world.targetPointIntent.tick[f.world.targetPointIntent.indexOf(
            f.derf,
          )],
          -1,
        );
        TargetPointImpactSystem().step(f.world, currentTick: releaseTick);
        expect(f.world.hitbox.denseEntities, isEmpty);
        caster.step(f.world, player: f.target, currentTick: 2);
        expect(f.world.activeAbility.hasActiveAbility(f.derf), isFalse);
        expect(f.world.controlLock.isLocked(f.derf, LockFlag.cast, 2), isTrue);
        for (
          var tick = 3;
          tick < 2 + transformation.transformationTicks;
          tick++
        ) {
          step(tick);
          expect(f.phase, DerfPhase.transforming);
        }
        final completed = 2 + transformation.transformationTicks;
        step(completed);
        expect(f.phase, DerfPhase.twisted);
        expect(
          f.world.controlLock.isLocked(f.derf, LockFlag.move, completed),
          isFalse,
        );
        expect(f.world.health.hp[f.world.health.indexOf(f.derf)], health);
        expect(f.world.mana.mana[f.world.mana.indexOf(f.derf)], mana);
        caster.step(f.world, player: f.target, currentTick: completed);
        expect(f.world.activeAbility.hasActiveAbility(f.derf), isFalse);

        final tuning = GroundEnemyTuningDerived.from(
          const GroundEnemyTuning(),
          tickHz: hz,
        );
        f.world.navIntent.navTargetX[f.world.navIntent.indexOf(f.derf)] = 90;
        final engagement = EnemyEngagementSystem(groundEnemyTuning: tuning);
        engagement.step(f.world, player: f.target, currentTick: completed);
        engagement.step(f.world, player: f.target, currentTick: completed + 1);
        EnemyMeleeSystem(groundEnemyTuning: tuning)
            .step(f.world, player: f.target, currentTick: completed + 1);
        expect(
          f.world.activeAbility.abilityId[f.world.activeAbility.indexOf(
            f.derf,
          )],
          'derf.tentacle_strike',
        );
        expect(
          f.world.engagementIntent.meleeRangeX[f.world.engagementIntent.indexOf(
            f.derf,
          )],
          greaterThan(90),
        );
        step(completed + 2, visible: true);
        expect(f.phase, DerfPhase.twisted);
        expect(
          f.world.derfPhase.transformationStartTick[f.world.derfPhase.indexOf(
            f.derf,
          )],
          2,
        );
      },
    );
  }

  test(
    'camera overlap uses both axes and the body rather than the sheet canvas',
    () {
      final f = _Fixture();
      final transformation = DerfTransformationSystem(tickHz: 60);
      void probe(double left, double top, double right, double bottom) {
        transformation.step(
          f.world,
          currentTick: 1,
          cameraLeft: left,
          cameraTop: top,
          cameraRight: right,
          cameraBottom: bottom,
        );
      }

      probe(12, -100, 100, 100);
      expect(
        f.phase,
        DerfPhase.caster,
        reason: 'Transparent tentacle padding is not the body.',
      );
      probe(-100, 32, 100, 100);
      expect(f.phase, DerfPhase.caster);
      probe(-100, -100, 100, -18);
      expect(f.phase, DerfPhase.caster);
      probe(-100, -100, -12, 100);
      expect(f.phase, DerfPhase.caster);
      probe(11.5, -100, 100, 100);
      expect(
        f.phase,
        DerfPhase.caster,
        reason: 'Touching the camera edge has no visible body area.',
      );
      probe(11.49, -100, 100, 100);
      expect(f.phase, DerfPhase.transforming);
    },
  );

  test(
    'death cancels awakening and longer unrelated locks survive completion',
    () {
      final f = _Fixture();
      final transformation = DerfTransformationSystem(tickHz: 60);
      f.world.controlLock.addLock(
        f.derf,
        LockFlag.stun | LockFlag.move,
        200,
        1,
      );
      transformation.step(
        f.world,
        currentTick: 1,
        cameraLeft: -100,
        cameraTop: -100,
        cameraRight: 100,
        cameraBottom: 100,
      );
      final completed = 1 + transformation.transformationTicks;
      ControlLockSystem().step(f.world, currentTick: completed);
      transformation.step(
        f.world,
        currentTick: completed,
        cameraLeft: -100,
        cameraTop: -100,
        cameraRight: 100,
        cameraBottom: 100,
      );
      expect(f.phase, DerfPhase.twisted);
      expect(f.world.controlLock.isStunned(f.derf, completed), isTrue);
      expect(
        f.world.controlLock.isLocked(f.derf, LockFlag.move, completed),
        isTrue,
      );
      final dead = _Fixture();
      dead.world.health.hp[dead.world.health.indexOf(dead.derf)] = 0;
      transformation.step(
        dead.world,
        currentTick: 1,
        cameraLeft: -100,
        cameraTop: -100,
        cameraRight: 100,
        cameraBottom: 100,
      );
      expect(dead.phase, DerfPhase.caster);
    },
  );

  test(
    'released explosions retain their world anchor through transformation',
    () {
      final f = _Fixture();
      _castSystem(60).step(f.world, player: f.target, currentTick: 1);
      final release = f
          .world
          .targetPointIntent
          .tick[f.world.targetPointIntent.indexOf(f.derf)];
      TargetPointImpactSystem().step(f.world, currentTick: release);
      final impact = f.world.hitbox.denseEntities.single;
      final ti = f.world.transform.indexOf(impact);
      final x = f.world.transform.posX[ti];
      DerfTransformationSystem(tickHz: 60).step(
        f.world,
        currentTick: release + 1,
        cameraLeft: -100,
        cameraTop: -100,
        cameraRight: 100,
        cameraBottom: 100,
      );
      expect(f.world.hitbox.has(impact), isTrue);
      expect(f.world.transform.posX[ti], x);
    },
  );

  test('entity destruction removes phase state before IDs are reused', () {
    final f = _Fixture();
    f.world.destroyEntity(f.derf);
    expect(f.world.derfPhase.has(f.derf), isFalse);
    expect(f.world.derfPhase.phase, isEmpty);
    final reused = f.world.createEntity();
    expect(reused, f.derf);
    f.world.derfPhase.add(reused);
    expect(f.phase, DerfPhase.caster);
    expect(f.world.derfPhase.transformationStartTick.single, -1);
  });

  test(
    'normal cast art, uninterrupted transformation, and death use Core clocks',
    () {
      final f = _Fixture();
      final anim = AnimSystem(
        tickHz: 60,
        enemyCatalog: const EnemyCatalog(),
        playerMovement: MovementTuningDerived.from(
          eloiseCharacter.tuning.movement,
          tickHz: 60,
        ),
        playerAnimTuning: AnimTuningDerived.from(
          eloiseCharacter.tuning.anim,
          tickHz: 60,
        ),
      );
      final ai = f.world.animState.indexOf(f.derf);
      anim.step(f.world, player: -1, currentTick: 1);
      expect(f.world.animState.anim[ai], AnimKey.casterIdle);
      _castSystem(60).step(f.world, player: f.target, currentTick: 1);
      anim.step(f.world, player: -1, currentTick: 1);
      expect(f.world.animState.anim[ai], AnimKey.cast);
      DerfTransformationSystem(tickHz: 60).step(
        f.world,
        currentTick: 2,
        cameraLeft: -100,
        cameraTop: -100,
        cameraRight: 100,
        cameraBottom: 100,
      );
      f.world.controlLock.addLock(f.derf, LockFlag.stun, 100, 3);
      anim.step(f.world, player: -1, currentTick: 22);
      expect(f.world.animState.anim[ai], AnimKey.transform);
      expect(f.world.animState.animFrame[ai], 20);
      f.world.health.hp[f.world.health.indexOf(f.derf)] = 0;
      f.world.deathState.add(
        f.derf,
        const DeathStateDef(phase: DeathPhase.deathAnim, deathStartTick: 23),
      );
      anim.step(f.world, player: -1, currentTick: 23);
      expect(f.world.animState.anim[ai], AnimKey.death);
      expect(f.world.animState.animFrame[ai], 0);
    },
  );
}

EnemyCastSystem _castSystem(int hz) => EnemyCastSystem(
  unocoDemonTuning: UnocoDemonTuningDerived.from(
    const UnocoDemonTuning(),
    tickHz: hz,
  ),
  enemyCatalog: const EnemyCatalog(),
  projectiles: const ProjectileCatalog(),
  abilities: AbilityCatalog.shared,
);

class _Fixture {
  _Fixture() {
    const archetype = EnemyCatalog();
    final a = archetype.get(EnemyId.derf);
    final factory = EntityFactory(world);
    target = factory.createPlayer(
      posX: 90,
      posY: 0,
      velX: 0,
      velY: 0,
      facing: Facing.left,
      grounded: true,
      body: a.body,
      collider: a.collider,
      health: a.health,
      mana: a.mana,
      stamina: a.stamina,
    );
    derf = factory.createEnemy(
      enemyId: EnemyId.derf,
      posX: 0,
      posY: 0,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      artFacing: a.artFacingDir,
      body: a.body,
      collider: a.collider,
      health: a.health,
      mana: a.mana,
      stamina: a.stamina,
    );
  }
  final world = EcsWorld(seed: 7);
  late final int derf;
  late final int target;
  DerfPhase get phase => world.derfPhase.phase[world.derfPhase.indexOf(derf)];
}
