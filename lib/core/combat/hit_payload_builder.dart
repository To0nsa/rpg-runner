import '../weapons/weapon_proc.dart';
import '../stats/gear_stat_bonuses.dart';
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
    // Modifiers (extracted from WeaponDef or ProjectileItemDef or Buffs)
    GearStatBonuses? weaponStats,
    int globalPowerBonusBp = 0,
    int globalCritChanceBonusBp = 0,
    DamageType? weaponDamageType,
    List<WeaponProc> weaponProcs = const [],
    List<WeaponProc> buffProcs = const [],
    List<WeaponProc> passiveProcs = const [],
  }) {
    // 1. Start with Ability Base
    int finalDamage100 = ability.baseDamage; // Fixed-point (e.g. 1500 = 15.0)
    DamageType finalDamageType = ability.baseDamageType;
    int finalCritChanceBp = globalCritChanceBonusBp;
    final List<WeaponProc> finalProcs = [];

    // 2. Apply global offensive modifiers.
    if (globalPowerBonusBp != 0) {
      finalDamage100 = (finalDamage100 * (10000 + globalPowerBonusBp)) ~/ 10000;
      if (finalDamage100 < 0) finalDamage100 = 0;
    }

    // 3. Apply payload-source weapon modifiers.
    if (weaponStats != null) {
      // A. Power Scaling (Integer Math)
      // Math: damage = base * (1 + bonusBp/10000)
      // Impl: (base * (10000 + bonusBp)) ~/ 10000
      final bonusBp = weaponStats.powerBonusBp;
      // e.g. 1500 * 12000 ~/ 10000 = 1800
      finalDamage100 = (finalDamage100 * (10000 + bonusBp)) ~/ 10000;
      if (finalDamage100 < 0) finalDamage100 = 0;

      // B. Crit chance is additive, with later cap at payload level.
      finalCritChanceBp += weaponStats.critChanceBonusBp;
    }

    if (weaponDamageType != null) {
      // C. Damage Type Override
      // Rule: Weapon overrides Physical ability. Elemental ability (Fire/Ice) keeps its element.
      if (finalDamageType == DamageType.physical) {
        finalDamageType = weaponDamageType;
      }
    }

    // D. Procs (deterministic merge + dedupe)
    // Order is canonical: ability -> item -> buffs -> passives.
    final Set<int> seen = <int>{};
    void addProcs(List<WeaponProc> procs) {
      for (final proc in procs) {
        final key = (proc.hook.index << 16) | proc.statusProfileId.index;
        if (!seen.add(key)) continue;
        finalProcs.add(proc);
      }
    }

    if (ability.procs.isNotEmpty) {
      addProcs(ability.procs);
    }
    if (weaponProcs.isNotEmpty) {
      addProcs(weaponProcs);
    }
    if (buffProcs.isNotEmpty) {
      addProcs(buffProcs);
    }
    if (passiveProcs.isNotEmpty) {
      addProcs(passiveProcs);
    }

    if (finalCritChanceBp < 0) finalCritChanceBp = 0;
    if (finalCritChanceBp > 10000) finalCritChanceBp = 10000;

    return HitPayload(
      damage100: finalDamage100,
      critChanceBp: finalCritChanceBp,
      damageType: finalDamageType,
      procs: finalProcs,
      sourceId: source,
      abilityId: ability.id,
    );
  }
}
