import '../math/vec2.dart';
import '../snapshots/enums.dart';
import 'entity_id.dart';
import 'stores/movement_store.dart';
import 'stores/player_input_store.dart';
import 'stores/transform_store.dart';

/// Minimal ECS world container (V0).
///
/// Entity IDs are monotonic and never reused.
class EcsWorld {
  EntityId _nextEntityId = 1;

  final TransformStore transform = TransformStore();
  final PlayerInputStore playerInput = PlayerInputStore();
  final MovementStore movement = MovementStore();

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
  }) {
    final id = createEntity();
    transform.add(id, pos: pos, vel: vel);
    playerInput.add(id);
    movement.add(id, grounded: grounded, facing: facing);
    return id;
  }
}
