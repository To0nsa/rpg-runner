import '../../enemies/death_behavior.dart';
import '../../npcs/npc_catalog.dart';
import '../../snapshots/enums.dart';
import '../../tuning/utils/anim_tuning.dart' as anim;
import '../world.dart';
import 'actor_death_lifecycle.dart';
import 'npc_combat_lifecycle.dart';

/// NPC deaths use normal actor animation cleanup and never report enemy kills.
final class NpcDeathStateSystem {
  NpcDeathStateSystem({
    required this.tickHz,
    this.catalog = const NpcCatalog(),
  });
  final int tickHz;
  final NpcCatalog catalog;

  void step(EcsWorld world, {required int currentTick}) {
    for (var i = 0; i < world.npc.denseEntities.length; i++) {
      final entity = world.npc.denseEntities[i];
      final definition = catalog.get(world.npc.npcId[i]).renderAnim;
      final began = advanceActorDeath(
        world,
        entity,
        currentTick: currentTick,
        behavior: DeathBehavior.groundImpactThenDeath,
        deathAnimTicks: anim.ticksForKey(
          key: AnimKey.death,
          frameCounts: definition.frameCountsByKey,
          stepTimeSecondsByKey: definition.stepTimeSecondsByKey,
          tickHz: tickHz,
        ),
        maxFallTicks: 3 * tickHz,
      );
      if (began) stopNpcCombat(world, entity);
    }
  }
}
