import '../collision/terrain/capsule_segment_kernel.dart';
import '../collision/terrain/terrain_contact_policy.dart';
import '../collision/terrain/terrain_edge_id.dart';
import '../collision/terrain/terrain_edge_index.dart';
import '../collision/terrain/terrain_geometry.dart';
import '../collision/terrain/terrain_numeric.dart';
import '../collision/terrain/terrain_polygon.dart';
import '../collision/terrain/terrain_query_buffer.dart';
import '../collision/terrain/terrain_traversal_cache.dart';
import '../collision/terrain/terrain_traversal_profile.dart';
import 'terrain_surface_query_buffer.dart';
import 'terrain_surface_spatial_index.dart';
import 'types/terrain_navigation_surface.dart';

/// Stable outcome of an actor-neutral terrain placement query.
enum TerrainPlacementValidity {
  valid,
  geometryVersionMismatch,
  intendedSupportMissing,
  noSupport,
  profileIneligible,
  outsideSupport,
  outsideVerticalRange,
  insufficientSupportWidth,
  outsideStandableRange,
  blockedClearance,
}

/// Whether a clearance-only query treats one-way faces as physical terrain.
enum TerrainOneWayClearancePolicy {
  /// Use the traversal profile and block penetration from the front side only.
  useTraversalProfile,

  /// Ignore every one-way edge, including endpoint and backside contacts.
  ignore,
}

/// Kind of horizontal foothold required around the capsule center.
enum TerrainSupportRequirementKind { runtimeNavigation, groundedSpawn }

/// Exact rational support-width rule used by placement and navigation.
class TerrainSupportRequirement {
  /// Preserves the current grounded-enemy runtime foothold of one third.
  const TerrainSupportRequirement.groundedEnemyRuntime()
    : kind = TerrainSupportRequirementKind.runtimeNavigation,
      numerator = 1,
      denominator = 3;

  /// Creates a profile-owned runtime foothold fraction in `(0, 1]`.
  factory TerrainSupportRequirement.runtimeNavigation({
    required int numerator,
    required int denominator,
  }) {
    if (numerator <= 0 || denominator <= 0 || numerator > denominator) {
      throw ArgumentError('Runtime support fraction must be in (0, 1].');
    }
    return TerrainSupportRequirement._(
      kind: TerrainSupportRequirementKind.runtimeNavigation,
      numerator: numerator,
      denominator: denominator,
    );
  }

  /// Requires the entire horizontal capsule diameter for a grounded spawn.
  const TerrainSupportRequirement.groundedSpawn()
    : kind = TerrainSupportRequirementKind.groundedSpawn,
      numerator = 1,
      denominator = 1;

  const TerrainSupportRequirement._({
    required this.kind,
    required this.numerator,
    required this.denominator,
  });

  final TerrainSupportRequirementKind kind;
  final int numerator;
  final int denominator;

  /// Minimum supported horizontal width, rounded up in physics ticks.
  int requiredWidthTicks(int radiusTicks) =>
      _divideCeil(2 * radiusTicks * numerator, denominator);
}

/// Resolved capsule dimensions and body-relative center offset.
class TerrainPlacementCapsule {
  factory TerrainPlacementCapsule({
    required int radiusTicks,
    required int verticalHalfSegmentTicks,
    int resolvedOffsetXTicks = 0,
    int offsetYTicks = 0,
  }) {
    if (radiusTicks <= 0 || verticalHalfSegmentTicks < 0) {
      throw ArgumentError(
        'Placement capsules need a positive radius and non-negative spine.',
      );
    }
    if (radiusTicks > terrainMaxAbsPhysicsTicks ||
        verticalHalfSegmentTicks > terrainMaxAbsPhysicsTicks ||
        resolvedOffsetXTicks.abs() > terrainMaxAbsPhysicsTicks ||
        offsetYTicks.abs() > terrainMaxAbsPhysicsTicks) {
      throw RangeError('Placement capsule values exceed the physics range.');
    }
    return TerrainPlacementCapsule._(
      radiusTicks: radiusTicks,
      verticalHalfSegmentTicks: verticalHalfSegmentTicks,
      resolvedOffsetXTicks: resolvedOffsetXTicks,
      offsetYTicks: offsetYTicks,
    );
  }

