import '../combat/status/status.dart';
import '../stats/gear_stat_bonuses.dart';
import '../weapons/weapon_proc.dart';
import 'spell_book_def.dart';
import 'spell_book_id.dart';

/// Lookup table for spell books.
class SpellBookCatalog {
  const SpellBookCatalog();

  SpellBookDef get(SpellBookId id) {
    switch (id) {
      case SpellBookId.apprenticePrimer:
        return const SpellBookDef(
          id: SpellBookId.apprenticePrimer,
          stats: GearStatBonuses(globalPowerBonusBp: 200, manaBonusBp: 1000),
        );
      case SpellBookId.bastionCodex:
        return const SpellBookDef(
          id: SpellBookId.bastionCodex,
          stats: GearStatBonuses(
            defenseBonusBp: 1200,
            healthBonusBp: 1000,
            cooldownReductionBp: -400,
          ),
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onKill,
              statusProfileId: StatusProfileId.arcaneWard,
            ),
          ],
        );
      case SpellBookId.emberGrimoire:
        return const SpellBookDef(
          id: SpellBookId.emberGrimoire,
          stats: GearStatBonuses(
            globalPowerBonusBp: 700,
            cooldownReductionBp: 300,
            defenseBonusBp: -500,
          ),
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.burnOnHit,
              chanceBp: 3500,
            ),
          ],
        );
      case SpellBookId.tideAlmanac:
        return const SpellBookDef(
          id: SpellBookId.tideAlmanac,
          stats: GearStatBonuses(
            manaBonusBp: 2500,
            cooldownReductionBp: 500,
            globalPowerBonusBp: -300,
          ),
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.drenchOnHit,
              chanceBp: 2500,
            ),
          ],
        );
      case SpellBookId.hexboundLexicon:
        return const SpellBookDef(
          id: SpellBookId.hexboundLexicon,
          stats: GearStatBonuses(
            globalCritChanceBonusBp: 1000,
            globalPowerBonusBp: -200,
          ),
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onCrit,
              statusProfileId: StatusProfileId.weakenOnHit,
            ),
          ],
        );
      case SpellBookId.galeFolio:
        return const SpellBookDef(
          id: SpellBookId.galeFolio,
          stats: GearStatBonuses(
            moveSpeedBonusBp: 600,
            staminaBonusBp: 1200,
            globalPowerBonusBp: -200,
          ),
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.slowOnHit,
              chanceBp: 3000,
            ),
          ],
        );
      case SpellBookId.nullTestament:
        return const SpellBookDef(
          id: SpellBookId.nullTestament,
          stats: GearStatBonuses(
            darkResistanceBp: 2000,
            holyResistanceBp: 2000,
            globalPowerBonusBp: 300,
          ),
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onCrit,
              statusProfileId: StatusProfileId.silenceOnHit,
              chanceBp: 6000,
            ),
          ],
        );
      case SpellBookId.crownOfFocus:
        return const SpellBookDef(
          id: SpellBookId.crownOfFocus,
          stats: GearStatBonuses(
            globalPowerBonusBp: 1500,
            globalCritChanceBonusBp: 1000,
            defenseBonusBp: -1500,
            healthBonusBp: -1000,
          ),
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onKill,
              statusProfileId: StatusProfileId.focus,
            ),
          ],
        );
    }
  }

  SpellBookDef? tryGet(SpellBookId id) {
    try {
      return get(id);
    } catch (_) {
      return null;
    }
  }
}
