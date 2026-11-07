import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../snapshots/enums.dart';
import '../world.dart';

/// Overrides horizontal locomotion during authored active combat lunges only.
/// Runs before knockback/gravity/terrain; interruption immediately releases it.
class CombatLungeSystem {
  const CombatLungeSystem({this.abilities = AbilityCatalog.shared});
  final AbilityResolver abilities;
  void step(EcsWorld world) {
    final active = world.activeAbility;
    for (var i = 0; i < active.denseEntities.length; i++) {
      if (active.phase[i] != AbilityPhase.active) continue;
      final id = active.abilityId[i];
      final speed = id == null
          ? null
          : abilities.resolve(id)?.activeForwardSpeedX;
      if (speed == null) continue;
      final ti = world.transform.tryIndexOf(active.denseEntities[i]);
      if (ti != null) {
        world.transform.velX[ti] =
            speed * (active.facing[i] == Facing.left ? -1 : 1);
      }
    }
  }
}
