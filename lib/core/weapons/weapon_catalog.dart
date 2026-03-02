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
          stats: GearStatBonuses(powerBonusBp: 1000),
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
          stats: GearStatBonuses(powerBonusBp: 1000),
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
          stats: GearStatBonuses(critChanceBonusBp: 1000),
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
              chanceBp: 3500,
            ),
          ],
          stats: GearStatBonuses(powerBonusBp: 2500, critChanceBonusBp: -1000),
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
          stats: GearStatBonuses(powerBonusBp: 2000),
        );
      case WeaponId.stormneedle:
        return const WeaponDef(
          id: WeaponId.stormneedle,
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.stunOnHit,
              chanceBp: 2000,
            ),
          ],
          stats: GearStatBonuses(powerBonusBp: 2000),
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
          stats: GearStatBonuses(powerBonusBp: 1000, critChanceBonusBp: 1000),
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
          stats: GearStatBonuses(powerBonusBp: 700, defenseBonusBp: 1000),
        );
      case WeaponId.graveglass:
        return const WeaponDef(
          id: WeaponId.graveglass,
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
            globalPowerBonusBp: 3000,
            defenseBonusBp: -1500,
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
          stats: GearStatBonuses(powerBonusBp: 2000, critChanceBonusBp: 1500),
        );
      case WeaponId.roadguard:
        return const WeaponDef(
          id: WeaponId.roadguard,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          stats: GearStatBonuses(defenseBonusBp: 1500, healthBonusBp: 1000),
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
          stats: GearStatBonuses(defenseBonusBp: 1200),
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
          stats: GearStatBonuses(fireResistanceBp: 3000, defenseBonusBp: 600),
        );
      case WeaponId.tideguardShell:
        return const WeaponDef(
          id: WeaponId.tideguardShell,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          reactiveProcs: <ReactiveProc>[
            ReactiveProc(
              hook: ReactiveProcHook.onDamaged,
              statusProfileId: StatusProfileId.silenceOnHit,
              target: ReactiveProcTarget.attacker,
              chanceBp: 1500,
            ),
          ],
          stats: GearStatBonuses(
            manaBonusBp: 2000,
            waterResistanceBp: 2000,
            defenseBonusBp: 500,
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
            iceResistanceBp: 2000,
            moveSpeedBonusBp: 600,
            defenseBonusBp: 800,
          ),
        );
      case WeaponId.ironBastion:
        return const WeaponDef(
          id: WeaponId.ironBastion,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          stats: GearStatBonuses(
            defenseBonusBp: 3200,
            healthBonusBp: 1500,
            moveSpeedBonusBp: -900,
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
              statusProfileId: StatusProfileId.speedBoost,
              target: ReactiveProcTarget.self,
              chanceBp: 2000,
            ),
          ],
          stats: GearStatBonuses(
            thunderResistanceBp: 2500,
            cooldownReductionBp: 700,
            defenseBonusBp: 700,
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
              statusProfileId: StatusProfileId.silenceOnHit,
              target: ReactiveProcTarget.attacker,
              chanceBp: 2000,
            ),
          ],
          stats: GearStatBonuses(
            darkResistanceBp: 2500,
            holyResistanceBp: 1500,
            defenseBonusBp: 600,
          ),
        );
      case WeaponId.warbannerGuard:
        return const WeaponDef(
          id: WeaponId.warbannerGuard,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onKill,
              statusProfileId: StatusProfileId.speedBoost,
              chanceBp: 10000,
            ),
          ],
          stats: GearStatBonuses(defenseBonusBp: 1000, globalPowerBonusBp: 700),
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
            defenseBonusBp: 2200,
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
