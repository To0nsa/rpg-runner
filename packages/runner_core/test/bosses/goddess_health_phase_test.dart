import 'package:runner_core/collision/terrain/terrain_motion_request.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/systems/ability_interrupt.dart';
import 'package:runner_core/ecs/systems/boss_utility_system.dart';
import 'package:runner_core/ecs/systems/enemy_cast_system.dart';
import 'package:runner_core/ecs/systems/voidborn_goddess_combat_system.dart';
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
  for (final hz in [30, 60, 90]) {
    test('75/50/25% each grant exactly one barrage at $hz Hz', () {
      final f = _Fixture(hz);
      for (var phase = 1; phase <= 3; phase++) {
        final hp = (4 - phase) * 9000;
        f.hp = hp + 1;
        f.decide(phase * 10);
        expect(f.action, isNot('goddess.eruption'));
        expect(f.reached, phase - 1);
        f.cancelAction(phase * 10 + 1);

        // Pending health phases outrank a close-range claw opportunity.
        f.world.bossCombat.actionIndex[f.world.bossCombat.indexOf(f.boss)] = 0;
        f.hp = hp;
        f.decide(phase * 10 + 2);
        expect(f.action, 'goddess.eruption');
        expect(f.reached, phase);
        expect(f.committed, phase);
        expect(f.world.goddessBarrage.has(f.boss), isTrue);
        f.cancelAction(phase * 10 + 3);
        f.decide(phase * 10 + 4);
        expect(
          f.action,
          isNot('goddess.eruption'),
          reason: 'no repeated phase',
        );
        f.cancelAction(phase * 10 + 5);
      }
      // Healing and crossing the same thresholds again cannot grant extra casts.
      f.hp = 36000;
      f.decide(50);
      f.cancelAction(51);
      f.hp = 1;
      f.decide(52);
      expect(f.action, isNot('goddess.eruption'));
      expect(f.committed, 3);
    });

    test(
      'large damage queues crossed thresholds through locks/healing at $hz Hz',
      () {
        final f = _Fixture(hz);
        f.world.controlLock.addLock(f.boss, LockFlag.allActions, 3, 10);
        f.hp = 8000;
        f.decide(10);
        expect(f.action, isNull);
        expect(f.reached, 3);
        expect(f.committed, 0);
        f.hp = 36000;
        for (var phase = 1; phase <= 3; phase++) {
          f.decide(13 + phase * 2);
          expect(f.action, 'goddess.eruption');
          expect(f.committed, phase);
          f.cancelAction(14 + phase * 2);
        }
        f.decide(30);
        expect(f.action, isNot('goddess.eruption'));
      },
    );

    test('threshold waits for the current action and cooldown at $hz Hz', () {
      final f = _Fixture(hz);
      f.decide(10);
      final current = f.action;
      f.hp = 27000;
      f.decide(11);
      expect(f.action, current);
      expect(f.committed, 0);
      f.cancelAction(12);
      f.world.cooldown.setTicksLeft(f.boss, 0, 10);
      f.decide(13);
      expect(f.action, isNull);
      expect(f.committed, 0);
      f.world.cooldown.setTicksLeft(f.boss, 0, 0);
      f.decide(14);
      expect(f.action, 'goddess.eruption');
      expect(f.committed, 1);
    });

    test('failed surface cast retains its health threshold at $hz Hz', () {
      final f = _Fixture(hz)..surfaceAvailable = false;
      f.hp = 27000;
      f.decide(10);
      expect(f.action, isNull);
      expect(f.committed, 0);
      expect(f.reached, 1);
      f.surfaceAvailable = true;
      f.decide(11);
      expect(f.action, 'goddess.eruption');
      expect(f.committed, 1);
    });
  }

  test('health phases are per Goddess and removed before ID recycling', () {
    final f = _Fixture(60);
    final other = f.actor(EnemyId.voidbornGoddess, 400);
    f.hp = 27000;
    f.decide(10);
    final phases = f.world.goddessHealthPhase;
    expect(phases.reached[phases.indexOf(other)], 0);
    expect(phases.committed[phases.indexOf(other)], 0);
    f.world.destroyEntity(f.boss);
    expect(phases.has(f.boss), isFalse);
    expect(f.world.createEntity(), f.boss);
    final i = phases.addEntity(f.boss);
    expect(phases.reached[i], 0);
    expect(phases.committed[i], 0);
    expect(phases.reached[phases.indexOf(other)], 0);
  });

  test('lethal damage never starts a pending health phase', () {
    final f = _Fixture(60);
    f.hp = 0;
    f.decide(10);
    expect(f.action, isNull);
    expect(f.world.goddessBarrage.has(f.boss), isFalse);
  });
}

final class _Fixture {
  _Fixture(int hz) {
    player = actor(EnemyId.grojib, 300);
    boss = actor(EnemyId.voidbornGoddess, 335);
    world.actorMotionBounds.add(
      boss,
      TerrainHorizontalBounds(minXTicks: 0, maxXTicks: 600 * 1024),
    );
    system = VoidbornGoddessCombatSystem(
      tickHz: hz,
      castCommitter: AiCastCommitter(
        tickHz: hz,
        projectiles: const ProjectileCatalog(),
        surfaceTarget: (x, y) => surfaceAvailable ? Vec2(x, 224) : null,
      ),
      utilities: BossUtilitySystem(
        tickHz: hz,
        motion: _NoMotion(),
        spawns: _NoSpawns(),
        groundTopY: 224,
      ),
    );
  }

  final world = EcsWorld(seed: 7);
  late final int player, boss;
  late final VoidbornGoddessCombatSystem system;
  bool surfaceAvailable = true;
  set hp(int value) => world.health.hp[world.health.indexOf(boss)] = value;
  int get phase => world.goddessHealthPhase.indexOf(boss);
  int get reached => world.goddessHealthPhase.reached[phase];
  int get committed => world.goddessHealthPhase.committed[phase];
  String? get action =>
      world.activeAbility.abilityId[world.activeAbility.indexOf(boss)];

  int actor(EnemyId id, double x) {
    final a = const EnemyCatalog().get(id);
    return EntityFactory(world).createEnemy(
      enemyId: id,
      posX: x,
      posY: 180,
      velX: 0,
      velY: 0,
      facing: Facing.left,
      body: a.body,
      collider: a.collider,
      health: a.health,
      mana: a.mana,
      stamina: a.stamina,
    );
  }

  void decide(int tick) =>
      system.step(world, player: player, currentTick: tick);

  // Exercise the real interruption cleanup between independently selected casts.
  // Motion and the uninterrupted six-hand lifecycle have separate Core tests.
  void cancelAction(int tick) {
    AbilityInterrupt.clearActiveAndTransient(
      world,
      entity: boss,
      startDeferredCooldown: false,
    );
    system.prepareBarrage(world, currentTick: tick);
    world.cooldown.setTicksLeft(boss, 0, 0);
    world.controlLock.removeEntity(boss);
  }
}

final class _NoMotion implements WorldMotionAuthority {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected motion');
}

final class _NoSpawns implements SpawnService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected spawn');
}
