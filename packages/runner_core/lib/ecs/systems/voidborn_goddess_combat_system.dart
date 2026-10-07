import '../../enemies/enemy_id.dart';
import '../entity_id.dart';
import '../world.dart';
import 'boss_combat_system.dart';

/// Goddess alternates her ranged threats, using claws when the target is close.
final class VoidbornGoddessCombatSystem extends BossCombatSystem {
  VoidbornGoddessCombatSystem({
    required super.tickHz,
    required super.castCommitter,
    required super.utilities,
  });

  @override
  EnemyId get enemyId => EnemyId.voidbornGoddess;
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
      return 'goddess.teleport';
    }
    if (distanceX <= 85 && atMeleeHeight && sequence % 3 == 0) {
      return 'goddess.claw_combo';
    }
    return sequence.isEven ? 'goddess.orb' : 'goddess.eruption';
  }

  @override
  void onAbilityCommitted(
    EcsWorld world,
    EntityId boss,
    String abilityId,
    int tick,
  ) {
    if (abilityId == 'goddess.teleport') {
      // Eight seconds between relocations leaves time to attack her in place.
      world.bossCombat.nextTeleportTick[world.bossCombat.indexOf(boss)] =
          tick + 8 * tickHz;
    }
  }
}
