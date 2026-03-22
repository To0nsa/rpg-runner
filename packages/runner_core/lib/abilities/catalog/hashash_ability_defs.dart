import 'package:runner_core/combat/damage_type.dart';

import '../../snapshots/enums.dart';
import '../ability_def.dart';

/// Hashash-authored melee abilities.
final Map<AbilityKey, AbilityDef> hashashAbilityDefs = <AbilityKey, AbilityDef>{
  'hashash.strike': AbilityDef(
    id: 'hashash.strike',
    category: AbilityCategory.melee,
    hitDelivery: MeleeHitDelivery(
      sizeX: 44.0,
      sizeY: 26.0,
      offsetX: 2.0,
      offsetY: 0.0,
      hitPolicy: HitPolicy.oncePerTarget,
    ),
    baseDamage: 900,
    baseDamageType: DamageType.physical,
    // Hashash strike row is authored as 13 frames. At 0.06s/frame and 60 Hz,
    // this is 4 ticks/frame. Active frames should be 9-10 (1-based):
    // - windup: frames 1-8  => 32 ticks
    // - active: frames 9-10 => 8 ticks
    // - recover: frames 11-13 => 12 ticks
    windupTicks: 32,
    activeTicks: 8,
    recoveryTicks: 12,
    cooldownTicks: 52,
    animKey: AnimKey.strike,
  ),
  'hashash.teleport_out': AbilityDef(
    id: 'hashash.teleport_out',
    category: AbilityCategory.mobility,
    hitDelivery: const SelfHitDelivery(),
    windupTicks: 0,
    activeTicks: 32,
    recoveryTicks: 0,
    cooldownTicks: 0,
    animKey: AnimKey.teleportOut,
  ),
  'hashash.ambush': AbilityDef(
    id: 'hashash.ambush',
    category: AbilityCategory.melee,
    hitDelivery: MeleeHitDelivery(
      sizeX: 52.0,
      sizeY: 28.0,
      offsetX: 2.0,
      offsetY: 0.0,
      hitPolicy: HitPolicy.oncePerTarget,
    ),
    baseDamage: 1200,
    baseDamageType: DamageType.physical,
    // Ambush row uses frame indices 1..9:
    // - windup: frames 1..6
    // - active: frames 7..9
    windupTicks: 24,
    activeTicks: 12,
    recoveryTicks: 12,
    cooldownTicks: 90,
    animKey: AnimKey.ambush,
  ),
};