  const TerrainPlacementCapsule._({
    required this.radiusTicks,
    required this.verticalHalfSegmentTicks,
    required this.resolvedOffsetXTicks,
    required this.offsetYTicks,
  });

  final int radiusTicks;
  final int verticalHalfSegmentTicks;

  /// Already-facing-resolved horizontal offset from body to capsule center.
  final int resolvedOffsetXTicks;

  /// Vertical offset from body to capsule center in Y-down coordinates.
  final int offsetYTicks;
}

/// Inclusive capsule-center interval that satisfies one surface's foothold.
class TerrainStandableCenterRange {
  const TerrainStandableCenterRange({
    required this.minimumXTicks,
    required this.maximumXTicks,
  }) : assert(minimumXTicks <= maximumXTicks);

  final int minimumXTicks;
  final int maximumXTicks;
}

/// Request to locate and validate an upright capsule on walkable terrain.
class TerrainGroundPlacementRequest {
  factory TerrainGroundPlacementRequest({
    required int desiredBodyCenterXTicks,
    required int minimumSupportYTicks,
    required int maximumSupportYTicks,
    required TerrainPlacementCapsule capsule,
    required TerrainTraversalProfile traversalProfile,
    required TerrainSupportRequirement supportRequirement,
    TerrainEdgeId? intendedSupportEdgeId,
    bool allowSameSupportClamp = false,
    TerrainOneWayClearancePolicy oneWayClearancePolicy =
        TerrainOneWayClearancePolicy.useTraversalProfile,
    int? expectedGeometryVersion,
  }) {
    if (minimumSupportYTicks > maximumSupportYTicks) {
      throw ArgumentError('Support Y minimum must not exceed its maximum.');
    }
    if (allowSameSupportClamp && intendedSupportEdgeId == null) {
      throw ArgumentError(
        'Same-support clamping requires an exact intended support edge.',
      );
    }
    if (expectedGeometryVersion != null && expectedGeometryVersion < 0) {
      throw ArgumentError.value(
        expectedGeometryVersion,
        'expectedGeometryVersion',
        'Must be non-negative.',
      );
    }
    if (desiredBodyCenterXTicks.abs() > terrainMaxAbsPhysicsTicks ||
        minimumSupportYTicks.abs() > terrainMaxAbsPhysicsTicks ||
        maximumSupportYTicks.abs() > terrainMaxAbsPhysicsTicks ||
        (desiredBodyCenterXTicks + capsule.resolvedOffsetXTicks).abs() >
            terrainMaxAbsPhysicsTicks) {
      throw RangeError(
        'Ground placement coordinates exceed the physics range.',
      );
    }
    return TerrainGroundPlacementRequest._(
      desiredBodyCenterXTicks: desiredBodyCenterXTicks,
      minimumSupportYTicks: minimumSupportYTicks,
      maximumSupportYTicks: maximumSupportYTicks,
      capsule: capsule,
      traversalProfile: traversalProfile,
      supportRequirement: supportRequirement,
      intendedSupportEdgeId: intendedSupportEdgeId,
      allowSameSupportClamp: allowSameSupportClamp,
      oneWayClearancePolicy: oneWayClearancePolicy,
      expectedGeometryVersion: expectedGeometryVersion,
    );
  }

  const TerrainGroundPlacementRequest._({
    required this.desiredBodyCenterXTicks,
    required this.minimumSupportYTicks,
    required this.maximumSupportYTicks,
    required this.capsule,
    required this.traversalProfile,
    required this.supportRequirement,
    required this.intendedSupportEdgeId,
    required this.allowSameSupportClamp,
    required this.oneWayClearancePolicy,
    required this.expectedGeometryVersion,
  });

