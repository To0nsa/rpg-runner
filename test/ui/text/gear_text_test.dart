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
      expect(projectileStatusSummaries(tuned), [
        'Weaken: -25% outgoing damage for 3 seconds',
      ]);
      expect(
        projectileStatusSummaries(
          const ProjectileCatalog().get(ProjectileId.darkBolt),
        ),
        ['Weaken: -50% outgoing damage for 5 seconds'],
      );
    });

    test('slot display names are resolved from UI mappings', () {
      expect(
        gearDisplayNameForSlot(GearSlot.mainWeapon, WeaponId.plainsteel),
        equals('Plainsteel'),
      );
      expect(
        gearDisplayNameForSlot(
          GearSlot.spellBook,
          SpellBookId.apprenticePrimer,
        ),
        equals('Apprentice Primer'),
      );
      expect(
        gearDisplayNameForSlot(GearSlot.spellBook, SpellBookId.crownOfFocus),
        equals('Crown of Focus'),
      );
      expect(
        gearDisplayNameForSlot(GearSlot.accessory, AccessoryId.goldenRing),
        equals('Golden Ring'),
      );
      expect(
        gearDisplayNameForSlot(GearSlot.accessory, AccessoryId.resilienceCape),
        equals('Resilience Cape'),
      );
      expect(
        gearDisplayNameForSlot(GearSlot.accessory, AccessoryId.ironBoots),
        equals('Iron Boots'),
      );
    });

    test('slot descriptions are resolved from UI mappings', () {
      expect(
        gearDescriptionForSlot(GearSlot.mainWeapon, WeaponId.nullblade),
        equals('Anti-caster sword that can silence on hit.'),
      );
      expect(
        gearDescriptionForSlot(GearSlot.spellBook, SpellBookId.emberGrimoire),
        equals('Aggressive spellbook with burn pressure and lower defense.'),
      );
      expect(
        gearDescriptionForSlot(
          GearSlot.spellBook,
          SpellBookId.apprenticePrimer,
        ),
        equals('Baseline spellbook with small power and mana gains.'),
      );
      expect(
        gearDescriptionForSlot(GearSlot.accessory, AccessoryId.speedBoots),
        equals(
          'Tempo accessory with movement, stamina regen, and cooldown pacing at heavy mana tax.',
        ),
      );
      expect(
        gearDescriptionForSlot(GearSlot.accessory, AccessoryId.oathBeads),
        equals(
          'Caster-tempo beads with cooldown, mana regen, and power at a defense tax.',
        ),
      );
    });

    test('projectile source names use the shared projectile mapping', () {
      expect(projectileDisplayName(ProjectileId.iceBolt), 'Ice Bolt');
      expect(projectileDisplayName(ProjectileId.fireBolt), 'Fire Bolt');
    });
  });
}
