import 'package:runner_core/levels/level_definition.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/tuning/core_tuning.dart';

const PlayerCharacterDefinition testPlayerCharacter =
    PlayerCharacterRegistry.eloise;

/// Builds a test level from the registry with optional deterministic overrides.
LevelDefinition testLevel({
  LevelId id = LevelId.field,
  CoreTuning? tuning,
  double? groundTopY,
}) {
  final base = LevelRegistry.byId(id);
  return base.copyWith(tuning: tuning, groundTopY: groundTopY);
}

/// Field-level convenience wrapper used by most tests.
LevelDefinition testFieldLevel({CoreTuning? tuning, double? groundTopY}) {
  return testLevel(id: LevelId.field, tuning: tuning, groundTopY: groundTopY);
}
