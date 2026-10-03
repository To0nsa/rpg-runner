import 'dart:convert';
import 'dart:io';

import 'package:runner_core/commands/command.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';

/// Compares projection CPU cost at identical seeded states, excluding simulation.
/// Run with the normal Dart VM from the repository workspace. Warmed medians are
/// diagnostic only: they do not measure GPU cost, frame rate or mobile hardware.
void main() {
  const iterations = 10000;
  const rounds = 7;
  var checksum = 0;
  final results = <Map<String, Object>>[];
  for (final level in [LevelId.field, LevelId.forest]) {
    final core = GameCore(
      seed: 1337,
      levelDefinition: LevelRegistry.byId(level),
      playerCharacter: PlayerCharacterRegistry.eloise,
    );
    for (var tick = 1; tick <= 180 && !core.gameOver; tick++) {
      core.applyCommands([
        MoveAxisCommand(tick: tick, axis: 1),
        if (tick % 45 == 0) JumpPressedCommand(tick: tick),
        if (tick % 35 == 0) ProjectilePressedCommand(tick: tick),
      ]);
      core.stepOneTick();
    }
    for (var warmup = 0; warmup < 3000; warmup++) {
      checksum += core.buildSnapshot().entities.length;
      checksum += core.buildActorFrameSnapshot().entities.length;
    }
    double measure(bool actorsOnly) {
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        checksum += actorsOnly
            ? core.buildActorFrameSnapshot().entities.length
            : core.buildSnapshot().entities.length;
      }
      return stopwatch.elapsedMicroseconds / iterations;
    }

    final full = <double>[];
    final actor = <double>[];
    for (var round = 0; round < rounds; round++) {
      if (round.isEven) {
        full.add(measure(false));
        actor.add(measure(true));
      } else {
        actor.add(measure(true));
        full.add(measure(false));
      }
    }
    full.sort();
    actor.sort();
    results.add({
      'level': level.name,
      'seed': 1337,
      'tick': core.tick,
      'fullEntities': core.buildSnapshot().entities.length,
      'actorEntities': core.buildActorFrameSnapshot().entities.length,
      'iterationsPerRound': iterations,
      'rounds': rounds,
      'fullMedianUs': full[rounds ~/ 2],
      'actorMedianUs': actor[rounds ~/ 2],
      'projectionSpeedup': full[rounds ~/ 2] / actor[rounds ~/ 2],
    });
    core.stopTerrainPreparation();
  }
  stdout.writeln(
    const JsonEncoder.withIndent('  ')
        .convert({'results': results, 'checksum': checksum}),
  );
}
