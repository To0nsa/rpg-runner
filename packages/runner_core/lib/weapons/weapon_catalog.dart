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
      case WeaponId.hunterBlade:
        return const WeaponDef(
          id: WeaponId.hunterBlade,
          category: WeaponCategory.primary,
          weaponType: WeaponType.hunterBlade,
          stats: GearStatBonuses(
            globalPowerBonusBp: 1000,
            staminaBonusBp: 1500,
            staminaRegenBonusBp: 500,
            defenseBonusBp: -500,
          ),
        );
      case WeaponId.hunterNotchknife:
        return const WeaponDef(
          id: WeaponId.hunterNotchknife,
          category: WeaponCategory.primary,
          weaponType: WeaponType.hunterBlade,
          stats: GearStatBonuses(globalPowerBonusBp: 500, healthBonusBp: -500),
          procs: [
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.meleeBleed,
              chanceBp: 2000,
              statusTuning: StatusProfileTuning(
                dot: StatusApplicationTuning(
                  magnitude: 200,
                  durationSeconds: 3,
                ),
              ),
            ),
          ],
        );
      case WeaponId.hunterHookblade:
        return const WeaponDef(
          id: WeaponId.hunterHookblade,
          category: WeaponCategory.primary,
          weaponType: WeaponType.hunterBlade,
          stats: GearStatBonuses(
            staminaRegenBonusBp: 1000,
            defenseBonusBp: -500,
          ),
          procs: [
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.slowOnHit,
              chanceBp: 2000,
              statusTuning: StatusProfileTuning(
                slow: StatusApplicationTuning(
                  magnitude: 2000,
                  durationSeconds: 2,
                ),
              ),
            ),
          ],
        );
      case WeaponId.hunterCausticEdge:
        return const WeaponDef(
          id: WeaponId.hunterCausticEdge,
          category: WeaponCategory.primary,
          weaponType: WeaponType.hunterBlade,
          stats: GearStatBonuses(staminaBonusBp: 1000, healthBonusBp: -500),
          procs: [
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.acidOnHit,
              chanceBp: 2000,
              statusTuning: StatusProfileTuning(
                vulnerable: StatusApplicationTuning(
                  magnitude: 1500,
                  durationSeconds: 3,
                ),
              ),
            ),
          ],
        );
      case WeaponId.hunterCinderpoint:
        return const WeaponDef(
          id: WeaponId.hunterCinderpoint,
          category: WeaponCategory.primary,
          weaponType: WeaponType.hunterBlade,
          stats: GearStatBonuses(
            globalCritChanceBonusBp: 1000,
            manaRegenBonusBp: -500,
          ),
          procs: [
            WeaponProc(
              hook: ProcHook.onCrit,
              statusProfileId: StatusProfileId.burnOnHit,
              chanceBp: 10000,
              statusTuning: StatusProfileTuning(
                dot: StatusApplicationTuning(
                  magnitude: 200,
                  durationSeconds: 3,
                ),
              ),
            ),
          ],
        );
      case WeaponId.hunterSappingBlade:
        return const WeaponDef(
          id: WeaponId.hunterSappingBlade,
          category: WeaponCategory.primary,
          weaponType: WeaponType.hunterBlade,
          stats: GearStatBonuses(
            staminaRegenBonusBp: 1000,
            healthBonusBp: -500,
          ),
          procs: [
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.weakenOnHit,
              chanceBp: 2000,
              statusTuning: StatusProfileTuning(
                weaken: StatusApplicationTuning(
                  magnitude: 1500,
                  durationSeconds: 3,
                ),
              ),
            ),
          ],
        );
      case WeaponId.hunterPursuitBlade:
        return const WeaponDef(
          id: WeaponId.hunterPursuitBlade,
          category: WeaponCategory.primary,
          weaponType: WeaponType.hunterBlade,
          stats: GearStatBonuses(
            globalPowerBonusBp: 500,
            staminaRegenBonusBp: 1000,
            defenseBonusBp: -500,
          ),
          procs: [
            WeaponProc(
              hook: ProcHook.onKill,
              statusProfileId: StatusProfileId.speedBoost,
              chanceBp: 3500,
              statusTuning: StatusProfileTuning(
                haste: StatusApplicationTuning(
                  magnitude: 1500,
                  durationSeconds: 3,
                ),
              ),
            ),
          ],
        );
      case WeaponId.hunterLastWord:
        return const WeaponDef(
          id: WeaponId.hunterLastWord,
          category: WeaponCategory.primary,
          weaponType: WeaponType.hunterBlade,
          stats: GearStatBonuses(
            globalPowerBonusBp: 1500,
            globalCritChanceBonusBp: 1000,
            staminaBonusBp: 1000,
            healthBonusBp: -1000,
          ),
        );
      case WeaponId.hunterBombKit:
        return const WeaponDef(
          id: WeaponId.hunterBombKit,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.bombKit,
          stats: GearStatBonuses(
            defenseBonusBp: 1000,
            staminaBonusBp: 1500,
            physicalResistanceBp: 1000,
            moveSpeedBonusBp: -500,
          ),
        );
      case WeaponId.hunterSplinterRig:
        return const WeaponDef(
          id: WeaponId.hunterSplinterRig,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.bombKit,
          stats: GearStatBonuses(defenseBonusBp: 500, globalPowerBonusBp: -500),
          procs: [
            WeaponProc(
              hook: ProcHook.onCrit,
              statusProfileId: StatusProfileId.meleeBleed,
              chanceBp: 10000,
              statusTuning: StatusProfileTuning(
                dot: StatusApplicationTuning(
                  magnitude: 200,
                  durationSeconds: 3,
                ),
              ),
            ),
          ],
        );
      case WeaponId.hunterPitchRig:
        return const WeaponDef(
          id: WeaponId.hunterPitchRig,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.bombKit,
          stats: GearStatBonuses(
            defenseBonusBp: 500,
            globalCritChanceBonusBp: -500,
          ),
          procs: [
            WeaponProc(
              hook: ProcHook.onCrit,
              statusProfileId: StatusProfileId.burnOnHit,
              chanceBp: 10000,
              statusTuning: StatusProfileTuning(
                dot: StatusApplicationTuning(
                  magnitude: 200,
                  durationSeconds: 3,
                ),
              ),
            ),
          ],
        );
      case WeaponId.hunterSnareRig:
        return const WeaponDef(
          id: WeaponId.hunterSnareRig,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.bombKit,
          stats: GearStatBonuses(
            staminaBonusBp: 1000,
            globalPowerBonusBp: -500,
          ),
          procs: [
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.slowOnHit,
              chanceBp: 2500,
              statusTuning: StatusProfileTuning(
                slow: StatusApplicationTuning(
                  magnitude: 2500,
                  durationSeconds: 2,
                ),
              ),
            ),
          ],
        );
      case WeaponId.hunterEtchingRig:
        return const WeaponDef(
          id: WeaponId.hunterEtchingRig,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.bombKit,
          stats: GearStatBonuses(
            staminaRegenBonusBp: 1000,
            globalCritChanceBonusBp: -500,
          ),
          procs: [
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.acidOnHit,
              chanceBp: 2000,
              statusTuning: StatusProfileTuning(
                vulnerable: StatusApplicationTuning(
                  magnitude: 1500,
                  durationSeconds: 3,
                ),
              ),
            ),
          ],
        );
      case WeaponId.hunterSapperHarness:
        return const WeaponDef(
          id: WeaponId.hunterSapperHarness,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.bombKit,
          stats: GearStatBonuses(
            defenseBonusBp: 1000,
            physicalResistanceBp: 1500,
            staminaRegenBonusBp: 500,
            moveSpeedBonusBp: -1000,
          ),
        );
      case WeaponId.hunterKilnwrapRig:
        return const WeaponDef(
          id: WeaponId.hunterKilnwrapRig,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.bombKit,
          stats: GearStatBonuses(
            fireResistanceBp: 2500,
            defenseBonusBp: 1000,
            staminaBonusBp: 500,
            globalCritChanceBonusBp: -500,
          ),
        );
      case WeaponId.hunterSealedRig:
        return const WeaponDef(
          id: WeaponId.hunterSealedRig,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.bombKit,
          stats: GearStatBonuses(
            acidResistanceBp: 2000,
            waterResistanceBp: 1500,
            staminaBonusBp: 1000,
            globalPowerBonusBp: -500,
          ),
        );
      case WeaponId.hunterStormwrapRig:
        return const WeaponDef(
          id: WeaponId.hunterStormwrapRig,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.bombKit,
          stats: GearStatBonuses(
            thunderResistanceBp: 2500,
            defenseBonusBp: 500,
            staminaRegenBonusBp: 1000,
            globalCritChanceBonusBp: -500,
          ),
        );
      case WeaponId.hunterBacktrailRig:
        return const WeaponDef(
          id: WeaponId.hunterBacktrailRig,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.bombKit,
          stats: GearStatBonuses(
            defenseBonusBp: 1000,
            globalPowerBonusBp: -1000,
          ),
          reactiveProcs: [
            ReactiveProc(
              hook: ReactiveProcHook.onLowHealth,
              statusProfileId: StatusProfileId.speedBoost,
              chanceBp: 10000,
              lowHealthThresholdBp: 3000,
              internalCooldownTicks: _thirtySecondsAt60Hz,
              statusTuning: StatusProfileTuning(
                haste: StatusApplicationTuning(
                  magnitude: 1500,
                  durationSeconds: 3,
                ),
              ),
            ),
          ],
        );
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
          stats: GearStatBonuses(globalPowerBonusBp: 500, healthBonusBp: -500),
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
