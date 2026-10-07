import '../snapshots/enums.dart';
import 'combat_geometry.dart';

/// Damage geometry in world units at ShoggothMinion's 1.5x art scale.
abstract final class ShoggothMinionPoseCatalog {
  static const minionBite = CombatStrikeProfile(
    artFacing: Facing.left,
    timing: ActionFramePolicy(frameCount: 6, activeStart: 3, activeEnd: 5),
    frames: [
      [],
      [],
      [],
      [CombatCapsule(-8, -4, -23, -4, 4)],
      [CombatCapsule(-8, -4, -23, -4, 4)],
      [],
    ],
  );

  /// Actor art phases share the committed action clock used by damage.
  static ActionFramePolicy? timingFor(String abilityId) => switch (abilityId) {
    'shoggoth_minion.bite' => ShoggothMinionPoseCatalog.minionBite.timing,
    _ => null,
  };
}
