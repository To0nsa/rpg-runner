import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/snapshots/actor_frame_snapshot.dart';
import 'package:run_protocol/replay_blob.dart';

/// One atomic publication of a replay's adjacent ticks and transient events.
///
/// Events belong only to this publication; consumers must not read them again
/// when interpolating subsequent render frames. Snapshot ticks are simulation
/// ticks, including when playback catches up across several ticks at once.
/// At initialization or completion both snapshots describe the same frozen tick.
class GhostRenderFrame {
  GhostRenderFrame({
    required this.replayBlob,
    required this.previous,
    required this.current,
    required Iterable<GameEvent> events,
  }) : events = List<GameEvent>.unmodifiable(events);

  final ReplayBlobV1 replayBlob;
  final ActorFrameSnapshot previous;
  final ActorFrameSnapshot current;
  final List<GameEvent> events;
}
