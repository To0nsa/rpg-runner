import 'dart:ui';

import 'package:runner_content_pipeline/campaign_tutorial.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/snapshots/combat_opportunity_snapshot.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';

import '../../game/game_controller.dart';
import 'campaign_tutorial_geometry.dart';

enum CombatGuidancePhase {
  approach,
  projectilePractice,
  meleePractice,
  complete,
}

/// Bounded attempt-local practice state. The controller owns cards and pause;
/// this object observes Core output and never issues gameplay commands.
final class CampaignCombatGuidance {
  CampaignCombatGuidance(this.lesson);
  final CampaignCombatTutorial lesson;
  CombatGuidancePhase phase = CombatGuidancePhase.approach;
  bool projectileLocked = false;
  CombatOpportunitySnapshot? opportunity;
  Rect? targetBounds;

  void accept(AbilitySlot slot) {
    phase = slot == AbilitySlot.projectile
        ? CombatGuidancePhase.projectilePractice
        : CombatGuidancePhase.meleePractice;
  }

  void executed(PlayerAttackExecutedEvent event) {
    if (phase == CombatGuidancePhase.projectilePractice &&
        event.slot == AbilitySlot.projectile) {
      projectileLocked = true;
    } else if (phase == CombatGuidancePhase.meleePractice &&
        event.slot == AbilitySlot.primary) {
      finish();
    }
  }

  void finish() {
    phase = CombatGuidancePhase.complete;
    projectileLocked = false;
  }

  /// Returns the page to interrupt with. Missing/dead targets and unsupported
  /// builds release guidance instead of trapping the player behind a locked slot.
  int? observe(GameController controller, {Rect? visibleWorldBounds}) {
    opportunity = controller.campaignCombatOpportunity(lesson.enemyTarget);
    final target = opportunity;
    if (target == null) {
      finish();
      return null;
    }
    final entity = controller.snapshot.entities
        .where((e) => e.id == target.entityId)
        .firstOrNull;
    targetBounds = entity == null ? null : campaignTutorialEntityBounds(entity);
    if (targetBounds == null) return null;
    final player = controller.snapshot.playerEntity;
    if (player == null) return null;
    final hud = controller.snapshot.hud;
    final distance = (target.x - player.pos.x).abs();
    final supported =
        hud.abilityPrimaryId == 'eloise.seeker_slash' &&
        hud.abilityProjectileId == 'eloise.snap_shot' &&
        hud.meleeSlotValid &&
        hud.projectileSlotValid;
    if (!supported) {
      if (distance <= lesson.approachDistance) finish();
      return null;
    }
    final ready =
        player.grounded &&
        !player.isSwimming &&
        target.playerIdle &&
        (player.controlLockMask &
                (EntityControlLockMask.stun | EntityControlLockMask.dash)) ==
            0;
    final camera = controller.snapshot.camera;
    final viewport =
        visibleWorldBounds ??
        Rect.fromLTRB(camera.left, camera.top, camera.right, camera.bottom);
    // Wait for the whole enemy and authored opening, not merely its anchor:
    // the latter can lie inside the camera while the body is still clipped.
    final opening = tutorialSpotlightRect(
      targetBounds!,
      lesson.steps.first.spotlight,
    ).expandToInclude(targetBounds!);
    final visible =
        opening.left >= viewport.left &&
        opening.right <= viewport.right &&
        opening.top >= viewport.top &&
        opening.bottom <= viewport.bottom;
    if (!ready || !visible) return null;
    if (phase == CombatGuidancePhase.approach &&
        distance <= lesson.approachDistance &&
        target.inProjectileReach &&
        hud.canAffordProjectile &&
        hud.cooldownTicksLeft[CooldownGroup.projectile] == 0) {
      return 0;
    }
    if (phase == CombatGuidancePhase.projectilePractice &&
        projectileLocked &&
        // Homing predicts the moving target through windup. Wait until its real
        // approach has stopped, so an impending AI stop cannot turn the lesson's
        // first strike into a miss. This never changes enemy motion or timing.
        target.targetStationary &&
        target.inMeleeReach &&
        hud.canAffordMelee &&
        hud.cooldownTicksLeft[CooldownGroup.primary] == 0) {
      return 2;
    }
    return null;
  }
}
