// Public entrypoint ("barrel file") for embedding the runner in a host app.
// Hosted runs wait for world and recorder readiness and expose loading recovery;
// hosts provide a server-issued ticket and an exit path (see the widget/route).
// Web or native-debug Developer Practice uses an explicit local descriptor, requires
// world readiness only and never records, submits or rewards a run.
// Authenticated results show gold/XP immediately. AppState presentation getters
// include journaled rewards; only canonical progression authorizes spending.
// Startup awaits the complete initial terrain window with bounded native
// parallelism. Runtime readiness holds missing publications before simulation;
// failure recovery retries within the same run and recorder.
// Boss entrances and arena completion remain inside that same run session.
// Campaign hosts pass RunMode.campaign and the ticket's CampaignBinding. Finite
// missions have no board/ghost; only verified settlement unlocks progress and XP.
// The running HUD includes left/top off-screen actor markers measured from the
// visible viewport; indicators remain presentation-only and pass touches through.
// RunnerControlScheme.automatic selects desktop keyboard/mouse or mobile touch;
// hosts can force .touch or .desktop. Desktop focus loss requires explicit resume.
// Mouse aiming has no aim-ray preview on desktop or its browsers; touch keeps it.
// Hosts can choose MovementControlMode.arrows, .joystick (floating), or
// .fixedJoystick via the widget/route. All emit identical digital movement;
// the host owns preference persistence.
// Hosts add RunnerLocalizations.delegates and supportedLocales to their app.
// English is the default/fallback; locale changes must not recreate run sessions.
//
// Host apps should import only this file:
// `import 'package:rpg_runner/runner.dart';`
//
// This keeps the public API stable while allowing internal folders/files to
// evolve without breaking downstream imports.
export 'package:runner_core/levels/level_id.dart';
export 'package:runner_core/players/player_character_definition.dart';
export 'package:runner_core/players/player_character_registry.dart';
export 'package:run_protocol/campaign_binding.dart';
export 'package:run_protocol/run_mode.dart';

export 'ui/runner_game_route.dart';
export 'ui/controls/movement_control_mode.dart';
export 'ui/runner_game_widget.dart';
export 'ui/l10n/app_localization.dart' show RunnerLocalizations;

export 'ui/input/runner_control_scheme.dart';