  final int desiredBodyCenterXTicks;
  final int minimumSupportYTicks;
  final int maximumSupportYTicks;
  final TerrainPlacementCapsule capsule;
  final TerrainTraversalProfile traversalProfile;
  final TerrainSupportRequirement supportRequirement;
  final TerrainEdgeId? intendedSupportEdgeId;
  final bool allowSameSupportClamp;
  final TerrainOneWayClearancePolicy oneWayClearancePolicy;
  final int? expectedGeometryVersion;
}

/// Request to validate one exact body/capsule position without support lookup.
class TerrainClearancePlacementRequest {
  factory TerrainClearancePlacementRequest({
    required TerrainPoint bodyCenter,
    required TerrainPlacementCapsule capsule,
    required TerrainTraversalProfile traversalProfile,
    TerrainOneWayClearancePolicy oneWayClearancePolicy =
        TerrainOneWayClearancePolicy.useTraversalProfile,
    int? expectedGeometryVersion,
  }) {
    if (expectedGeometryVersion != null && expectedGeometryVersion < 0) {
      throw ArgumentError.value(
        expectedGeometryVersion,
        'expectedGeometryVersion',
        'Must be non-negative.',
      );
    }
    return TerrainClearancePlacementRequest._(
      bodyCenter: bodyCenter,
      capsule: capsule,
      traversalProfile: traversalProfile,
      oneWayClearancePolicy: oneWayClearancePolicy,
      expectedGeometryVersion: expectedGeometryVersion,
    );
  }

  const TerrainClearancePlacementRequest._({
    required this.bodyCenter,
    required this.capsule,
    required this.traversalProfile,
    required this.oneWayClearancePolicy,
    required this.expectedGeometryVersion,
  });

  final TerrainPoint bodyCenter;
  final TerrainPlacementCapsule capsule;
  final TerrainTraversalProfile traversalProfile;
  final TerrainOneWayClearancePolicy oneWayClearancePolicy;
  final int? expectedGeometryVersion;
}

/// Stable counters retained with a placement result for diagnosis and tests.
class TerrainPlacementDiagnostics {
  const TerrainPlacementDiagnostics({
    required this.surfaceCandidates,
    required this.eligibleSurfaceCandidates,
    required this.clearanceCandidates,
    required this.clearanceCandidatesTested,
    required this.requiredSupportWidthTicks,
  });

  final int surfaceCandidates;
  final int eligibleSurfaceCandidates;
  final int clearanceCandidates;
  final int clearanceCandidatesTested;
  final int requiredSupportWidthTicks;
}

/// Immutable support/placement evidence tied to one geometry version.
class TerrainPlacementResult {
  const TerrainPlacementResult._({
    required this.validity,
    required this.geometryVersion,
    required this.bodyCenter,
    required this.capsuleCenter,
    required this.supportPoint,
    required this.supportEdgeId,
    required this.supportTangent,
    required this.supportNormal,
    required this.absoluteSlopeAngleUnits,
    required this.sameSupportClampedBodyXTicks,
    required this.blockingEdgeId,
    required this.diagnostics,
  });

  final TerrainPlacementValidity validity;
  final int geometryVersion;
  final TerrainPoint? bodyCenter;
  final TerrainPoint? capsuleCenter;

  /// Exact vertical projection on the selected finite surface at capsule X.
  final TerrainPoint? supportPoint;

  final TerrainEdgeId? supportEdgeId;
  final TerrainDirection? supportTangent;
  final TerrainDirection? supportNormal;
  final int? absoluteSlopeAngleUnits;

  /// Final body X when an explicitly requested same-edge clamp was applied.
  final int? sameSupportClampedBodyXTicks;

  final TerrainEdgeId? blockingEdgeId;
  final TerrainPlacementDiagnostics diagnostics;

  bool get isValid => validity == TerrainPlacementValidity.valid;
}

