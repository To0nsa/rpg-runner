/// Core -> Render/UI event model.
///
/// Events are transient side effects emitted by the simulation (SFX triggers,
/// screen shake, spawn/despawn notifications, etc.). Render/UI may consume them
/// once; gameplay truth still comes from snapshots.
part 'run_events.dart';

sealed class GameEvent {
  const GameEvent();
}
