import '../ecs/stores/body_store.dart';
import '../ecs/stores/collider_aabb_store.dart';
import '../ecs/stores/health_store.dart';
import '../ecs/stores/mana_store.dart';
import '../ecs/stores/stamina_store.dart';
import 'enemy_id.dart';

/// Static archetype data for enemies (V0).
///
/// IMPORTANT:
/// - Keeps per-enemy stats in one place to avoid divergence between spawn code,
///   tests, and future deterministic spawning.
/// - AI behavior tuning (cooldowns/speeds/ranges) lives in `V0EnemyTuning`.
class EnemyArchetype {
  const EnemyArchetype({
    required this.body,
    required this.collider,
    required this.health,
    required this.mana,
    required this.stamina,
  });

  final BodyDef body;
  final ColliderAabbDef collider;
  final HealthDef health;
  final ManaDef mana;
  final StaminaDef stamina;
}

class EnemyCatalog {
  const EnemyCatalog();

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
          health: HealthDef(hp: 50.0, hpMax: 50.0, regenPerSecond: 0.0),
          mana: ManaDef(mana: 80.0, manaMax: 80.0, regenPerSecond: 5.0),
          stamina: StaminaDef(stamina: 0.0, staminaMax: 0.0, regenPerSecond: 0.0),
        );
      case EnemyId.fireWorm:
        return const EnemyArchetype(
          body: BodyDef(
            isKinematic: false,
            useGravity: true,
            gravityScale: 1.0,
            sideMask: BodyDef.sideLeft | BodyDef.sideRight,
          ),
          collider: ColliderAabbDef(halfX: 12.0, halfY: 12.0),
          health: HealthDef(hp: 50.0, hpMax: 50.0, regenPerSecond: 0.0),
          mana: ManaDef(mana: 0.0, manaMax: 0.0, regenPerSecond: 0.0),
          stamina: StaminaDef(stamina: 0.0, staminaMax: 0.0, regenPerSecond: 0.0),
        );
    }
  }
}

