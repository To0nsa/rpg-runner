import 'package:runner_core/ecs/systems/active_ability_phase_system.dart';
import 'package:runner_core/ecs/systems/anim/anim_system.dart';
import 'package:runner_core/ecs/systems/combat_hurtbox_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/players/player_tuning.dart';

/// Resolves the same pre-combat poses as Core for isolated NPC combat tests.
void resolveCombatPoses(EcsWorld world, int tick, {int tickHz = 60}) {
  const ActiveAbilityPhaseSystem().step(world, currentTick: tick);
  final tuning = PlayerCharacterRegistry.eloise.tuning;
  AnimSystem(
    tickHz: tickHz,
    enemyCatalog: const EnemyCatalog(),
    playerMovement: MovementTuningDerived.from(tuning.movement, tickHz: tickHz),
    playerAnimTuning: AnimTuningDerived.from(tuning.anim, tickHz: tickHz),
  ).step(world, player: -1, currentTick: tick);
  CombatHurtboxSystem(tickHz: tickHz).step(world);
}
