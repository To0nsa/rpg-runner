import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:runner_core/meta/meta_state.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:test/test.dart';

void main() {
  test('only Éloïse and Willow have runtime identities', () {
    expect(PlayerCharacterId.values.map((id) => id.name), [
      'eloise',
      'bountyHunter',
    ]);
    expect(
      PlayerCharacterRegistry.all.map((c) => c.id),
      PlayerCharacterId.values,
    );
    expect(PlayerCharacterRegistry.playable, PlayerCharacterRegistry.all);
    expect(
      () => PlayerCharacterId.values.byName('eloiseWip'),
      throwsArgumentError,
    );
  });

  test(
    'retired ownership preserves earned skills without replacing current gear',
    () {
      final fallback = const MetaService().createNew();
      final json = fallback.toJson();
      final ownership = json['abilityOwnershipByCharacter'] as Map;
      ownership['eloiseWip'] = {
        'projectileSpells': ['fireBolt'],
        'abilitiesBySlot': {
          'spell': ['eloise.arcane_ward', 'eloise.focus'],
        },
      };
      (json['equippedByCharacter'] as Map)['eloiseWip'] = {
        'mainWeaponId': 'waspfang',
      };
      final restored = MetaState.fromJson(json, fallback: fallback);
      final eloise = restored.abilityOwnershipFor(PlayerCharacterId.eloise);
      expect(eloise.learnedProjectileSpellIds, contains(ProjectileId.fireBolt));
      expect(eloise.learnedProjectileSpellIds, contains(ProjectileId.acidBolt));
      expect(
        eloise.learnedAbilityIdsForSlot(AbilitySlot.spell),
        containsAll(['eloise.arcane_ward', 'eloise.focus']),
      );
      expect(
        restored.equippedFor(PlayerCharacterId.eloise).toJson(),
        fallback.equippedFor(PlayerCharacterId.eloise).toJson(),
      );
      expect(restored.toJson().toString(), isNot(contains('eloiseWip')));
      expect(
        MetaState.fromJson(restored.toJson(), fallback: fallback).toJson(),
        restored.toJson(),
      );
      expect(ownership, contains('eloiseWip'));
    },
  );
}
