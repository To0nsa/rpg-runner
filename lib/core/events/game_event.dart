/// Core -> Render/UI event model.
///
/// **Architecture**:
/// - "Events" in this context are **transient side effects** emitted by the simulation.
/// - Examples: SFX triggers, Particle spawns, Run completion, Screen shake.
/// - They are distinct from "State" (Snapshots). State is continuous; Events are discrete.
///
/// **Usage**:
/// - Systems emit events into a queue.
/// - The GameController or UI layer consumes them (e.g., to play a sound or show a dialog).
/// - Events are fire-and-forget.
library;

import '../abilities/ability_def.dart';
import '../enemies/enemy_id.dart';
import '../projectiles/projectile_id.dart';
import '../snapshots/enums.dart';
import '../projectiles/projectile_item_id.dart';
import '../util/vec2.dart';

part 'run_events.dart';
part 'enemy_events.dart';
part 'projectile_events.dart';
part 'ability_events.dart';

/// Base sealed class for all simulation events.
sealed class GameEvent {
  const GameEvent();
}
