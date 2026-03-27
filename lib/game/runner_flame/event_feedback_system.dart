import 'dart:math' as dart_math;

import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';

import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/snapshots/enums.dart';

import '../components/camera_space_snapped_sprite_animation.dart';
import '../components/player/player_view.dart';
import '../components/projectiles/projectile_render_registry.dart';
import '../components/spell_impacts/spell_impact_render_registry.dart';
import '../components/sprite_anim/deterministic_anim_view.dart';
import '../tuning/combat_feedback_tuning.dart';
import 'camera_shake_controller.dart';
import 'render_constants.dart';

/// Buffers transient render-only feedback events and flushes them to views.
class RunEventFeedbackSystem {
  RunEventFeedbackSystem({
    required this.world,
    required this.projectileRenderRegistry,
    required this.spellImpactRenderRegistry,
    required this.combatFeedbackTuning,
    required this.cameraShakeController,
  });

  final Component world;
  final ProjectileRenderRegistry projectileRenderRegistry;
  final SpellImpactRenderRegistry spellImpactRenderRegistry;
  final CombatFeedbackTuning combatFeedbackTuning;
  final CameraShakeController cameraShakeController;

  final List<ProjectileHitEvent> _pendingProjectileHitEvents =
      <ProjectileHitEvent>[];
  final List<SpellImpactEvent> _pendingSpellImpactEvents = <SpellImpactEvent>[];
  final List<EntityVisualCueEvent> _pendingEntityVisualCueEvents =
      <EntityVisualCueEvent>[];

  void handleGameEvent(GameEvent event) {
    if (event is PlayerImpactFeedbackEvent) {
      cameraShakeController.trigger(
        intensity01: _shakeIntensityFromDamage100(event.amount100),
      );
      return;
    }
    if (event is EntityVisualCueEvent) {
      _pendingEntityVisualCueEvents.add(event);
      return;
    }
    if (event is ProjectileHitEvent) {
      _pendingProjectileHitEvents.add(event);
      return;
    }
    if (event is SpellImpactEvent) {
      _pendingSpellImpactEvents.add(event);
    }
  }

  void flushEntityVisualCueEvents({
    required int? playerEntityId,
    required PlayerView playerView,
    required Map<int, DeterministicAnimView> enemyViews,
  }) {
    if (_pendingEntityVisualCueEvents.isEmpty) {
      return;
    }

    for (final event in _pendingEntityVisualCueEvents) {
      final intensity01 = _visualCueIntensity01(event.intensityBp);
      if (intensity01 <= 0.0) {
        continue;
      }

      final DeterministicAnimView? view;
      if (playerEntityId != null && event.entityId == playerEntityId) {
        view = playerView;
      } else {
        view = enemyViews[event.entityId];
      }
      if (view == null) {
        continue;
      }

      switch (event.kind) {
        case EntityVisualCueKind.directHit:
          view.triggerDirectHitFlash(intensity01: intensity01);
        case EntityVisualCueKind.dotPulse:
          view.triggerDotPulse(
            color: combatFeedbackTuning.dotColorFor(event.damageType),
            intensity01: intensity01,
          );
        case EntityVisualCueKind.resourcePulse:
          view.triggerResourcePulse(
            color: combatFeedbackTuning.resourceColorFor(event.resourceType),
            intensity01: intensity01,
          );
      }
    }

    _pendingEntityVisualCueEvents.clear();
  }

  void flushProjectileHitEvents({
    required Vector2 cameraCenter,
    required int priority,
  }) {
    if (_pendingProjectileHitEvents.isEmpty) {
      return;
    }

    for (final event in _pendingProjectileHitEvents) {
      final entry = projectileRenderRegistry.entryFor(event.projectileId);
      if (entry == null) {
        continue;
      }

      final hitAnim = entry.animSet.animations[AnimKey.hit];
      if (hitAnim == null) {
        continue;
      }

      final component = CameraSpaceSnappedSpriteAnimation(
        animation: hitAnim,
        size: entry.animSet.frameSize.clone(),
        worldPosX: event.pos.x,
        worldPosY: event.pos.y,
        anchor: entry.animSet.anchor,
        paint: Paint()..filterQuality = FilterQuality.none,
        removeOnFinish: true,
      )..priority = priority;

      component.scale.setValues(entry.renderScale.x, entry.renderScale.y);
      component.angle = event.rotationRad;
      component.snapToCamera(cameraCenter);
      world.add(component);
    }

    _pendingProjectileHitEvents.clear();
  }

  void flushSpellImpactEvents({
    required Vector2 cameraCenter,
    required int priority,
  }) {
    if (_pendingSpellImpactEvents.isEmpty) {
      return;
    }

    for (final event in _pendingSpellImpactEvents) {
      final entry = spellImpactRenderRegistry.entryFor(event.impactId);
      if (entry == null) {
        continue;
      }

      final hitAnim = entry.animSet.animations[AnimKey.hit];
      if (hitAnim == null) {
        continue;
      }

      final component = CameraSpaceSnappedSpriteAnimation(
        animation: hitAnim,
        size: entry.animSet.frameSize.clone(),
        worldPosX: event.pos.x,
        worldPosY: event.pos.y,
        anchor: entry.animSet.anchor,
        paint: Paint()..filterQuality = FilterQuality.none,
        removeOnFinish: true,
      )..priority = priority;

      component.scale.setValues(entry.renderScale.x, entry.renderScale.y);
      component.snapToCamera(cameraCenter);
      world.add(component);
    }

    _pendingSpellImpactEvents.clear();
  }

  double _shakeIntensityFromDamage100(int amount100) {
    if (amount100 <= 0) {
      return 0.0;
    }
    final normalized = (amount100 / damageForMaxShake100).clamp(0.0, 1.0);
    return dart_math.sqrt(normalized);
  }

  double _visualCueIntensity01(int intensityBp) {
    if (intensityBp <= 0) {
      return 0.0;
    }
    return (intensityBp / visualCueIntensityScaleBp).clamp(0.0, 1.0);
  }
}
