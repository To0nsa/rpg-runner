import '../../abilities/ability_def.dart';
import '../../enemies/enemy_id.dart';
import '../../snapshots/enums.dart';
import '../combat_target.dart';
import '../entity_id.dart';
import '../world.dart';
import 'boss_combat_system.dart';

/// Shoggoth mixes close sweeps and committed charges with orbs and owned minions.
final class ShoggothCombatSystem extends BossCombatSystem {
  ShoggothCombatSystem({
    required super.tickHz,
    required super.castCommitter,
    required super.utilities,
  });

  @override
  EnemyId get enemyId => EnemyId.shoggoth;
  @override
  double get standOff => 65;
  @override
  double get pursuitSpeedScale => .8;

  @override
  String selectAbility(
    EcsWorld world,
    EntityId boss, {
    required int sequence,
    required double distanceX,
    required bool atMeleeHeight,
    required int currentTick,
  }) {
    final state = world.bossCombat.indexOf(boss);
    if (sequence >= 3 &&
        currentTick >= world.bossCombat.nextTeleportTick[state]) {
      return 'shoggoth.teleport';
    }
    if (sequence % 4 == 3 && utilities.livingSummons(world, boss) < 3) {
      return 'shoggoth.summon';
    }
    if (distanceX <= 150 && atMeleeHeight && sequence % 3 == 1) {
      return 'shoggoth.spinning_charge';
    }
    return distanceX <= 85 && atMeleeHeight
        ? 'shoggoth.tentacle_sweep'
        : 'shoggoth.orb';
  }

  @override
  void onAbilityCommitted(
    EcsWorld world,
    EntityId boss,
    String abilityId,
    int tick,
  ) {
    if (abilityId == 'shoggoth.teleport') {
      // Eight seconds between relocations keeps his melee phase available.
      world.bossCombat.nextTeleportTick[world.bossCombat.indexOf(boss)] =
          tick + 8 * tickHz;
    }
  }

  /// Composes the committed spin after locomotion; terrain still integrates once.
  void composeMotion(EcsWorld world, {required int currentTick}) {
    for (final boss in world.bossCombat.denseEntities) {
      if (world.enemy.enemyId[world.enemy.indexOf(boss)] != enemyId) continue;
      final ai = world.activeAbility.indexOf(boss);
      if (world.activeAbility.abilityId[ai] != 'shoggoth.spinning_charge' ||
          world.activeAbility.phase[ai] != AbilityPhase.active ||
          !isLivingCombatActor(world, boss) ||
          world.arenaSuspension.has(boss) ||
          world.controlLock.isStunned(boss, currentTick)) {
        continue;
      }
      final ti = world.transform.indexOf(boss);
      // 180 world units/sec: gravity, walls and arena bounds still apply.
      world.transform.velX[ti] = world.activeAbility.facing[ai] == Facing.left
          ? -180
          : 180;
    }
  }
}
