import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/meta/meta_state.dart';
import 'package:runner_core/players/player_character_definition.dart';

import '../../l10n/app_localization.dart';
import '../../state/ownership/progression_state.dart';

/// Ranged sources are equipment; techniques using them belong to Training.
enum TownService {
  equipment,
  training;

  String label(AppLocalizations l10n) => switch (this) {
    equipment => l10n.townEquipment,
    training => l10n.townTraining,
  };

  bool includes(StoreOfferState offer) =>
      (offer.domain == StoreDomain.ability) == (this == training);

  List<StoreSlot> get slots => switch (this) {
    equipment => const [
      StoreSlot.mainWeapon,
      StoreSlot.offhandWeapon,
      StoreSlot.spellBook,
      StoreSlot.projectile,
      StoreSlot.accessory,
    ],
    training => const [
      StoreSlot.primary,
      StoreSlot.secondary,
      StoreSlot.projectile,
      StoreSlot.mobility,
      StoreSlot.jump,
      StoreSlot.spell,
    ],
  };
}

/// Presentation-only ownership lookup; spending and grants remain server-authoritative.
bool townOfferOwned(
  MetaState meta,
  PlayerCharacterId characterId,
  StoreOfferState offer,
) {
  final inventory = meta.inventory;
  final ownership = meta.abilityOwnershipFor(characterId);
  return switch (offer.domain) {
    StoreDomain.gear => switch (offer.slot) {
      StoreSlot.mainWeapon || StoreSlot.offhandWeapon =>
        inventory.unlockedWeaponIds.any((id) => id.name == offer.itemId),
      StoreSlot.spellBook => inventory.unlockedSpellBookIds.any(
        (id) => id.name == offer.itemId,
      ),
      StoreSlot.accessory => inventory.unlockedAccessoryIds.any(
        (id) => id.name == offer.itemId,
      ),
      _ => false,
    },
    StoreDomain.projectileSpell => ownership.learnedProjectileSpellIds.any(
      (id) => id.name == offer.itemId,
    ),
    StoreDomain.ability => AbilitySlot.values.any(
      (slot) =>
          slot.name == offer.slot.name &&
          ownership.learnedAbilityIdsForSlot(slot).contains(offer.itemId),
    ),
  };
}
