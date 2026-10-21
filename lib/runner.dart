// Public entrypoint ("barrel file") for embedding the runner in a host app.
// Hosted runs wait for world and recorder readiness and expose loading recovery;
// hosts provide a server-issued ticket and an exit path (see the widget/route).
// Debug-only developer Practice uses an explicit local descriptor, requires
// world readiness only and never records, submits or rewards a run.
// Startup awaits the complete initial terrain window with bounded native
// parallelism. Runtime readiness holds missing publications before simulation;
// failure recovery retries within the same run and recorder.
// Boss entrances and arena completion remain inside that same run session.
// Hosts can choose MovementControlMode.arrows, .joystick (floating), or
// .fixedJoystick via the widget/route. All emit identical digital movement;
// the host owns preference persistence.
//
// Host apps should import only this file:
// `import 'package:rpg_runner/runner.dart';`
//
// This keeps the public API stable while allowing internal folders/files to
// evolve without breaking downstream imports.
export 'package:runner_core/levels/level_id.dart';
export 'package:runner_core/players/player_character_definition.dart';
export 'package:runner_core/players/player_character_registry.dart';

export 'ui/runner_game_route.dart';
export 'ui/controls/movement_control_mode.dart';
export 'ui/runner_game_widget.dart';
