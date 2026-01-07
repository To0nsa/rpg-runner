import '../ecs/stores/body_store.dart';
import '../ecs/stores/collider_aabb_store.dart';
import '../ecs/stores/health_store.dart';
import '../ecs/stores/mana_store.dart';
import '../ecs/stores/stamina_store.dart';
import 'enemy_id.dart';

/// Defines the base stats and physics properties for an enemy type.
///
/// This data is "static" (read-only) configuration used to initialize
/// the ECS components effectively when an enemy spawns.
class EnemyArchetype {
  const EnemyArchetype({
    required this.body,
    required this.collider,
    required this.health,
    required this.mana,
    required this.stamina,
  });

  /// Physics configuration (Gravity, Constraints, Kinematics).
  final BodyDef body;
  
  /// Hitbox size (Collision).
  final ColliderAabbDef collider;
  
  /// Vitals (HP, Mana, Stamina) configuration.
  final HealthDef health;
  final ManaDef mana;
  final StaminaDef stamina;
}

/// Central registry for Enemy Definitions.
///
/// **Usage**:
/// - Accessed by `EnemySpawnSystem` (or similar) to hydration entities.
/// - Decouples "What an enemy is" from "How to spawn it".
class EnemyCatalog {
  const EnemyCatalog();

  /// Returns the static archetype definition for a given [EnemyId].
  ///
  /// Note: The returned objects are `const` and allocation-light.
  EnemyArchetype get(EnemyId id) {
    switch (id) {
      case EnemyId.flyingEnemy:
        return const EnemyArchetype(
          body: BodyDef(
            isKinematic: false,
            useGravity: false,
            gravityScale: 0.0,
            sideMask: BodyDef.sideNone,
            maxVelX: 800.0,
            maxVelY: 800.0,
          ),
          collider: ColliderAabbDef(halfX: 12.0, halfY: 12.0),
          health: HealthDef(hp: 20.0, hpMax: 20.0, regenPerSecond: 0.5),
          mana: ManaDef(mana: 80.0, manaMax: 80.0, regenPerSecond: 5.0),
          stamina: StaminaDef(stamina: 0.0, staminaMax: 0.0, regenPerSecond: 0.0),
        );
        
      case EnemyId.groundEnemy:
        return const EnemyArchetype(
          body: BodyDef(
            isKinematic: false,
            useGravity: true,
            ignoreCeilings: true,
            gravityScale: 1.0,
            sideMask: BodyDef.sideLeft | BodyDef.sideRight,
          ),
          collider: ColliderAabbDef(halfX: 12.0, halfY: 12.0),
          health: HealthDef(hp: 20.0, hpMax: 20.0, regenPerSecond: 0.5),
          mana: ManaDef(mana: 0.0, manaMax: 0.0, regenPerSecond: 0.0),
          stamina: StaminaDef(stamina: 0.0, staminaMax: 0.0, regenPerSecond: 0.0),
        );
    }
  }
}

