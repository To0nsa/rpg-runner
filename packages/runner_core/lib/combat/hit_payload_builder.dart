import '../weapons/weapon_proc.dart';
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
    // Global modifiers (stats + buffs)
    int globalPowerBonusBp = 0,
    int globalCritChanceBonusBp = 0,
    DamageType? weaponDamageType,
    List<WeaponProc> weaponProcs = const [],
    List<WeaponProc> buffProcs = const [],
    List<WeaponProc> passiveProcs = const [],
  }) {
    // 1. Start with Ability Base
    int finalDamage100 = ability.baseDamage; // Fixed-point (e.g. 1500 = 15.0)
    DamageComposition finalDamageType = ability.baseDamageType;
    int finalCritChanceBp = globalCritChanceBonusBp;
    final List<WeaponProc> finalProcs = [];

    // 2. Apply global offensive modifiers.
    if (globalPowerBonusBp != 0) {
      finalDamage100 = (finalDamage100 * (10000 + globalPowerBonusBp)) ~/ 10000;
      if (finalDamage100 < 0) finalDamage100 = 0;
    }

    if (weaponDamageType != null) {
      // Item conversion affects only physical shares; authored elements remain.
      finalDamageType = finalDamageType.withPhysicalType(weaponDamageType);
    }

    // 4. Procs (deterministic merge + dedupe)
    // Order is canonical: ability -> item -> buffs -> passives.
    // The first matching hook/profile owns its complete tuning and chance;
    // duplicate item procs must not replace an ability's authored values.
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
      knockback: ability.knockback,
      sourceId: source,
      abilityId: ability.id,
    );
  }
}
