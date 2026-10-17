import '../spell_impacts/spell_impact_id.dart';
import 'level_blessing.dart';

enum WorldInteractionId { regenerationShrine }

/// Appearance is selected by the authored placement, independently of the
/// gameplay preset shared by shrines in different levels.
enum WorldInteractionAppearanceId { emberFlame, blueFlame }

/// Reusable top-contact behavior, separate from the prefab providing collision.
/// Activations are player-only, once per occurrence, and persist for the attempt.
final class WorldInteractionDefinition {
  const WorldInteractionDefinition({
    required this.blessing,
    required this.grantEffectId,
  });
  final LevelBlessingId blessing;
  final SpellImpactId grantEffectId;

  static WorldInteractionDefinition get(WorldInteractionId id) => switch (id) {
    WorldInteractionId.regenerationShrine => const WorldInteractionDefinition(
      blessing: LevelBlessingId.regeneration,
      grantEffectId: SpellImpactId.holyShrineBlessing,
    ),
  };
}

/// Manual content attachment to one collision-bearing prefab in a chunk.
/// Without [placementKey], exactly one matching prefab/shape must exist. This
/// follows editor moves/scales while rejecting ambiguous duplication. An exact
/// compiled placement key can select one of several otherwise matching prefabs.
/// The trigger uses the shape's highest horizontal edge in compiled coordinates.
final class WorldInteractionBinding {
  const WorldInteractionBinding({
    required this.key,
    required this.chunkKey,
    required this.prefabKey,
    required this.shapeId,
    required this.interactionId,
    required this.appearanceId,
    this.placementKey,
    this.zIndex = 1,
  });

  final String key;
  final String chunkKey;
  final String prefabKey;
  final String shapeId;
  final String? placementKey;
  final WorldInteractionId interactionId;
  final WorldInteractionAppearanceId appearanceId;

  /// Depth relative to terrain, on the same scale as static prefab snapshots.
  final int zIndex;
}

/// Explicit opt-in content; other uses of this prefab remain decorative.
/// This catalog is consumed by normal Core, captured Play, and replay alike.
abstract final class WorldInteractionCatalog {
  static const bindings = <WorldInteractionBinding>[
    WorldInteractionBinding(
      key: 'forest_regeneration_vasque',
      chunkKey: 'forest_default_early_008',
      prefabKey: 'tiny_swords_fire_vasque_01',
      shapeId: 'collision_001',
      interactionId: WorldInteractionId.regenerationShrine,
      appearanceId: WorldInteractionAppearanceId.emberFlame,
    ),
    WorldInteractionBinding(
      key: 'field_regeneration_pot',
      chunkKey: 'field_default_easy_008',
      prefabKey: 'gandalf_hardcore_high_garden_pot_02',
      shapeId: 'collision_001',
      interactionId: WorldInteractionId.regenerationShrine,
      appearanceId: WorldInteractionAppearanceId.blueFlame,
    ),
  ];
}