/// Deterministic shared support lookup and complete-capsule placement query.
///
/// The resolver is actor-neutral: callers supply a capsule, traversal policy,
/// and support-width requirement. It owns reusable surface/edge query scratch
/// buffers, but returns immutable evidence suitable for graph construction,
/// runtime navigation, spawn validation, and teleport validation.
class TerrainPlacementQuery {
  TerrainPlacementQuery({
    required this.geometry,
    required this.terrainIndex,
    required this.surfaceIndex,
  }) : _surfaceBuffer = surfaceIndex.createQueryBuffer(),
       _terrainBuffer = terrainIndex.createQueryBuffer() {
    if (geometry.version != surfaceIndex.geometryVersion) {
      throw ArgumentError('Geometry and surface index versions must match.');
    }
    if (geometry.edges.length != terrainIndex.edges.length) {
      throw ArgumentError('Geometry and terrain index edge counts must match.');
    }
    for (var index = 0; index < geometry.edges.length; index += 1) {
      if (geometry.edges[index].id != terrainIndex.edges[index].id) {
        throw ArgumentError(
          'Geometry and terrain index must use canonical edge order.',
        );
      }
    }
    for (final surface in surfaceIndex.surfaces) {
      final edge = geometry.edgeById[surface.id];
      if (edge == null ||
          edge.start != surface.start ||
          edge.end != surface.end) {
        throw ArgumentError(
          'Every navigation surface must match its compiled terrain edge.',
        );
      }
    }
  }

  final TerrainGeometry geometry;
  final TerrainEdgeIndex terrainIndex;
  final TerrainSurfaceSpatialIndex surfaceIndex;
  final TerrainSurfaceQueryBuffer _surfaceBuffer;
  final TerrainQueryBuffer _terrainBuffer;
  final CapsuleSegmentKernel _kernel = CapsuleSegmentKernel();
  final CapsuleSegmentContact _contact = CapsuleSegmentContact();

  /// Returns the exact standable capsule-center interval for [surface].
  ///
  /// This is the same profile eligibility and rational support-width rule used
  /// by [resolveGrounded]. A `null` result means the surface is ineligible or
  /// too narrow; it never silently clamps to a neighboring surface.
  TerrainStandableCenterRange? standableCenterRange({
    required TerrainNavigationSurface surface,
    required TerrainPlacementCapsule capsule,
    required TerrainTraversalProfile traversalProfile,
    required TerrainSupportRequirement supportRequirement,
  }) {
    if (surfaceIndex.surfaceSet.surfaceById(surface.id) != surface) {
      throw ArgumentError(
        'Standable-range surfaces must belong to this placement query.',
      );
    }
    if (!surface.isEligibleFor(traversalProfile)) return null;
    final requiredWidth = supportRequirement.requiredWidthTicks(
      capsule.radiusTicks,
    );
    final range = _standableCenterRange(
      surface,
      capsule.radiusTicks,
      requiredWidth,
    );
    return range == null
        ? null
        : TerrainStandableCenterRange(
            minimumXTicks: range.$1,
            maximumXTicks: range.$2,
          );
  }

