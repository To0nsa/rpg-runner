import 'accessory_def.dart';
import 'accessory_id.dart';
import '../combat/status/status.dart';
import '../stats/gear_stat_bonuses.dart';
import '../weapons/reactive_proc.dart';

/// Read-only authored accessory definitions.
///
/// This catalog uses an exhaustive enum switch so adding a new [AccessoryId]
/// forces a compile-time update here.
class AccessoryCatalog {
  const AccessoryCatalog();

  /// Returns the authored definition for [id].
  ///
  /// This API is intentionally non-nullable: every valid [AccessoryId] must
  /// resolve to a definition.
  AccessoryDef get(AccessoryId id) {
    switch (id) {
      case AccessoryId.speedBoots:
        return const AccessoryDef(
          id: AccessoryId.speedBoots,
          stats: GearStatBonuses(
            moveSpeedBonusBp: 1000,
            staminaRegenBonusBp: 1000,
            cooldownReductionBp: 500,
            manaBonusBp: -1000,
          ),
        );
      case AccessoryId.goldenRing:
        return const AccessoryDef(
          id: AccessoryId.goldenRing,
          reactiveProcs: <ReactiveProc>[
            ReactiveProc(
              hook: ReactiveProcHook.onLowHealth,
              statusProfileId: StatusProfileId.restoreHealth,
              target: ReactiveProcTarget.self,
              chanceBp: 10000,
              lowHealthThresholdBp: 3000,
              internalCooldownTicks: 1800,
            ),
          ],
          stats: GearStatBonuses(
            healthBonusBp: 1500,
            cooldownReductionBp: -500,
          ),
        );
      case AccessoryId.teethNecklace:
        return const AccessoryDef(
          id: AccessoryId.teethNecklace,
          reactiveProcs: <ReactiveProc>[
            ReactiveProc(
              hook: ReactiveProcHook.onLowHealth,
              statusProfileId: StatusProfileId.restoreStamina,
              target: ReactiveProcTarget.self,
              chanceBp: 10000,
              lowHealthThresholdBp: 3000,
              internalCooldownTicks: 1800,
            ),
          ],
          stats: GearStatBonuses(
            staminaBonusBp: 1500,
            healthBonusBp: -500,
          ),
        );
      case AccessoryId.diamondRing:
        return const AccessoryDef(
          id: AccessoryId.diamondRing,
          reactiveProcs: <ReactiveProc>[
            ReactiveProc(
              hook: ReactiveProcHook.onLowHealth,
              statusProfileId: StatusProfileId.restoreMana,
              target: ReactiveProcTarget.self,
              chanceBp: 10000,
              lowHealthThresholdBp: 3000,
              internalCooldownTicks: 1800,
            ),
          ],
          stats: GearStatBonuses(
            manaBonusBp: 1500,
            staminaBonusBp: -500,
          ),
        );
      case AccessoryId.ironBoots:
        return const AccessoryDef(
          id: AccessoryId.ironBoots,
          stats: GearStatBonuses(
            healthBonusBp: 500,
            defenseBonusBp: 1500,
            physicalResistanceBp: 1500,
            globalPowerBonusBp: -500,
          ),
        );
      case AccessoryId.oathBeads:
        return const AccessoryDef(
          id: AccessoryId.oathBeads,
          stats: GearStatBonuses(
            cooldownReductionBp: 500,
            globalPowerBonusBp: 1000,
            manaRegenBonusBp: 1000,
            defenseBonusBp: -500,
          ),
        );
      case AccessoryId.resilienceCape:
        return const AccessoryDef(
          id: AccessoryId.resilienceCape,
          stats: GearStatBonuses(
            fireResistanceBp: 2500,
            darkResistanceBp: 2000,
            defenseBonusBp: 1000,
            manaBonusBp: -500,
          ),
        );
      case AccessoryId.strengthBelt:
        return const AccessoryDef(
          id: AccessoryId.strengthBelt,
          stats: GearStatBonuses(
            globalPowerBonusBp: 1500,
            globalCritChanceBonusBp: 1000,
            staminaBonusBp: 1000,
            cooldownReductionBp: -500,
          ),
        );
    }
  }
}
