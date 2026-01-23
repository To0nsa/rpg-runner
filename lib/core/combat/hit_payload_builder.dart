import '../weapons/weapon_proc.dart';
import '../weapons/weapon_stats.dart';
import '../abilities/ability_def.dart';
import '../ecs/entity_id.dart';
import 'damage_type.dart';
import 'hit_payload.dart';

/// Canonical builder for [HitPayload].
///
/// Encapsulates the logic for combining an [AbilityDef] (Base) with a
/// set of Modifiers (Stats/Procs) to produce a deterministic damage snapshot.
///
/// **Usage:**
/// *   **Producers** (Intent Systems): Call `build` to freeze the payload into the intent.
/// *   **UI** (Tooltip/Preview): Call `build` to show predicted damage.
class HitPayloadBuilder {
  static HitPayload build({
    required AbilityDef ability,
    required EntityId source,
    // Modifiers (extracted from WeaponDef or RangedWeaponDef or Buffs)
    WeaponStats? weaponStats,
    DamageType? weaponDamageType,
    List<WeaponProc> weaponProcs = const [],
  }) {
    // 1. Start with Ability Base
    int finalDamage100 = ability.baseDamage; // Fixed-point (e.g. 1500 = 15.0)
    DamageType finalDamageType = ability.baseDamageType;
    final List<WeaponProc> finalProcs = [];

    // 2. Apply Weapon Modifiers
    if (weaponStats != null) {
      // A. Power Scaling (Integer Math)
      // Math: damage = base * (1 + bonusBp/10000)
      // Impl: (base * (10000 + bonusBp)) ~/ 10000
      final bonusBp = weaponStats.powerBonusBp;
      if (bonusBp > 0) {
        // e.g. 1500 * 12000 ~/ 10000 = 1800
        finalDamage100 = (finalDamage100 * (10000 + bonusBp)) ~/ 10000;
      }
    }

    if (weaponDamageType != null) {
      // B. Damage Type Override
      // Rule: Weapon overrides Physical ability. Elemental ability (Fire/Ice) keeps its element.
      if (finalDamageType == DamageType.physical) {
        finalDamageType = weaponDamageType;
      }
    }

    // C. Procs
    finalProcs.addAll(weaponProcs);

    return HitPayload(
      damage100: finalDamage100,
      damageType: finalDamageType,
      procs: finalProcs,
      sourceId: source,
      abilityId: ability.id,
      // Removed weaponId debug field to decouple? Or keep optional?
      // Let's remove weaponId from builder logic, caller can add if needed via 'copyWith'? 
      // Or just omit relevant debug info for now.
    );
  }
}