  /// Resolves the highest eligible support and validates the complete capsule.
  TerrainPlacementResult resolveGrounded(
    TerrainGroundPlacementRequest request,
  ) {
    final versionFailure = _versionFailure(request.expectedGeometryVersion);
    if (versionFailure != null) return versionFailure;

    final requiredWidth = request.supportRequirement.requiredWidthTicks(
      request.capsule.radiusTicks,
    );
    final desiredCapsuleX =
        request.desiredBodyCenterXTicks + request.capsule.resolvedOffsetXTicks;
    var surfaceCandidates = 0;
    var eligibleCandidates = 0;
    TerrainNavigationSurface? support;

    final intendedId = request.intendedSupportEdgeId;
    if (intendedId != null) {
      support = surfaceIndex.surfaceSet.surfaceById(intendedId);
      if (support == null) {
        return _failure(
          TerrainPlacementValidity.intendedSupportMissing,
          requiredSupportWidthTicks: requiredWidth,
        );
      }
      surfaceCandidates = 1;
      if (!support.isEligibleFor(request.traversalProfile)) {
        return _failure(
          TerrainPlacementValidity.profileIneligible,
          support: support,
          requiredSupportWidthTicks: requiredWidth,
          surfaceCandidates: surfaceCandidates,
        );
      }
      eligibleCandidates = 1;
    } else {
      surfaceIndex.queryBounds(
        minX: desiredCapsuleX,
        minY: request.minimumSupportYTicks,
        maxX: desiredCapsuleX,
        maxY: request.maximumSupportYTicks,
        buffer: _surfaceBuffer,
      );
      for (
        var candidateIndex = 0;
        candidateIndex < _surfaceBuffer.candidateCount;
        candidateIndex += 1
      ) {
        final candidate = _surfaceBuffer.surfaceAt(
          candidateIndex,
          surfaceIndex.surfaces,
        );
        if (desiredCapsuleX < candidate.xMinTicks ||
            desiredCapsuleX > candidate.xMaxTicks) {
          continue;
        }
        final y = candidate.yAtXTicks(desiredCapsuleX);
        if (y < request.minimumSupportYTicks ||
            y > request.maximumSupportYTicks) {
          continue;
        }
        surfaceCandidates += 1;
        if (!candidate.isEligibleFor(request.traversalProfile)) continue;
        eligibleCandidates += 1;
        if (support == null ||
            _compareSupport(candidate, support, desiredCapsuleX, y) < 0) {
          support = candidate;
        }
      }
      if (support == null) {
        return _failure(
          surfaceCandidates == 0
              ? TerrainPlacementValidity.noSupport
              : TerrainPlacementValidity.profileIneligible,
          requiredSupportWidthTicks: requiredWidth,
          surfaceCandidates: surfaceCandidates,
          eligibleSurfaceCandidates: eligibleCandidates,
        );
      }
    }

    final standable = _standableCenterRange(
      support,
      request.capsule.radiusTicks,
      requiredWidth,
    );
    if (standable == null) {
      return _failure(
        TerrainPlacementValidity.insufficientSupportWidth,
        support: support,
        requiredSupportWidthTicks: requiredWidth,
        surfaceCandidates: surfaceCandidates,
        eligibleSurfaceCandidates: eligibleCandidates,
      );
    }

    if ((desiredCapsuleX < support.xMinTicks ||
            desiredCapsuleX > support.xMaxTicks) &&
        !request.allowSameSupportClamp) {
      return _failure(
        TerrainPlacementValidity.outsideSupport,
        support: support,
        requiredSupportWidthTicks: requiredWidth,
        surfaceCandidates: surfaceCandidates,
        eligibleSurfaceCandidates: eligibleCandidates,
      );
    }

    var capsuleX = desiredCapsuleX;
    int? clampedBodyX;
    if (capsuleX < standable.$1 || capsuleX > standable.$2) {
      if (!request.allowSameSupportClamp) {
        return _failure(
          TerrainPlacementValidity.outsideStandableRange,
          support: support,
          requiredSupportWidthTicks: requiredWidth,
          surfaceCandidates: surfaceCandidates,
          eligibleSurfaceCandidates: eligibleCandidates,
        );
      }
      capsuleX = capsuleX.clamp(standable.$1, standable.$2);
      clampedBodyX = capsuleX - request.capsule.resolvedOffsetXTicks;
    }

    final supportY = support.yAtXTicks(capsuleX);
    if (supportY < request.minimumSupportYTicks ||
        supportY > request.maximumSupportYTicks) {
      return _failure(
        TerrainPlacementValidity.outsideVerticalRange,
        support: support,
        requiredSupportWidthTicks: requiredWidth,
        surfaceCandidates: surfaceCandidates,
        eligibleSurfaceCandidates: eligibleCandidates,
        sameSupportClampedBodyXTicks: clampedBodyX,
      );
    }

    final initialCapsuleY = _supportedCapsuleCenterY(
      support: support,
      supportYTicks: supportY,
      radiusTicks: request.capsule.radiusTicks,
      verticalHalfSegmentTicks: request.capsule.verticalHalfSegmentTicks,
    );
    final capsuleY = _liftAboveCompatibleSupportChain(
      initialCenterYTicks: initialCapsuleY,
      centerXTicks: capsuleX,
      capsule: request.capsule,
      support: support,
      traversalProfile: request.traversalProfile,
    );
    final capsuleCenter = TerrainPoint(capsuleX, capsuleY);
    final bodyCenter = TerrainPoint(
      capsuleX - request.capsule.resolvedOffsetXTicks,
      capsuleY - request.capsule.offsetYTicks,
    );
    final clearance = _firstClearanceBlocker(
      capsuleCenter: capsuleCenter,
      capsule: request.capsule,
      traversalProfile: request.traversalProfile,
      oneWayPolicy: request.oneWayClearancePolicy,
      support: support,
    );
    final diagnostics = TerrainPlacementDiagnostics(
      surfaceCandidates: surfaceCandidates,
      eligibleSurfaceCandidates: eligibleCandidates,
      clearanceCandidates: clearance.$2,
      clearanceCandidatesTested: clearance.$3,
      requiredSupportWidthTicks: requiredWidth,
    );
    return TerrainPlacementResult._(
      validity: clearance.$1 == null
          ? TerrainPlacementValidity.valid
          : TerrainPlacementValidity.blockedClearance,
      geometryVersion: geometry.version,
      bodyCenter: bodyCenter,
      capsuleCenter: capsuleCenter,
      supportPoint: TerrainPoint(capsuleX, supportY),
      supportEdgeId: support.id,
      supportTangent: support.tangent,
      supportNormal: support.outwardNormal,
      absoluteSlopeAngleUnits: terrainAbsoluteSlopeAngleUnits(
        dxTicks: support.dxTicks,
        dyTicks: support.dyTicks,
        tangentXTicks: support.tangent.xTicks,
        tangentYTicks: support.tangent.yTicks,
      ),
      sameSupportClampedBodyXTicks: clampedBodyX,
      blockingEdgeId: clearance.$1,
      diagnostics: diagnostics,
    );
  }

