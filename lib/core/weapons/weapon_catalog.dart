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
            globalPowerBonusBp: 1800,
            globalCritChanceBonusBp: 1200,
            staminaBonusBp: 2000,
            staminaRegenBonusBp: 800,
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
              chanceBp: 3500,
            ),
          ],
          stats: GearStatBonuses(
            globalPowerBonusBp: 1800,
            globalCritChanceBonusBp: 1000,
            staminaBonusBp: 2000,
            staminaRegenBonusBp: 600,
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
              statusProfileId: StatusProfileId.weakenOnHit,
              chanceBp: 10000,
            ),
          ],
          stats: GearStatBonuses(
            globalPowerBonusBp: 1300,
            globalCritChanceBonusBp: 800,
            staminaBonusBp: 1200,
            staminaRegenBonusBp: 500,
          ),
        );
      case WeaponId.basiliskKiss:
        return const WeaponDef(
          id: WeaponId.basiliskKiss,
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onCrit,
              statusProfileId: StatusProfileId.acidOnHit,
              chanceBp: 10000,
            ),
          ],
          stats: GearStatBonuses(
            globalPowerBonusBp: 1500,
            globalCritChanceBonusBp: 800,
            staminaBonusBp: 1000,
            defenseBonusBp: -500,
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
              chanceBp: 3500,
            ),
          ],
          stats: GearStatBonuses(
            globalPowerBonusBp: 1800,
            globalCritChanceBonusBp: 900,
            staminaBonusBp: 2000,
            staminaRegenBonusBp: 800,
          ),
        );
      case WeaponId.stormneedle:
        return const WeaponDef(
          id: WeaponId.stormneedle,
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onCrit,
              statusProfileId: StatusProfileId.stunOnHit,
              chanceBp: 2000,
            ),
          ],
          stats: GearStatBonuses(
            globalPowerBonusBp: 1800,
            globalCritChanceBonusBp: 1200,
            staminaBonusBp: 2000,
            staminaRegenBonusBp: 500,
          ),
        );
      case WeaponId.nullblade:
        return const WeaponDef(
          id: WeaponId.nullblade,
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onCrit,
              statusProfileId: StatusProfileId.silenceOnHit,
              chanceBp: 2000,
            ),
          ],
          stats: GearStatBonuses(
            globalPowerBonusBp: 1700,
            globalCritChanceBonusBp: 1200,
            staminaBonusBp: 2000,
            staminaRegenBonusBp: 600,
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
              statusProfileId: StatusProfileId.speedBoost,
              chanceBp: 10000,
            ),
          ],
          stats: GearStatBonuses(
            globalPowerBonusBp: 1500,
            globalCritChanceBonusBp: 1000,
            staminaBonusBp: 1500,
            staminaRegenBonusBp: 600,
          ),
        );
      case WeaponId.graveglass:
        return const WeaponDef(
          id: WeaponId.graveglass,
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onCrit,
              statusProfileId: StatusProfileId.acidOnHit,
              chanceBp: 2000,
            ),
          ],
          stats: GearStatBonuses(
            globalPowerBonusBp: 1800,
            globalCritChanceBonusBp: 1200,
            staminaBonusBp: 2000,
            staminaRegenBonusBp: 500,
          ),
        );
      case WeaponId.duelistsOath:
        return const WeaponDef(
          id: WeaponId.duelistsOath,
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onCrit,
              statusProfileId: StatusProfileId.weakenOnHit,
              chanceBp: 10000,
            ),
          ],
          stats: GearStatBonuses(
            globalPowerBonusBp: 1500,
            globalCritChanceBonusBp: 1200,
            staminaBonusBp: 700,
          ),
        );
      case WeaponId.roadguard:
        return const WeaponDef(
          id: WeaponId.roadguard,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          stats: GearStatBonuses(
            defenseBonusBp: 1800,
            staminaBonusBp: 2000,
            staminaRegenBonusBp: 1200,
            physicalResistanceBp: 1900,
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
            defenseBonusBp: 1800,
            staminaBonusBp: 1800,
            staminaRegenBonusBp: 700,
            bleedResistanceBp: 2000,
          ),
        );
      case WeaponId.cinderWard:
        return const WeaponDef(
          id: WeaponId.cinderWard,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          reactiveProcs: <ReactiveProc>[
            ReactiveProc(
              hook: ReactiveProcHook.onDamaged,
              statusProfileId: StatusProfileId.burnOnHit,
              target: ReactiveProcTarget.attacker,
              chanceBp: 2500,
            ),
          ],
          stats: GearStatBonuses(
            fireResistanceBp: 2500,
            defenseBonusBp: 1800,
            staminaBonusBp: 1200,
            staminaRegenBonusBp: 800,
          ),
        );
      case WeaponId.tideguardShell:
        return const WeaponDef(
          id: WeaponId.tideguardShell,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          reactiveProcs: <ReactiveProc>[
            ReactiveProc(
              hook: ReactiveProcHook.onDamaged,
              statusProfileId: StatusProfileId.drenchOnHit,
              target: ReactiveProcTarget.attacker,
              chanceBp: 1500,
            ),
          ],
          stats: GearStatBonuses(
            waterResistanceBp: 2500,
            defenseBonusBp: 1800,
            staminaBonusBp: 1800,
            staminaRegenBonusBp: 500,
          ),
        );
      case WeaponId.frostlockBuckler:
        return const WeaponDef(
          id: WeaponId.frostlockBuckler,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          reactiveProcs: <ReactiveProc>[
            ReactiveProc(
              hook: ReactiveProcHook.onDamaged,
              statusProfileId: StatusProfileId.slowOnHit,
              target: ReactiveProcTarget.attacker,
              chanceBp: 3500,
            ),
          ],
          stats: GearStatBonuses(
            iceResistanceBp: 2500,
            defenseBonusBp: 1600,
            staminaBonusBp: 1500,
            staminaRegenBonusBp: 600,
          ),
        );
      case WeaponId.ironBastion:
        return const WeaponDef(
          id: WeaponId.ironBastion,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          stats: GearStatBonuses(
            defenseBonusBp: 1800,
            staminaBonusBp: 2000,
            staminaRegenBonusBp: 1200,
            physicalResistanceBp: 1100,
            moveSpeedBonusBp: -1000,
          ),
        );
      case WeaponId.stormAegis:
        return const WeaponDef(
          id: WeaponId.stormAegis,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          reactiveProcs: <ReactiveProc>[
            ReactiveProc(
              hook: ReactiveProcHook.onDamaged,
              statusProfileId: StatusProfileId.slowOnHit,
              target: ReactiveProcTarget.attacker,
              chanceBp: 2500,
            ),
          ],
          stats: GearStatBonuses(
            thunderResistanceBp: 2500,
            defenseBonusBp: 1700,
            staminaBonusBp: 1500,
            staminaRegenBonusBp: 700,
          ),
        );
      case WeaponId.nullPrism:
        return const WeaponDef(
          id: WeaponId.nullPrism,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          reactiveProcs: <ReactiveProc>[
            ReactiveProc(
              hook: ReactiveProcHook.onDamaged,
              statusProfileId: StatusProfileId.drenchOnHit,
              target: ReactiveProcTarget.attacker,
              chanceBp: 2000,
            ),
          ],
          stats: GearStatBonuses(
            darkResistanceBp: 2000,
            holyResistanceBp: 2000,
            defenseBonusBp: 1400,
            staminaBonusBp: 900,
          ),
        );
      case WeaponId.warbannerGuard:
        return const WeaponDef(
          id: WeaponId.warbannerGuard,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          reactiveProcs: <ReactiveProc>[
            ReactiveProc(
              hook: ReactiveProcHook.onDamaged,
              statusProfileId: StatusProfileId.burnOnHit,
              target: ReactiveProcTarget.attacker,
              chanceBp: 2500,
            ),
          ],
          stats: GearStatBonuses(
            defenseBonusBp: 1800,
            staminaBonusBp: 2000,
            staminaRegenBonusBp: 1000,
            physicalResistanceBp: 1300,
            globalPowerBonusBp: -500,
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
            defenseBonusBp: 1800,
            staminaBonusBp: 1200,
            holyResistanceBp: 500,
            globalPowerBonusBp: -500,
            globalCritChanceBonusBp: -1000,
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
