import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../combat/damage.dart';
import '../../combat/status/status.dart';
import '../../events/game_event.dart';
import '../hit/hit_resolver.dart';
import '../spatial/broadphase_grid.dart';
import '../world.dart';

/// Applies authored mobility contact impacts while mobility abilities are active.
///
/// This covers roll/dash overlap effects (status and optional damage) without
/// requiring synthetic hitbox entities.
class MobilityImpactSystem {
  MobilityImpactSystem({required this.abilities});

  final AbilityResolver abilities;
  final HitResolver _resolver = HitResolver();
  final List<int> _overlaps = <int>[];

  void step(
    EcsWorld world,
    BroadphaseGrid broadphase, {
    required int currentTick,
    void Function(StatusRequest request)? queueStatus,
  }) {
    if (broadphase.targets.isEmpty) return;

    final active = world.activeAbility;
    if (active.denseEntities.isEmpty) return;

    final factions = world.faction;
    final transforms = world.transform;
    final colliders = world.colliderAabb;

    for (var i = 0; i < active.denseEntities.length; i += 1) {
      final source = active.denseEntities[i];
      final abilityId = active.abilityId[i];
      if (abilityId == null || abilityId.isEmpty) continue;
      if (active.slot[i] != AbilitySlot.mobility) continue;
      if (active.phase[i] != AbilityPhase.active) continue;
      if (world.deathState.has(source)) continue;

      final ability = abilities.resolve(abilityId);
      if (ability == null) continue;
      final impact = ability.mobilityImpact;
      if (!impact.hasAnyEffect) continue;

      final hasDamage = impact.damage100 > 0;
      final hasStatus =
          queueStatus != null && impact.statusProfileId != StatusProfileId.none;
      if (!hasDamage && !hasStatus) continue;

      final sourceFactionIndex = factions.tryIndexOf(source);
      final sourceTransformIndex = transforms.tryIndexOf(source);
      final sourceColliderIndex = colliders.tryIndexOf(source);
      if (sourceFactionIndex == null ||
          sourceTransformIndex == null ||
          sourceColliderIndex == null) {
        continue;
      }

      final sourceCenterX =
          transforms.posX[sourceTransformIndex] +
          colliders.offsetX[sourceColliderIndex];
      final sourceCenterY =
          transforms.posY[sourceTransformIndex] +
          colliders.offsetY[sourceColliderIndex];
      final sourceHalfX = colliders.halfX[sourceColliderIndex];
      final sourceHalfY = colliders.halfY[sourceColliderIndex];

      _resolver.collectOrderedOverlapsCenters(
        broadphase: broadphase,
        centerX: sourceCenterX,
        centerY: sourceCenterY,
        halfX: sourceHalfX,
        halfY: sourceHalfY,
        owner: source,
        sourceFaction: factions.faction[sourceFactionIndex],
        outTargetIndices: _overlaps,
      );
      if (_overlaps.isEmpty) continue;

      final activationTick = active.startTick[i];
      final sourceEnemyIndex = world.enemy.tryIndexOf(source);
      final sourceEnemyId = sourceEnemyIndex == null
          ? null
          : world.enemy.enemyId[sourceEnemyIndex];

      for (var oi = 0; oi < _overlaps.length; oi += 1) {
        final target = broadphase.targets.entities[_overlaps[oi]];
        final shouldApply = world.mobilityImpactState.registerImpact(
          source: source,
          target: target,
          activationTick: activationTick,
          hitPolicy: impact.hitPolicy,
        );
        if (!shouldApply) continue;

        if (hasDamage) {
          world.damageQueue.add(
            DamageRequest(
              target: target,
              amount100: impact.damage100,
              critChanceBp: impact.critChanceBp,
              damageType: impact.damageType,
              procs: impact.procs,
              source: source,
              sourceKind: DeathSourceKind.meleeHitbox,
              sourceEnemyId: sourceEnemyId,
            ),
          );
        }

        if (hasStatus) {
          queueStatus(
            StatusRequest(
              target: target,
              profileId: impact.statusProfileId,
              damageType: impact.damageType,
            ),
          );
        }

        if (impact.hitPolicy == HitPolicy.once) break;
      }
    }
  }
}
