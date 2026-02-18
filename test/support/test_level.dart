import 'package:rpg_runner/core/collision/static_world_geometry.dart';
import 'package:rpg_runner/core/levels/level_definition.dart';
import 'package:rpg_runner/core/levels/level_id.dart';
import 'package:rpg_runner/core/levels/level_registry.dart';
import 'package:rpg_runner/core/players/player_character_definition.dart';
import 'package:rpg_runner/core/players/player_character_registry.dart';
import 'package:rpg_runner/core/tuning/core_tuning.dart';

const PlayerCharacterDefinition testPlayerCharacter =
    PlayerCharacterRegistry.eloise;

/// Builds a test level from the registry with optional deterministic overrides.
LevelDefinition testLevel({
  LevelId id = LevelId.field,
  CoreTuning? tuning,
  StaticWorldGeometry? staticWorldGeometry,
}) {
  final base = LevelRegistry.byId(id);
  return base.copyWith(
    tuning: tuning,
    staticWorldGeometry: staticWorldGeometry,
  );
}

/// Field-level convenience wrapper used by most tests.
LevelDefinition testFieldLevel({
  CoreTuning? tuning,
  StaticWorldGeometry? staticWorldGeometry,
}) {
  return testLevel(
    id: LevelId.field,
    tuning: tuning,
    staticWorldGeometry: staticWorldGeometry,
  );
}
