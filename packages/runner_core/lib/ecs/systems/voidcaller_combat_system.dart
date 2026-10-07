import '../../enemies/enemy_id.dart';
import '../entity_id.dart';
import '../world.dart';
import 'boss_combat_system.dart';

/// Voidcaller keeps distance and cycles beams, fiery claws and planted tentacles.
final class VoidcallerCombatSystem extends BossCombatSystem {
  VoidcallerCombatSystem({
    required super.tickHz,
    required super.castCommitter,
    required super.utilities,
  });

  @override
  EnemyId get enemyId => EnemyId.voidcaller;
  @override
  double get standOff => 180;
  @override
  double get pursuitSpeedScale => .45;

  @override
  String selectAbility(
    EcsWorld world,
    EntityId boss, {
    required int sequence,
    required double distanceX,
    required bool atMeleeHeight,
    required int currentTick,
  }) => switch (sequence % 4) {
    0 => 'voidcaller.vertical_beam',
    1 => 'voidcaller.diagonal_beam',
    2 => 'voidcaller.claw',
    _ =>
      utilities.livingSummons(world, boss) < 2
          ? 'voidcaller.summon'
          : 'voidcaller.claw',
  };
}