  /// Validates a fixed position without grounding or relocation.
  TerrainPlacementResult validateClearance(
    TerrainClearancePlacementRequest request,
  ) {
    final versionFailure = _versionFailure(request.expectedGeometryVersion);
    if (versionFailure != null) return versionFailure;
    final capsuleCenter = request.bodyCenter.translated(
      request.capsule.resolvedOffsetXTicks,
      request.capsule.offsetYTicks,
    );
    final clearance = _firstClearanceBlocker(
      capsuleCenter: capsuleCenter,
      capsule: request.capsule,
      traversalProfile: request.traversalProfile,
      oneWayPolicy: request.oneWayClearancePolicy,
      support: null,
    );
    return TerrainPlacementResult._(
      validity: clearance.$1 == null
          ? TerrainPlacementValidity.valid
          : TerrainPlacementValidity.blockedClearance,
      geometryVersion: geometry.version,
      bodyCenter: request.bodyCenter,
      capsuleCenter: capsuleCenter,
      supportPoint: null,
      supportEdgeId: null,
      supportTangent: null,
      supportNormal: null,
      absoluteSlopeAngleUnits: null,
      sameSupportClampedBodyXTicks: null,
      blockingEdgeId: clearance.$1,
      diagnostics: TerrainPlacementDiagnostics(
        surfaceCandidates: 0,
        eligibleSurfaceCandidates: 0,
        clearanceCandidates: clearance.$2,
        clearanceCandidatesTested: clearance.$3,
        requiredSupportWidthTicks: 0,
      ),
    );
  }

  /// Whether retained valid evidence still belongs to this geometry version.
  bool canCommit(TerrainPlacementResult result) =>
      result.isValid && result.geometryVersion == geometry.version;

  TerrainPlacementResult? _versionFailure(int? expectedVersion) {
    if (expectedVersion == null || expectedVersion == geometry.version) {
      return null;
    }
    return _failure(TerrainPlacementValidity.geometryVersionMismatch);
  }

