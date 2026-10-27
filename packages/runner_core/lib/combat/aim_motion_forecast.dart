import 'dart:math' as math;

import '../collision/terrain/terrain_capsule_controller.dart';
import '../collision/terrain/terrain_edge_id.dart';
import '../collision/terrain/terrain_edge_index.dart';
import '../collision/terrain/terrain_geometry.dart';
import '../collision/terrain/terrain_motion_request.dart';
import '../collision/terrain/terrain_numeric.dart';
import '../collision/terrain/terrain_traversal_profile.dart';
import '../ecs/actor_facing.dart';
import '../ecs/entity_id.dart';
import '../ecs/world.dart';
import '../terrain/swimming_tuning.dart';
import '../tuning/physics_tuning.dart';
import '../util/fixed_math.dart';

/// One coherent published collision world used by an aim forecast.
typedef AimTerrain = ({TerrainGeometry geometry, TerrainEdgeIndex index});

/// Reusable, read-only actor forecast for committed auto aim.
///
/// Holds current horizontal motion and immersion fixed, but advances gravity,
/// suppression expiry, velocity caps and full-capsule terrain contacts at Core's
/// tick rate. It does not predict future input, AI decisions or new abilities.
/// Coordinates/velocities use world units and seconds. Call [reset] for each actor;
/// [advance] mutates only this scratch object, never the ECS or live controller.
final class AimMotionForecast {
  AimMotionForecast({
    required this.tickHz,
    this.physics = const PhysicsTuning(),
    this.terrainProvider,
  }) {
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'Must be positive.');
    }
  }

  final int tickHz;
  final PhysicsTuning physics;
  final AimTerrain Function()? terrainProvider;
  final _controllers = <TerrainTraversalProfile, TerrainCapsuleController>{};
  final _result = TerrainCapsuleMotionResult();
  TerrainGeometry? _geometry;
  TerrainCapsuleController? _controller;
  TerrainHorizontalBounds? _bounds;
  TerrainEdgeId? _support;
  int _supportVersion = -1;
  bool _grounded = false;
  bool _surfaceMotion = false;
  int _radius = 0;
  int _halfSegment = 0;
  int _offsetX = 0;
  int _offsetY = 0;
  int _suppressedTicks = 0;
  double _gravity = 0;
  double _maxRiseSpeed = double.infinity;
  double _maxFallSpeed = double.infinity;

  double x = 0;
  double y = 0;
  double velocityX = 0;
  double velocityY = 0;

  /// Whether the remaining trajectory admits the exact constant-velocity solve.
  bool get isLinear => _controller == null && _gravity == 0;

  /// Captures an actor with a transform and the current terrain publication.
  /// Missing body data omits gravity; missing terrain components omit contacts.
  void reset(EcsWorld world, EntityId entity) {
    final ti = world.transform.indexOf(entity);
    x = world.transform.posX[ti];
    y = world.transform.posY[ti];
    velocityX = world.transform.velX[ti];
    velocityY = world.transform.velY[ti];
    _controller = null;
    _bounds = null;
    _gravity = 0;
    _suppressedTicks = 0;
    _maxRiseSpeed = double.infinity;
    _maxFallSpeed = double.infinity;
    _grounded = false;
    _support = null;
    _supportVersion = -1;
    final bi = world.body.tryIndexOf(entity);
    final boundsIndex = world.actorMotionBounds.tryIndexOf(entity);
    if ((bi != null && !world.body.enabled[bi]) ||
        world.arenaSuspension.has(entity) ||
        (boundsIndex != null && world.actorMotionBounds.frozen[boundsIndex])) {
      velocityX = 0;
      velocityY = 0;
      return;
    }
    if (bi != null &&
        !world.body.isKinematic[bi] &&
        world.body.useGravity[bi]) {
      final swimming = world.swimState.isSwimming(entity);
      _gravity =
          physics.gravityY *
          world.body.gravityScale[bi] *
          (swimming ? SwimmingTuning.gravityMultiplier : 1);
      _maxRiseSpeed = world.body.maxVelY[bi];
      _maxFallSpeed = swimming
          ? math.min(_maxRiseSpeed, SwimmingTuning.maxSinkSpeed)
          : _maxRiseSpeed;
      final gi = world.gravityControl.tryIndexOf(entity);
      if (gi != null) {
        _suppressedTicks = world.gravityControl.suppressGravityTicksLeft[gi];
      }
    }

    final ci = world.worldContactCapsule.tryIndexOf(entity);
    final pi = world.terrainTraversalProfile.tryIndexOf(entity);
    if (terrainProvider == null ||
        ci == null ||
        pi == null ||
        bi == null ||
        world.body.isKinematic[bi]) {
      return;
    }
    final profile = world.terrainTraversalProfile.profile[pi];
    if (!profile.enabled || profile.isKinematic) return;
    final terrain = terrainProvider!();
    if (!identical(_geometry, terrain.geometry)) {
      _controllers.clear();
      _geometry = terrain.geometry;
    }
    _controller = _controllers.putIfAbsent(
      profile,
      () => TerrainCapsuleController(
        geometry: terrain.geometry,
        index: terrain.index,
        profile: profile,
      ),
    );
    final facingSign =
        actorFacing(world, entity) == actorArtFacing(world, entity) ? 1 : -1;
    _offsetX = world.worldContactCapsule.offsetXTicks[ci] * facingSign;
    _offsetY = world.worldContactCapsule.offsetYTicks[ci];
    _radius = world.worldContactCapsule.radiusTicks[ci];
    _halfSegment = world.worldContactCapsule.verticalHalfSegmentTicks[ci];
    final contactIndex = world.terrainContact.tryIndexOf(entity);
    if (contactIndex != null) {
      _support = world.terrainContact.supportEdgeId[contactIndex];
      _supportVersion =
          world.terrainContact.supportGeometryVersion[contactIndex];
      _grounded =
          world.terrainContact.grounded[contactIndex] &&
          _supportVersion == terrain.geometry.version;
    }
    _surfaceMotion = !world.playerInput.has(entity);
    final ni = world.npc.tryIndexOf(entity);
    _bounds = boundsIndex != null
        ? world.actorMotionBounds.bounds[boundsIndex]
        : ni == null
        ? null
        : world.npc.movementBounds[ni];
  }

  /// Advances a non-negative number of fixed ticks without changing live state.
  void advance(int ticks) {
    if (ticks < 0) {
      throw ArgumentError.value(ticks, 'ticks', 'Must be non-negative.');
    }
    if (isLinear) {
      x += velocityX * ticks / tickHz;
      y += velocityY * ticks / tickHz;
      return;
    }
    for (var i = 0; i < ticks; i++) {
      _step();
    }
  }

  void _step() {
    final dt = 1 / tickHz;
    final beforeGravity = velocityY;
    if (_suppressedTicks > 0) {
      _suppressedTicks--;
    } else if (_gravity != 0) {
      final pilot = physics.fixedPointPilot;
      velocityY += pilot.enabled
          ? accelerationDeltaPerTickFixed(
              accelerationPerSecondSq: _gravity,
              tickHz: tickHz,
              scale: pilot.subpixelScale,
            )
          : _gravity * dt;
      if (pilot.enabled) {
        velocityY = quantizeToScale(velocityY, pilot.subpixelScale);
      }
      velocityY = velocityY.clamp(-_maxRiseSpeed, _maxFallSpeed);
    }
    final controller = _controller;
    if (controller == null) {
      x += velocityX * dt;
      y += velocityY * dt;
      return;
    }
    final gravityDelta = velocityY - beforeGravity;
    final mode = _grounded
        ? _surfaceMotion
              ? TerrainMotionMode.groundedSurface
              : TerrainMotionMode.groundedHorizontal
        : TerrainMotionMode.worldSpace;
    final centerX = physicsCoordinateToTicks(x) + _offsetX;
    final centerY = physicsCoordinateToTicks(y) + _offsetY;
    final gravityDisplacement = physicsCoordinateToTicks(gravityDelta * dt);
    controller.moveAtValues(
      centerXTicks: centerX,
      centerYTicks: centerY,
      radiusTicks: _radius,
      verticalHalfSegmentTicks: _halfSegment,
      displacementXTicks: physicsCoordinateToTicks(velocityX * dt),
      displacementYTicks:
          physicsCoordinateToTicks(velocityY * dt) - gravityDisplacement,
      gravityYTicks: gravityDisplacement,
      mode: mode,
      surfaceDirectionSign: velocityX < 0 ? -1 : 1,
      horizontalBounds: _bounds,
      beganGrounded: _grounded,
      priorSupportEdgeId: _support,
      priorSupportGeometryVersion: _supportVersion,
      lastValidCapsuleCenterXTicks: centerX,
      lastValidCapsuleCenterYTicks: centerY,
      out: _result,
    );
    x =
        (_result.finalCenterXTicks - _offsetX) /
        terrainPhysicsTicksPerWorldUnit;
    y =
        (_result.finalCenterYTicks - _offsetY) /
        terrainPhysicsTicksPerWorldUnit;
    if (_result.grounded && mode == TerrainMotionMode.groundedSurface) {
      velocityY -= gravityDelta;
    }
    for (var i = 0; i < _result.contactCount; i++) {
      final nx = _result.contactNormalXTicks[i] / terrainDirectionScale;
      final ny = _result.contactNormalYTicks[i] / terrainDirectionScale;
      final dot = velocityX * nx + velocityY * ny;
      if (dot < 0) {
        velocityX -= dot * nx;
        velocityY -= dot * ny;
      }
    }
    if (_result.grounded) {
      final tx = _result.supportTangentXTicks / terrainDirectionScale;
      final ty = _result.supportTangentYTicks / terrainDirectionScale;
      if (mode == TerrainMotionMode.groundedHorizontal && tx.abs() > 1e-9) {
        velocityY = velocityX * ty / tx;
      } else if (mode == TerrainMotionMode.groundedSurface) {
        final speed = math.sqrt(velocityX * velocityX + velocityY * velocityY);
        final sign = (velocityX < 0 ? -1 : 1) * tx.sign;
        velocityX = speed * tx * sign;
        velocityY = speed * ty * sign;
      } else {
        final nx = _result.supportNormalXTicks / terrainDirectionScale;
        final ny = _result.supportNormalYTicks / terrainDirectionScale;
        final dot = velocityX * nx + velocityY * ny;
        if (dot < 0) {
          velocityX -= dot * nx;
          velocityY -= dot * ny;
        }
      }
    }
    if ((_result.hitLeft && velocityX < 0) ||
        (_result.hitRight && velocityX > 0) ||
        _result.hitHorizontalBound) {
      velocityX = 0;
    }
    if (_result.hitCeiling && velocityY < 0) velocityY = 0;
    _grounded = _result.grounded;
    _support = _result.supportEdgeId;
    _supportVersion = controller.geometry.version;
  }
}
