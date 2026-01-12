// Public entrypoint ("barrel file") for embedding the runner in a host app.
//
// Host apps should import only this file:
// `import 'package:rpg_runner/runner.dart';`
//
// This keeps the public API stable while allowing internal folders/files to
// evolve without breaking downstream imports.
export 'core/levels/level_id.dart';
export 'core/players/player_character_definition.dart';
export 'core/players/player_character_registry.dart';
export 'ui/runner_game_route.dart';
export 'ui/runner_game_widget.dart';
