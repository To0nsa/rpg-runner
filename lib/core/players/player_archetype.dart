import '../ecs/stores/body_store.dart';
import '../ecs/stores/collider_aabb_store.dart';
import '../ecs/stores/health_store.dart';
import '../ecs/stores/mana_store.dart';
import '../ecs/stores/stamina_store.dart';
import '../snapshots/enums.dart';

class PlayerArchetype {
  const PlayerArchetype({
    required this.collider,
    required this.body,
    required this.health,
    required this.mana,
    required this.stamina,
    this.facing = Facing.right,
  });

  final ColliderAabbDef collider;

  /// Template for how the player participates in physics (body flags/constraints).
  final BodyDef body;

  final HealthDef health;
  final ManaDef mana;
  final StaminaDef stamina;

  /// Default facing direction at spawn time.
  final Facing facing;
}
