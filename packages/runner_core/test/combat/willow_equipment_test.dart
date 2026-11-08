import 'package:test/test.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:runner_core/meta/gear_slot.dart';
import 'package:runner_core/players/character_equipment_policy.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/projectiles/projectile_render_catalog.dart';
import 'package:runner_core/combat/projectile_pose_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/players/characters/bounty_hunter.dart';

void main() {
  const service = MetaService();
  final fresh = service.createNew();
  test('each character has 42 items and starter ownership remains narrow', () {
    for (final character in [
      PlayerCharacterId.eloise,
      PlayerCharacterId.bountyHunter,
    ]) {
      for (final entry in {
        GearSlot.mainWeapon: 8,
        GearSlot.offhandWeapon: 10,
        GearSlot.spellBook: 8,
        GearSlot.accessory: 8,
      }.entries) {
        final candidates = service.candidatesForSlot(
          fresh,
          entry.key,
          characterId: character,
        );
        expect(candidates, hasLength(entry.value));
        expect(candidates.where((c) => c.isUnlocked), hasLength(1));
        if (entry.key != GearSlot.accessory) {
          final other = character == PlayerCharacterId.eloise
              ? PlayerCharacterId.bountyHunter
              : PlayerCharacterId.eloise;
          expect(
            candidates.any(
              (c) =>
                  CharacterEquipmentPolicy.allowsGear(other, entry.key, c.id),
            ),
            isFalse,
          );
        }
      }
      expect(
        playerEquippableProjectileIds.where(
          (id) => CharacterEquipmentPolicy.allowsProjectile(character, id),
        ),
        hasLength(8),
      );
    }
    expect(bountyHunterCatalog.startingProjectileSpellIds, {
      ProjectileId.hunterPistol,
      ProjectileId.hunterCrossbow,
      ProjectileId.hunterShotgun,
    });
  });
  test(
    'all gun variants have frame-aligned collision and matching player art',
    () {
      for (final id in hunterRangedWeaponIds) {
        final anim = const ProjectileRenderCatalog().get(id);
        for (
          var frame = 0;
          frame < anim.frameCountsByKey[AnimKey.idle]!;
          frame++
        ) {
          expect(
            ProjectilePoseCatalog.frame(id, AnimKey.idle, frame),
            isNotEmpty,
            reason: '$id/$frame',
          );
        }
        expect(bountyHunterCharacter.renderVariants.containsKey(id), isTrue);
      }
    },
  );
}
