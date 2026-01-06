/// Defines the side an entity belongs to in combat.
///
/// Factions determine friend-or-foe relationships for targeting and collision.
enum Faction {
  /// The player and their allies/summons.
  player,

  /// Hostile entities that attack the player.
  enemy
}

