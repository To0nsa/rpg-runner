import 'dart:math';

import '../../abilities/ability_def.dart';
import '../../events/game_event.dart';
import '../../spell_impacts/spell_impact_id.dart';
import '../../util/vec2.dart';
import '../stores/hitbox_store.dart';
import '../stores/lifetime_store.dart';
import '../stores/target_point_intent_store.dart';
import '../world.dart';

/// Executes [TargetPointIntentStore] intents by spawning world-anchored hitboxes.
class TargetPointImpactSystem {
  TargetPointImpactSystem({this.queueImpactEvent});

  final void Function(SpellImpactEvent event)? queueImpactEvent;

  void step(EcsWorld world, {required int currentTick}) {
    final intents = world.targetPointIntent;
    if (intents.denseEntities.isEmpty) return;

    final factions = world.faction;

    for (var ii = 0; ii < intents.denseEntities.length; ii += 1) {
      final caster = intents.denseEntities[ii];
      final executeTick = intents.tick[ii];
      if (executeTick != currentTick) continue;

      _invalidateIntent(intents, ii);

      final fi = factions.tryIndexOf(caster);
      if (fi == null) continue;

      final hitbox = world.createEntity();
      world.transform.add(
        hitbox,
        posX: intents.targetX[ii],
        posY: intents.targetY[ii],
        velX: 0.0,
        velY: 0.0,
      );
      world.hitbox.add(
        hitbox,
        HitboxDef(
          owner: caster,
          abilityId: intents.abilityId[ii],
          faction: factions.faction[fi],
          damage100: intents.damage100[ii],
          critChanceBp: intents.critChanceBp[ii],
          damageType: intents.damageType[ii],
          procs: intents.procs[ii],
          hitPolicy: intents.hitPolicy[ii],
          sourceKind: intents.sourceKind[ii],
          attachment: HitboxAttachment.worldAnchor,
          halfX: intents.halfX[ii],
          halfY: intents.halfY[ii],
          offsetX: 0.0,
          offsetY: 0.0,
          dirX: 1.0,
          dirY: 0.0,
        ),
      );
      if (intents.hitPolicy[ii] != HitPolicy.everyTick) {
        world.hitOnce.add(hitbox);
      }
      world.lifetime.add(
        hitbox,
        LifetimeDef(ticksLeft: max(1, intents.activeTicks[ii])),
      );

      if (intents.impactEffectId[ii] != SpellImpactId.unknown) {
        final enemyIndex = world.enemy.tryIndexOf(caster);
        queueImpactEvent?.call(
          SpellImpactEvent(
            tick: currentTick,
            impactId: intents.impactEffectId[ii],
            pos: Vec2(intents.targetX[ii], intents.targetY[ii]),
            sourceEnemyId: enemyIndex == null ? null : world.enemy.enemyId[enemyIndex],
            abilityId: intents.abilityId[ii],
          ),
        );
      }
    }
  }

  void _invalidateIntent(TargetPointIntentStore intents, int index) {
    intents.tick[index] = -1;
    intents.commitTick[index] = -1;
  }
}
