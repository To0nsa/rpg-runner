/// Environmental attacks share combat collision without inventing a faction.
enum HitTargetPolicy {
  /// Standard owner exclusion and faction friendly-fire filtering.
  hostile,

  /// Living damageable actors of either faction, with no attacker identity.
  allActors,
}
