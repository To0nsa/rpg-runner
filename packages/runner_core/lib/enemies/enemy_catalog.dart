import 'catalog/bringer_of_death_enemy.dart';
import 'catalog/derf_enemy.dart';
import 'catalog/grojib_enemy.dart';
import 'catalog/hashash_enemy.dart';
import 'catalog/shoggoth_enemy.dart';
import 'catalog/shoggoth_minion_enemy.dart';
import 'catalog/unoco_enemy.dart';
import 'catalog/void_tentacle_enemy.dart';
import 'catalog/voidborn_goddess_enemy.dart';
import 'catalog/voidcaller_enemy.dart';
import 'enemy_archetype.dart';
import 'enemy_id.dart';
import 'enemy_terrain_profile.dart';

export 'enemy_archetype.dart';

/// Enemy lookup; tune individual definitions in `catalog/<name>_enemy.dart`.
class EnemyCatalog {
  const EnemyCatalog();

  /// Returns the shared, constant spawn and presentation definition for [id].
  EnemyArchetype get(EnemyId id) => switch (id) {
    EnemyId.unocoDemon => unocoArchetype,
    EnemyId.grojib => grojibArchetype,
    EnemyId.hashash => hashashArchetype,
    EnemyId.bringerOfDeath => bringerArchetype,
    EnemyId.voidbornGoddess => voidbornGoddessArchetype,
    EnemyId.shoggoth => shoggothArchetype,
    EnemyId.voidcaller => voidcallerArchetype,
    EnemyId.shoggothMinion => shoggothMinionArchetype,
    EnemyId.voidTentacle => voidTentacleArchetype,
    EnemyId.derf => derfArchetype,
  };

  /// Returns the explicit polygon-terrain policy for [id].
  ///
  /// The returned profile is catalog-owned and initialized once. The
  /// exhaustive switch makes adding an enemy without choosing a terrain
  /// policy a compile-time error.
  EnemyTerrainContactProfile terrainContactProfile(EnemyId id) {
    return switch (id) {
      EnemyId.unocoDemon => unocoTerrainProfile,
      EnemyId.grojib => grojibTerrainProfile,
      EnemyId.hashash => hashashTerrainProfile,
      EnemyId.derf => derfTerrainProfile,
      EnemyId.bringerOfDeath => bringerTerrainProfile,
      EnemyId.voidbornGoddess => voidbornGoddessTerrainProfile,
      EnemyId.shoggoth => shoggothTerrainProfile,
      EnemyId.voidcaller => voidcallerTerrainProfile,
      EnemyId.shoggothMinion => shoggothMinionTerrainProfile,
      EnemyId.voidTentacle => voidTentacleTerrainProfile,
    };
  }
}
