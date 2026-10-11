import 'dart:convert';
import 'dart:io';

import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';

/// Native startup comparison with the same eight exact terrain states.
/// Compile AOT and run with other builds/profilers idle. This excludes rendering,
/// authentication, and recorder I/O; it is not a phone loading-time measurement.
Future<void> main() async {
  for (final (level, seed) in [
    (LevelId.forest, 42),
    (LevelId.forest, 857469563),
    (LevelId.field, 42),
  ]) {
    // Reverse the ordering on the repeat to expose cold/process-order effects.
    for (final parallel in [false, true, true, false]) {
      final watch = Stopwatch()..start();
      final core = GameCore(
        seed: seed,
        levelDefinition: LevelRegistry.byId(level),
        playerCharacter: PlayerCharacterRegistry.eloise,
      );
      final constructionMicros = watch.elapsedMicroseconds;
      try {
        if (parallel) {
          await core.prepareTerrainForRun();
        } else {
          await core.prepareTerrainAhead();
        }
        final stats = core.terrainPreparationStats!;
        if (stats.lastError != null || stats.ready != 8 || core.tick != 0) {
          throw StateError(
            'Startup benchmark did not prepare its full window: $stats',
          );
        }
        stdout.writeln(
          jsonEncode({
            'level': level.name,
            'seed': seed,
            'parallel': parallel,
            'constructionMs': constructionMicros / 1000,
            'terrainMs':
                (watch.elapsedMicroseconds - constructionMicros) / 1000,
            'ready': stats.ready,
            'completed': stats.completed,
          }),
        );
      } finally {
        core.stopTerrainPreparation();
      }
    }
  }
}