  int _compareSupport(
    TerrainNavigationSurface candidate,
    TerrainNavigationSurface current,
    int queryXTicks,
    int candidateY,
  ) {
    final currentY = current.yAtXTicks(queryXTicks);
    final yOrder = candidateY.compareTo(currentY);
    return yOrder != 0 ? yOrder : candidate.id.compareTo(current.id);
  }

  (int, int)? _standableCenterRange(
    TerrainNavigationSurface support,
    int radiusTicks,
    int requiredWidthTicks,
  ) {
    if (support.dxTicks < requiredWidthTicks) return null;
    return (
      _maxInt(
        support.xMinTicks,
        support.xMinTicks + requiredWidthTicks - radiusTicks,
      ),
      _minInt(
        support.xMaxTicks,
        support.xMaxTicks - requiredWidthTicks + radiusTicks,
      ),
    );
  }

  int _supportedCapsuleCenterY({
    required TerrainNavigationSurface support,
    required int supportYTicks,
    required int radiusTicks,
    required int verticalHalfSegmentTicks,
  }) {
    final radiusVerticalOffset = _divideCeil(
      radiusTicks * terrainDirectionScale,
      -support.outwardNormal.yTicks,
    );
    return supportYTicks - verticalHalfSegmentTicks - radiusVerticalOffset;
  }

  int _liftAboveCompatibleSupportChain({
    required int initialCenterYTicks,
    required int centerXTicks,
    required TerrainPlacementCapsule capsule,
    required TerrainNavigationSurface support,
    required TerrainTraversalProfile traversalProfile,
  }) {
    if (!_penetratesSupportChain(
      centerXTicks: centerXTicks,
      centerYTicks: initialCenterYTicks,
      capsule: capsule,
      support: support,
      traversalProfile: traversalProfile,
    )) {
      return initialCenterYTicks;
    }

    var clearY = initialCenterYTicks;
    var liftTicks = capsule.radiusTicks;
    for (var attempt = 0; attempt < 16; attempt += 1) {
      clearY -= liftTicks;
      if (!_penetratesSupportChain(
        centerXTicks: centerXTicks,
        centerYTicks: clearY,
        capsule: capsule,
        support: support,
        traversalProfile: traversalProfile,
      )) {
        var penetratingY = initialCenterYTicks;
        while (penetratingY - clearY > 1) {
          final middleY = (penetratingY + clearY) >> 1;
          if (_penetratesSupportChain(
            centerXTicks: centerXTicks,
            centerYTicks: middleY,
            capsule: capsule,
            support: support,
            traversalProfile: traversalProfile,
          )) {
            penetratingY = middleY;
          } else {
            clearY = middleY;
          }
        }
        return clearY;
      }
      liftTicks <<= 1;
    }
    throw StateError('Compatible support chain did not clear the capsule.');
  }

  bool _penetratesSupportChain({
    required int centerXTicks,
    required int centerYTicks,
    required TerrainPlacementCapsule capsule,
    required TerrainNavigationSurface support,
    required TerrainTraversalProfile traversalProfile,
  }) {
    final halfHeight = capsule.radiusTicks + capsule.verticalHalfSegmentTicks;
    surfaceIndex.queryBounds(
      minX: centerXTicks - capsule.radiusTicks,
      minY: centerYTicks - halfHeight,
      maxX: centerXTicks + capsule.radiusTicks,
      maxY: centerYTicks + halfHeight,
      buffer: _surfaceBuffer,
    );
    for (
      var candidateIndex = 0;
      candidateIndex < _surfaceBuffer.candidateCount;
      candidateIndex += 1
    ) {
      final candidate = _surfaceBuffer.surfaceAt(
        candidateIndex,
        surfaceIndex.surfaces,
      );
      if (candidate.chainId != support.chainId ||
          !candidate.isEligibleFor(traversalProfile)) {
        continue;
      }
      final edge = geometry.edgeById[candidate.id]!;
      _kernel.evaluateAtCenter(
        centerXTicks: centerXTicks,
        centerYTicks: centerYTicks,
        radiusTicks: capsule.radiusTicks,
        verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks,
        edge: edge,
        out: _contact,
      );
      if (_contact.separationLessThanTicks(-terrainContactEpsilonTicks)) {
        return true;
      }
    }
    return false;
  }

