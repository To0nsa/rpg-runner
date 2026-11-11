import 'catalog/derf_ability_defs.dart';
import 'catalog/bringer_ability_defs.dart';
import 'catalog/voidborn_goddess_ability_defs.dart';
import 'catalog/shoggoth_ability_defs.dart';
import 'catalog/voidcaller_ability_defs.dart';
import 'catalog/shoggoth_minion_ability_defs.dart';
import 'catalog/void_tentacle_ability_defs.dart';
import 'catalog/eloise_ability_defs.dart';
import 'catalog/bounty_hunter_ability_defs.dart';
import 'catalog/grojib_ability_defs.dart';
import 'catalog/hashash_ability_defs.dart';
import 'catalog/unoco_ability_defs.dart';
import 'catalog/npc_ability_defs.dart';
import 'ability_def.dart';

/// Read-only ability definition lookup contract.
///
/// Systems should depend on this interface so tests and alternate catalogs can
/// be injected without coupling to static globals.
abstract interface class AbilityResolver {
  /// Returns the authored ability for [key], or null when unknown.
  AbilityDef? resolve(AbilityKey key);
}

/// Static registry of all available abilities.
///
/// This is currently code-authored data to keep ability tuning deterministic
/// and reviewable in source control.
class AbilityCatalog implements AbilityResolver {
  const AbilityCatalog();

  /// Shared default resolver for convenience call sites.
  static const AbilityCatalog shared = AbilityCatalog();

  /// Complete ability definition table keyed by [AbilityKey].
  ///
  /// Keys should remain stable because they are referenced by loadouts, tests,
  /// and persisted run/telemetry data.
  static final Map<AbilityKey, AbilityDef> abilities = _buildAbilities();

  static Map<AbilityKey, AbilityDef> _buildAbilities() {
    final result = <AbilityKey, AbilityDef>{};
    // Validate before merging: map spreads would silently replace duplicate IDs.
    // This must also hold in release/AOT and repository generation without asserts.
    for (final source in [
      unocoAbilityDefs,
      derfAbilityDefs,
      bringerAbilityDefs,
      voidbornGoddessAbilityDefs,
      shoggothAbilityDefs,
      voidcallerAbilityDefs,
      shoggothMinionAbilityDefs,
      voidTentacleAbilityDefs,
      grojibAbilityDefs,
      hashashAbilityDefs,
      eloiseAbilityDefs,
      bountyHunterAbilityDefs,
      npcAbilityDefs,
    ]) {
      for (final entry in source.entries) {
        if (entry.key != entry.value.id) {
          throw StateError(
            'AbilityCatalog key "${entry.key}" does not match AbilityDef.id "${entry.value.id}".',
          );
        }
        if (result.containsKey(entry.key)) {
          throw StateError(
            'Duplicate AbilityDef.id "${entry.key}" in catalog.',
          );
        }
        result[entry.key] = entry.value;
      }
    }
    return Map<AbilityKey, AbilityDef>.unmodifiable(result);
  }

  @override
  AbilityDef? resolve(AbilityKey key) {
    return abilities[key];
  }
}
