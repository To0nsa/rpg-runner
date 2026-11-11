import 'player_character_definition.dart';
import 'player_character_registry.dart';

/// Returns the authored ability id namespace for [characterId].
///
/// Authored prefixes need not match character IDs (for example, Willow uses
/// `bounty_hunter.*` while her character ID is `bountyHunter`).
String characterAbilityNamespace(PlayerCharacterId characterId) {
  final catalog = PlayerCharacterRegistry.resolve(characterId).catalog;
  final namespace = _namespaceFromAbilityId(catalog.abilityPrimaryId);
  if (namespace != null) return namespace;

  final spellNamespace = _namespaceFromAbilityId(catalog.abilitySpellId);
  if (spellNamespace != null) return spellNamespace;

  return characterId.name;
}

String? _namespaceFromAbilityId(String abilityId) {
  final separator = abilityId.indexOf('.');
  if (separator <= 0) return null;
  return abilityId.substring(0, separator);
}
