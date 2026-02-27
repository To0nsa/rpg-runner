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
          stats: GearStatBonuses(powerBonusBp: 100),
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
              chanceBp: 3000,
            ),
          ],
          stats: GearStatBonuses(powerBonusBp: 50),
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
          stats: GearStatBonuses(critChanceBonusBp: 200),
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
              chanceBp: 2500,
            ),
          ],
          stats: GearStatBonuses(powerBonusBp: 50, critChanceBonusBp: -100),
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
              chanceBp: 3000,
            ),
          ],
          stats: GearStatBonuses(powerBonusBp: 80),
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
              chanceBp: 800,
            ),
          ],
          stats: GearStatBonuses(powerBonusBp: 70),
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
              chanceBp: 1500,
            ),
          ],
          stats: GearStatBonuses(powerBonusBp: 80),
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
          stats: GearStatBonuses(powerBonusBp: 70, defenseBonusBp: 100),
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
              chanceBp: 700,
            ),
          ],
          stats: GearStatBonuses(globalPowerBonusBp: 120, defenseBonusBp: -150),
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
          stats: GearStatBonuses(powerBonusBp: 50, critChanceBonusBp: 150),
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
