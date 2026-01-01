import '../ecs/stores/body_store.dart';
import '../ecs/stores/collider_aabb_store.dart';
import '../ecs/stores/health_store.dart';
import '../ecs/stores/mana_store.dart';
import '../ecs/stores/stamina_store.dart';
import '../snapshots/enums.dart';
import '../tuning/v0_movement_tuning.dart';
import '../tuning/v0_resource_tuning.dart';
import 'player_archetype.dart';

class PlayerCatalog {
  const PlayerCatalog({
    this.bodyTemplate = const BodyDef(
      isKinematic: false,
      useGravity: true,
      ignoreCeilings: false,
      topOnlyGround: true,
      gravityScale: 1.0,
      sideMask: BodyDef.sideLeft | BodyDef.sideRight,
    ),
    this.facing = Facing.right,
  });

  /// Template for how the player participates in physics.
  ///
  /// `maxVelX/maxVelY` are filled from `V0MovementTuning` during derivation so
  /// movement tuning remains the single source of truth for clamps.
  final BodyDef bodyTemplate;

  /// Default facing direction at spawn time.
  final Facing facing;
}

class PlayerCatalogDerived {
  const PlayerCatalogDerived._({required this.archetype});

  factory PlayerCatalogDerived.from(
    PlayerCatalog base, {
    required V0MovementTuningDerived movement,
    required V0ResourceTuning resources,
  }) {
    final body = BodyDef(
      enabled: base.bodyTemplate.enabled,
      isKinematic: base.bodyTemplate.isKinematic,
      useGravity: base.bodyTemplate.useGravity,
      ignoreCeilings: base.bodyTemplate.ignoreCeilings,
      topOnlyGround: base.bodyTemplate.topOnlyGround,
      gravityScale: base.bodyTemplate.gravityScale,
      maxVelX: movement.base.maxVelX,
      maxVelY: movement.base.maxVelY,
      sideMask: base.bodyTemplate.sideMask,
    );

    final collider = ColliderAabbDef(
      halfX: movement.base.playerRadius,
      halfY: movement.base.playerRadius,
    );

    final health = HealthDef(
      hp: resources.playerHpMax,
      hpMax: resources.playerHpMax,
      regenPerSecond: resources.playerHpRegenPerSecond,
    );
    final mana = ManaDef(
      mana: resources.playerManaMax,
      manaMax: resources.playerManaMax,
      regenPerSecond: resources.playerManaRegenPerSecond,
    );
    final stamina = StaminaDef(
      stamina: resources.playerStaminaMax,
      staminaMax: resources.playerStaminaMax,
      regenPerSecond: resources.playerStaminaRegenPerSecond,
    );

    return PlayerCatalogDerived._(
      archetype: PlayerArchetype(
        collider: collider,
        body: body,
        health: health,
        mana: mana,
        stamina: stamina,
        facing: base.facing,
      ),
    );
  }

  final PlayerArchetype archetype;
}
