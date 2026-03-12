import '../abilities/ability_def.dart' show WeaponType;
import '../combat/status/status.dart';
import 'weapon_category.dart';
import 'weapon_def.dart';
import 'weapon_id.dart';
import '../stats/gear_stat_bonuses.dart';
import 'reactive_proc.dart';
import 'weapon_proc.dart';

/// Lookup table for weapon definitions.
///
/// Similar to [ProjectileCatalog], but for melee weapons.
class WeaponCatalog {
  const WeaponCatalog();

  static const int _thirtySecondsAt60Hz = 1800;

  WeaponDef get(WeaponId id) {
    switch (id) {
      case WeaponId.plainsteel:
        return const WeaponDef(
          id: WeaponId.plainsteel,
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          stats: GearStatBonuses(
            globalPowerBonusBp: 1500,
            globalCritChanceBonusBp: 1000,
            staminaBonusBp: 1000,
            defenseBonusBp: -500,
          ),
        );
      case WeaponId.waspfang:
        return const WeaponDef(
          id: WeaponId.waspfang,
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.meleeBleed,
              chanceBp: 2000,
            ),
          ],
          stats: GearStatBonuses(
            globalPowerBonusBp: 500,
            healthBonusBp: -500,
          ),
        );
      case WeaponId.cinderedge:
        return const WeaponDef(
          id: WeaponId.cinderedge,
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onCrit,
              statusProfileId: StatusProfileId.burnOnHit,
              chanceBp: 10000,
            ),
          ],
          stats: GearStatBonuses(
            globalCritChanceBonusBp: 1000,
            manaRegenBonusBp: -500,
          ),
        );
      case WeaponId.basiliskKiss:
        return const WeaponDef(
          id: WeaponId.basiliskKiss,
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.acidOnHit,
              chanceBp: 2000,
            ),
          ],
          stats: GearStatBonuses(
            staminaRegenBonusBp: 1000,
            healthBonusBp: -500,
          ),
        );
      case WeaponId.frostbrand:
        return const WeaponDef(
          id: WeaponId.frostbrand,
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.slowOnHit,
              chanceBp: 2000,
            ),
          ],
          stats: GearStatBonuses(
            globalPowerBonusBp: 1000,
            defenseBonusBp: -500,
          ),
        );
      case WeaponId.stormneedle:
        return const WeaponDef(
          id: WeaponId.stormneedle,
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          stats: GearStatBonuses(
            globalCritChanceBonusBp: 1000,
            staminaBonusBp: 1500,
            staminaRegenBonusBp: 500,
            healthBonusBp: -500,
          ),
        );
      case WeaponId.nullblade:
        return const WeaponDef(
          id: WeaponId.nullblade,
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.silenceOnHit,
              chanceBp: 2000,
            ),
          ],
          stats: GearStatBonuses(
            globalCritChanceBonusBp: 1000,
            staminaBonusBp: -500,
          ),
        );
      case WeaponId.sunlitVow:
        return const WeaponDef(
          id: WeaponId.sunlitVow,
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onKill,
              statusProfileId: StatusProfileId.focus,
              chanceBp: 3500,
            ),
          ],
          stats: GearStatBonuses(
            globalPowerBonusBp: 1000,
            staminaRegenBonusBp: 1000,
            healthBonusBp: -500,
          ),
        );
      case WeaponId.roadguard:
        return const WeaponDef(
          id: WeaponId.roadguard,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          stats: GearStatBonuses(
            defenseBonusBp: 1500,
            staminaBonusBp: 1500,
            physicalResistanceBp: 1000,
            moveSpeedBonusBp: -500,
          ),
        );
      case WeaponId.thornbark:
        return const WeaponDef(
          id: WeaponId.thornbark,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          reactiveProcs: <ReactiveProc>[
            ReactiveProc(
              hook: ReactiveProcHook.onDamaged,
              statusProfileId: StatusProfileId.meleeBleed,
              target: ReactiveProcTarget.attacker,
              chanceBp: 3500,
            ),
          ],
          stats: GearStatBonuses(
            defenseBonusBp: 1000,
            globalPowerBonusBp: -500,
          ),
        );
      case WeaponId.cinderWard:
        return const WeaponDef(
          id: WeaponId.cinderWard,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          stats: GearStatBonuses(
            fireResistanceBp: 2500,
            defenseBonusBp: 1000,
            globalCritChanceBonusBp: -500,
          ),
        );
      case WeaponId.tideguardShell:
        return const WeaponDef(
          id: WeaponId.tideguardShell,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          stats: GearStatBonuses(
            waterResistanceBp: 2000,
            staminaBonusBp: 1500,
            defenseBonusBp: 500,
            globalPowerBonusBp: -500,
          ),
        );
      case WeaponId.frostlockBuckler:
        return const WeaponDef(
          id: WeaponId.frostlockBuckler,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          stats: GearStatBonuses(
            iceResistanceBp: 2000,
            defenseBonusBp: 1000,
            staminaBonusBp: 1000,
            globalCritChanceBonusBp: -500,
          ),
        );
      case WeaponId.ironBastion:
        return const WeaponDef(
          id: WeaponId.ironBastion,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          stats: GearStatBonuses(
            defenseBonusBp: 1500,
            physicalResistanceBp: 1500,
            staminaRegenBonusBp: 1000,
            moveSpeedBonusBp: -1000,
          ),
        );
      case WeaponId.stormAegis:
        return const WeaponDef(
          id: WeaponId.stormAegis,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          stats: GearStatBonuses(
            thunderResistanceBp: 2500,
            defenseBonusBp: 500,
            staminaRegenBonusBp: 1000,
            globalCritChanceBonusBp: -500,
          ),
        );
      case WeaponId.nullPrism:
        return const WeaponDef(
          id: WeaponId.nullPrism,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          stats: GearStatBonuses(
            darkResistanceBp: 2000,
            holyResistanceBp: 1500,
            defenseBonusBp: 500,
            moveSpeedBonusBp: -500,
          ),
        );
      case WeaponId.warbannerGuard:
        return const WeaponDef(
          id: WeaponId.warbannerGuard,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          stats: GearStatBonuses(
            defenseBonusBp: 1000,
            staminaBonusBp: 2000,
            bleedResistanceBp: 500,
            globalCritChanceBonusBp: -1000,
          ),
        );
      case WeaponId.oathwallRelic:
        return const WeaponDef(
          id: WeaponId.oathwallRelic,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          reactiveProcs: <ReactiveProc>[
            ReactiveProc(
              hook: ReactiveProcHook.onLowHealth,
              statusProfileId: StatusProfileId.speedBoost,
              target: ReactiveProcTarget.self,
              chanceBp: 10000,
              lowHealthThresholdBp: 3000,
              internalCooldownTicks: _thirtySecondsAt60Hz,
            ),
          ],
          stats: GearStatBonuses(
            defenseBonusBp: 1500,
            globalPowerBonusBp: -1000,
          ),
        );
    }
  }

  WeaponDef? tryGet(WeaponId id) {
    try {
      return get(id);
    } catch (_) {
      return null;
    }
  }
}
