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
          // Tempo baseline with stamina comfort and mana-tax dump.
          stats: GearStatBonuses(
            moveSpeedBonusBp: 1000,
            staminaBonusBp: 1000,
            manaBonusBp: -500,
          ),
        );
      case AccessoryId.goldenRing:
        return const AccessoryDef(
          id: AccessoryId.goldenRing,
          // Survivability baseline with low-health self-heal.
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
            healthRegenBonusBp: 500,
            defenseBonusBp: 1000,
            manaBonusBp: -500,
          ),
        );
      case AccessoryId.teethNecklace:
        return const AccessoryDef(
          id: AccessoryId.teethNecklace,
          // Stamina sustain package with low-health stamina recovery.
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
            staminaBonusBp: 2000,
            staminaRegenBonusBp: 1000,
            manaBonusBp: -500,
          ),
        );
      case AccessoryId.diamondRing:
        return const AccessoryDef(
          id: AccessoryId.diamondRing,
          // Caster sustain package with low-health mana recovery.
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
            manaBonusBp: 2000,
            manaRegenBonusBp: 1000,
            cooldownReductionBp: 800,
          ),
        );
      case AccessoryId.ironBoots:
        return const AccessoryDef(
          id: AccessoryId.ironBoots,
          // Mitigation anchor with route control and offense pressure.
          stats: GearStatBonuses(
            defenseBonusBp: 1200,
            globalPowerBonusBp: 1000,
            moveSpeedBonusBp: 500,
          ),
        );
      case AccessoryId.oathBeads:
        return const AccessoryDef(
          id: AccessoryId.oathBeads,
          // Rotation consistency package with mana-tax dump.
          stats: GearStatBonuses(
            cooldownReductionBp: 800,
            globalPowerBonusBp: 500,
            globalCritChanceBonusBp: 500,
            manaBonusBp: -500,
          ),
        );
      case AccessoryId.resilienceCape:
        return const AccessoryDef(
          id: AccessoryId.resilienceCape,
          // Counterpick resist package with mana-tax dump.
          stats: GearStatBonuses(
            bleedResistanceBp: 1200,
            darkResistanceBp: 800,
            healthBonusBp: 500,
            manaBonusBp: -500,
          ),
        );
      case AccessoryId.strengthBelt:
        return const AccessoryDef(
          id: AccessoryId.strengthBelt,
          // Offense-forward pick with crit pressure and mana-tax dump.
          stats: GearStatBonuses(
            globalPowerBonusBp: 1000,
            globalCritChanceBonusBp: 1000,
            staminaBonusBp: 1000,
            manaBonusBp: -500,
          ),
        );
    }
  }
}
