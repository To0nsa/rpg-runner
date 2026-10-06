import '../enemies/enemy_id.dart';
import '../npcs/npc_id.dart';
import '../snapshots/enums.dart';
import 'combat_geometry.dart';

/// Torso/head/leg poses, excluding weapons, hair trails and attack smears.
/// Feet remain on the reviewed source support line; compact rolls deliberately
/// lower vulnerability without changing the terrain movement capsule.
abstract final class ActorHurtboxCatalog {
  static const _roll = [
    CombatCapsule(0, -7, 0, 14, 8),
    CombatCapsule(-10, 12, 10, 12, 10),
    CombatCapsule(-10, 12, 10, 12, 10),
    CombatCapsule(-6, 12, 6, 12, 10),
    CombatCapsule(-6, 15, 7, 15, 8),
    CombatCapsule(-12, 12, 12, 12, 10),
    CombatCapsule(0, -6, 0, 14, 8),
    CombatCapsule(0, 5, 8, 14, 8),
    CombatCapsule(0, 6, 8, 14, 8),
    CombatCapsule(0, -4, 0, 14, 9),
  ];
  static const _playerStrike = [
    CombatCapsule(0, -11, 0, 14, 9),
    CombatCapsule(-2, -11, -2, 14, 9),
    CombatCapsule(-5, -10, -3, 14, 9),
    CombatCapsule(-5, -11, -3, 14, 9),
    CombatCapsule(1, -10, 0, 14, 9),
    CombatCapsule(0, -11, 0, 14, 9),
  ];
  static CombatCapsule? player(AnimKey key, int frame) => switch (key) {
    AnimKey.roll => _roll[frame % _roll.length],
    AnimKey.strike => _playerStrike[frame % _playerStrike.length],
    AnimKey.backStrike => const CombatCapsule(2, -10, 1, 14, 9),
    AnimKey.dash => const CombatCapsule(-4, -7, 4, 14, 9),
    AnimKey.jump || AnimKey.fall => const CombatCapsule(0, -12, 0, 8, 9),
    AnimKey.hit => const CombatCapsule(-3, -10, 0, 14, 9),
    _ => null,
  };

  static CombatCapsule? npc(NpcId id, AnimKey key, int frame) {
    if (key == AnimKey.strike || key == AnimKey.strike2) {
      return id == NpcId.warrior
          ? const CombatCapsule(0, -12, -8, 14, 12)
          : const CombatCapsule(-4, -7, 0, 15, 11);
    }
    if (key == AnimKey.hit) return const CombatCapsule(-3, -13, 3, 14, 12);
    if (key == AnimKey.jump || key == AnimKey.fall) {
      return const CombatCapsule(0, -12, 0, 8, 12);
    }
    return null;
  }

  static CombatCapsule? enemy(EnemyId id, AnimKey key, int frame) =>
      switch (id) {
        EnemyId.grojib
            when key == AnimKey.strike ||
                key == AnimKey.strike2 ||
                key == AnimKey.backStrike =>
          frame >= 4 ? const CombatCapsule(0, 14, -4, 29, 14) : null,
        EnemyId.hashash
            when key == AnimKey.strike ||
                key == AnimKey.ambush ||
                key == AnimKey.dash =>
          const CombatCapsule(1, 0, -4, 18, 12),
        EnemyId.unocoDemon => CombatCapsule(
          0,
          1 + (frame.isOdd ? 1 : 0),
          0,
          3 + (frame.isOdd ? 1 : 0),
          8,
        ),
        EnemyId.derf when key == AnimKey.strike && (frame == 3 || frame == 4) =>
          const CombatCapsule(-10, -3, -1, 20, 10),
        EnemyId.derf when key == AnimKey.cast => const CombatCapsule(
          0,
          -6,
          0,
          20,
          11.5,
        ),
        _ => null,
      };
}
