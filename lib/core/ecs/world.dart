import '../math/vec2.dart';
import '../snapshots/enums.dart';
import 'entity_id.dart';
import 'stores/body_store.dart';
import 'stores/collider_aabb_store.dart';
import 'stores/collision_state_store.dart';
import 'stores/health_store.dart';
import 'stores/mana_store.dart';
import 'stores/movement_store.dart';
import 'stores/player_input_store.dart';
import 'stores/stamina_store.dart';
import 'stores/transform_store.dart';

/// Minimal ECS world container (V0).
///
/// Entity IDs are monotonic and never reused.
class EcsWorld {
  EntityId _nextEntityId = 1;

  final TransformStore transform = TransformStore();
  final PlayerInputStore playerInput = PlayerInputStore();
  final MovementStore movement = MovementStore();
  final BodyStore body = BodyStore();
  final ColliderAabbStore colliderAabb = ColliderAabbStore();
  final CollisionStateStore collision = CollisionStateStore();
  final HealthStore health = HealthStore();
  final ManaStore mana = ManaStore();
  final StaminaStore stamina = StaminaStore();

  EntityId createEntity() {
    final id = _nextEntityId;
    _nextEntityId += 1;
    return id;
  }

  EntityId createPlayer({
    required Vec2 pos,
    required Vec2 vel,
    required Facing facing,
    required bool grounded,
    required BodyDef body,
    required ColliderAabbDef collider,
    required HealthDef health,
    required ManaDef mana,
    required StaminaDef stamina,
  }) {
    final id = createEntity();
    transform.add(id, pos: pos, vel: vel);
    playerInput.add(id);
    movement.add(id, facing: facing);
    this.body.add(id, body);
    colliderAabb.add(id, collider);
    collision.add(id);
    this.health.add(id, health);
    this.mana.add(id, mana);
    this.stamina.add(id, stamina);
    collision.grounded[collision.indexOf(id)] = grounded;
    return id;
  }
}
