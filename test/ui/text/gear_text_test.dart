import 'package:game_presentation/game_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/combat/status/status.dart';
import 'package:runner_core/projectiles/projectile_item_def.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/weapons/weapon_proc.dart';
import 'package:runner_core/meta/gear_slot.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/spellBook/spell_book_id.dart';
import 'package:runner_core/weapons/weapon_id.dart';
import 'package:game_presentation/gear_text.dart';

void main() {
  group('gear text', () {
    test('projectile summaries use local strength and duration', () {
      const tuned = ProjectileItemDef(
        id: ProjectileId.darkBolt,
        weaponType: WeaponType.spell,
        speedUnitsPerSecond: 550,
        lifetimeSeconds: 1.3,
        colliderSizeX: 14,
        colliderSizeY: 14,
        procs: [
          WeaponProc(
            hook: ProcHook.onHit,
            statusProfileId: StatusProfileId.weakenOnHit,
            statusTuning: StatusProfileTuning(
              weaken: StatusApplicationTuning(
                magnitude: 2500,
                durationSeconds: 3,
              ),
            ),
          ),
        ],
      );
      expect(projectileStatusSummaries(tuned, strings: gameStringsFor(null)), [
        'Weaken: -25% outgoing damage for 3 seconds',
      ]);
      expect(
        projectileStatusSummaries(
          const ProjectileCatalog().get(ProjectileId.darkBolt),
          strings: gameStringsFor(null),
        ),
        ['Weaken: -50% outgoing damage for 5 seconds'],
      );
    });

    test('slot display names are resolved from UI mappings', () {
      expect(
        gearDisplayNameForSlot(
          GearSlot.mainWeapon,
          WeaponId.plainsteel,
          strings: gameStringsFor(null),
        ),
        equals('Plainsteel'),
      );
      expect(
        gearDisplayNameForSlot(
          GearSlot.spellBook,
          SpellBookId.apprenticePrimer,
          strings: gameStringsFor(null),
        ),
        equals('Apprentice Primer'),
      );
      expect(
        gearDisplayNameForSlot(
          GearSlot.spellBook,
          SpellBookId.crownOfFocus,
          strings: gameStringsFor(null),
        ),
        equals('Crown of Focus'),
      );
      expect(
        gearDisplayNameForSlot(
          GearSlot.accessory,
          AccessoryId.goldenRing,
          strings: gameStringsFor(null),
        ),
        equals('Golden Ring'),
      );
      expect(
        gearDisplayNameForSlot(
          GearSlot.accessory,
          AccessoryId.resilienceCape,
          strings: gameStringsFor(null),
        ),
        equals('Resilience Cape'),
      );
      expect(
        gearDisplayNameForSlot(
          GearSlot.accessory,
          AccessoryId.ironBoots,
          strings: gameStringsFor(null),
        ),
        equals('Iron Boots'),
      );
    });

    test('slot descriptions are resolved from UI mappings', () {
      expect(
        gearDescriptionForSlot(
          GearSlot.mainWeapon,
          WeaponId.nullblade,
          strings: gameStringsFor(null),
        ),
        equals('Anti-caster sword that can silence on hit.'),
      );
      expect(
        gearDescriptionForSlot(
          GearSlot.spellBook,
          SpellBookId.emberGrimoire,
          strings: gameStringsFor(null),
        ),
        equals(
          'Mana, critical chance and faster cooldowns, with slower stamina recovery.',
        ),
      );
      expect(
        gearDescriptionForSlot(
          GearSlot.spellBook,
          SpellBookId.apprenticePrimer,
          strings: gameStringsFor(null),
        ),
        equals(
          'Balanced mana reserves, regeneration and critical chance, with less stamina.',
        ),
      );
      expect(
        gearDescriptionForSlot(
          GearSlot.accessory,
          AccessoryId.speedBoots,
          strings: gameStringsFor(null),
        ),
        equals(
          'Tempo accessory with movement, stamina regen, and cooldown pacing at heavy mana tax.',
        ),
      );
      expect(
        gearDescriptionForSlot(
          GearSlot.accessory,
          AccessoryId.oathBeads,
          strings: gameStringsFor(null),
        ),
        equals(
          'Caster-tempo beads with cooldown, mana regen, and power at a defense tax.',
        ),
      );
    });

    test('projectile source names use the shared projectile mapping', () {
      expect(
        projectileDisplayName(
          ProjectileId.iceBolt,
          strings: gameStringsFor(null),
        ),
        'Ice Bolt',
      );
      expect(
        projectileDisplayName(
          ProjectileId.fireBolt,
          strings: gameStringsFor(null),
        ),
        'Fire Bolt',
      );
    });
  });
}
