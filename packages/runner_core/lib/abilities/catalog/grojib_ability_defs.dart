import 'package:runner_core/combat/damage_type.dart';

import '../../combat/status/status.dart';
import '../../snapshots/enums.dart';
import '../../weapons/weapon_proc.dart';
import '../ability_def.dart';

/// Grojib-authored melee abilities.
final Map<AbilityKey, AbilityDef> grojibAbilityDefs = <AbilityKey, AbilityDef>{
  'grojib.strike': AbilityDef(
    id: 'grojib.strike',
    category: AbilityCategory.melee,
    hitDelivery: MeleeHitDelivery(
      sizeX: 56.0,
      sizeY: 32.0,
      offsetX: 0.0,
      offsetY: 0.0,
      hitPolicy: HitPolicy.oncePerTarget,
    ),
    baseDamage: 800,
    baseDamageType: DamageType.physical,
    windupTicks: 15,
    activeTicks: 4,
    recoveryTicks: 17,
    cooldownTicks: 60,
    animKey: AnimKey.strike,
  ),
  'grojib.strike2': AbilityDef(
    id: 'grojib.strike2',
    category: AbilityCategory.melee,
    hitDelivery: MeleeHitDelivery(
      sizeX: 56.0,
      sizeY: 32.0,
      offsetX: 0.0,
      offsetY: 0.0,
      hitPolicy: HitPolicy.oncePerTarget,
    ),
    baseDamage: 1000,
    baseDamageType: DamageType.physical,
    windupTicks: 15,
    activeTicks: 4,
    recoveryTicks: 17,
    cooldownTicks: 60,
    procs: <WeaponProc>[
      WeaponProc(
        hook: ProcHook.onHit,
        statusProfileId: StatusProfileId.stunOnHit,
        chanceBp: 10000,
      ),
    ],
    animKey: AnimKey.strike2,
  ),
};