  (TerrainEdgeId?, int, int) _firstClearanceBlocker({
    required TerrainPoint capsuleCenter,
    required TerrainPlacementCapsule capsule,
    required TerrainTraversalProfile traversalProfile,
    required TerrainOneWayClearancePolicy oneWayPolicy,
    required TerrainNavigationSurface? support,
  }) {
    final halfHeight = capsule.radiusTicks + capsule.verticalHalfSegmentTicks;
    terrainIndex.queryBounds(
      minX: capsuleCenter.xTicks - capsule.radiusTicks,
      minY: capsuleCenter.yTicks - halfHeight,
      maxX: capsuleCenter.xTicks + capsule.radiusTicks,
      maxY: capsuleCenter.yTicks + halfHeight,
      buffer: _terrainBuffer,
    );
    final policy = TerrainContactPolicy(
      geometry: geometry,
      profile: traversalProfile,
    );
    var tested = 0;
    for (
      var candidateIndex = 0;
      candidateIndex < _terrainBuffer.candidateCount;
      candidateIndex += 1
    ) {
      final edge = _terrainBuffer.edgeAt(candidateIndex, terrainIndex.edges);
      _kernel.evaluateAtCenter(
        centerXTicks: capsuleCenter.xTicks,
        centerYTicks: capsuleCenter.yTicks,
        radiusTicks: capsule.radiusTicks,
        verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks,
        edge: edge,
        out: _contact,
      );
      tested += 1;
      if (!_contact.separationLessThanTicks(-terrainContactEpsilonTicks)) {
        continue;
      }
      if (support != null && edge.id == support.id) continue;
      if (edge.collisionMode == TerrainCollisionMode.oneWay) {
        if (oneWayPolicy == TerrainOneWayClearancePolicy.ignore ||
            !traversalProfile.oneWaySupportEnabled) {
          continue;
        }
        final centerSide = policy.capsuleCenterPlaneDistanceNumeratorAtCenter(
          centerXTicks: capsuleCenter.xTicks,
          centerYTicks: capsuleCenter.yTicks,
          edge: edge,
        );
        if (centerSide <= 0) continue;
      }
      return (edge.id, _terrainBuffer.candidateCount, tested);
    }
    return (null, _terrainBuffer.candidateCount, tested);
  }

  TerrainPlacementResult _failure(
    TerrainPlacementValidity validity, {
    TerrainNavigationSurface? support,
    int requiredSupportWidthTicks = 0,
    int surfaceCandidates = 0,
    int eligibleSurfaceCandidates = 0,
    int? sameSupportClampedBodyXTicks,
  }) => TerrainPlacementResult._(
    validity: validity,
    geometryVersion: geometry.version,
    bodyCenter: null,
    capsuleCenter: null,
    supportPoint: null,
    supportEdgeId: support?.id,
    supportTangent: support?.tangent,
    supportNormal: support?.outwardNormal,
    absoluteSlopeAngleUnits: support == null
        ? null
        : terrainAbsoluteSlopeAngleUnits(
            dxTicks: support.dxTicks,
            dyTicks: support.dyTicks,
            tangentXTicks: support.tangent.xTicks,
            tangentYTicks: support.tangent.yTicks,
          ),
    sameSupportClampedBodyXTicks: sameSupportClampedBodyXTicks,
    blockingEdgeId: null,
    diagnostics: TerrainPlacementDiagnostics(
      surfaceCandidates: surfaceCandidates,
      eligibleSurfaceCandidates: eligibleSurfaceCandidates,
      clearanceCandidates: 0,
      clearanceCandidatesTested: 0,
      requiredSupportWidthTicks: requiredSupportWidthTicks,
    ),
  );
}

int _divideCeil(int numerator, int positiveDenominator) =>
    (numerator + positiveDenominator - 1) ~/ positiveDenominator;

int _minInt(int left, int right) => left < right ? left : right;

int _maxInt(int left, int right) => left > right ? left : right;
