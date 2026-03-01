import '../abilities/ability_def.dart' show WeaponType;
import '../combat/status/status.dart';
import 'weapon_category.dart';
import 'weapon_def.dart';
import 'weapon_id.dart';
import '../stats/gear_stat_bonuses.dart';
import 'weapon_proc.dart';

/// Lookup table for weapon definitions.
///
/// Similar to [ProjectileCatalog], but for melee weapons.
class WeaponCatalog {
  const WeaponCatalog();

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
      case WeaponId.woodenShield:
        return const WeaponDef(
          id: WeaponId.woodenShield,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          stats: GearStatBonuses(powerBonusBp: -100),
        );
      case WeaponId.basicShield:
        return const WeaponDef(
          id: WeaponId.basicShield,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          stats: GearStatBonuses(powerBonusBp: 100),
        );
      case WeaponId.solidShield:
        return const WeaponDef(
          id: WeaponId.solidShield,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          stats: GearStatBonuses(powerBonusBp: 200),
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
