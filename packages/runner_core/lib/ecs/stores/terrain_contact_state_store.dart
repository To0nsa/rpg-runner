import '../../collision/terrain/terrain_controller_diagnostic.dart';
import '../../collision/terrain/terrain_contact_policy.dart';
import '../../collision/terrain/terrain_edge.dart';
import '../../collision/terrain/terrain_edge_id.dart';
import '../../collision/terrain/capsule_segment_kernel.dart';
import '../../collision/terrain/terrain_numeric.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

/// Final quantized support and blocker state written by terrain motion.
///
/// Support identity is valid only while [supportGeometryVersion] matches the
/// currently published geometry. The controller writes this store atomically
/// after movement, probe, step, and snap resolution.
class TerrainContactStateStore extends SparseSet {
  final List<bool> grounded = <bool>[];
  final List<TerrainEdgeId?> supportEdgeId = <TerrainEdgeId?>[];
  final List<int> supportPointXTicks = <int>[];
  final List<int> supportPointYTicks = <int>[];
  final List<int> supportNormalXTicks = <int>[];
  final List<int> supportNormalYTicks = <int>[];
  final List<int> supportTangentXTicks = <int>[];
  final List<int> supportTangentYTicks = <int>[];
  final List<int> supportSlopeAngleUnits = <int>[];
  final List<int> supportGeometryVersion = <int>[];
  final List<int> lastValidSupportTick = <int>[];

  final List<bool> hitCeiling = <bool>[];
  final List<bool> hitLeft = <bool>[];
  final List<bool> hitRight = <bool>[];
  final List<int> wallNormalXTicks = <int>[];
  final List<int> wallNormalYTicks = <int>[];
  final List<int> ceilingNormalXTicks = <int>[];
  final List<int> ceilingNormalYTicks = <int>[];

  final List<bool> beganTickGrounded = <bool>[];
  final List<bool> snapEligibleAtTickStart = <bool>[];
  final List<bool> usedStep = <bool>[];
  final List<bool> usedSnap = <bool>[];
  final List<bool> usedRecovery = <bool>[];

  final List<bool> hasLastValidBodyPosition = <bool>[];
  final List<int> lastValidBodyXTicks = <int>[];
  final List<int> lastValidBodyYTicks = <int>[];
  final List<bool> hasLastCapsuleState = <bool>[];
  final List<int> lastCapsuleCenterXTicks = <int>[];
  final List<int> lastCapsuleCenterYTicks = <int>[];
  final List<int> lastCapsuleFacingSign = <int>[];

  final List<bool> mobilityStartedGrounded = <bool>[];
  final List<int> mobilitySurfaceDirectionSign = <int>[];

  final List<int> blockingContactCount = <int>[];
  final List<List<TerrainEdgeId?>> blockingContactEdgeIds =
      <List<TerrainEdgeId?>>[];
  final List<List<TerrainContactKind>> blockingContactKinds =
      <List<TerrainContactKind>>[];
  final List<List<TerrainSegmentFeature>> blockingContactFeatures =
      <List<TerrainSegmentFeature>>[];
  final List<List<int>> blockingContactNormalXTicks = <List<int>>[];
  final List<List<int>> blockingContactNormalYTicks = <List<int>>[];
  final List<int> contactIterations = <int>[];
  final List<int> recoveryIterations = <int>[];
  final List<int> candidateCount = <int>[];
  final List<int> queryCellsVisited = <int>[];
  final List<TerrainControllerDiagnostic> diagnostic =
      <TerrainControllerDiagnostic>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  /// Captures support eligibility and clears transient results for a new tick.
  void beginTick(EntityId entity, {required int currentGeometryVersion}) {
    final index = indexOf(entity);
    final supportIsCurrent =
        grounded[index] &&
        supportEdgeId[index] != null &&
        supportGeometryVersion[index] == currentGeometryVersion;
    beganTickGrounded[index] = supportIsCurrent;
    snapEligibleAtTickStart[index] = supportIsCurrent;
    hitCeiling[index] = false;
    hitLeft[index] = false;
    hitRight[index] = false;
    wallNormalXTicks[index] = 0;
    wallNormalYTicks[index] = 0;
    ceilingNormalXTicks[index] = 0;
    ceilingNormalYTicks[index] = 0;
    usedStep[index] = false;
    usedSnap[index] = false;
    usedRecovery[index] = false;
    blockingContactCount[index] = 0;
    for (
      var contactIndex = 0;
      contactIndex < terrainMaxBlockingContacts;
      contactIndex += 1
    ) {
      blockingContactEdgeIds[index][contactIndex] = null;
      blockingContactKinds[index][contactIndex] = TerrainContactKind.ignored;
      blockingContactFeatures[index][contactIndex] = TerrainSegmentFeature.face;
      blockingContactNormalXTicks[index][contactIndex] = 0;
      blockingContactNormalYTicks[index][contactIndex] = 0;
    }
    contactIterations[index] = 0;
    recoveryIterations[index] = 0;
    candidateCount[index] = 0;
    queryCellsVisited[index] = 0;
    diagnostic[index] = TerrainControllerDiagnostic.none;
    if (!supportIsCurrent && grounded[index]) {
      clearSupportAt(index);
      diagnostic[index] = TerrainControllerDiagnostic.staleSupportCleared;
    }
  }

  /// Stores one final eligible support from canonical terrain.
  void setSupport(
    EntityId entity, {
    required TerrainEdge edge,
    required int pointXTicks,
    required int pointYTicks,
    required int geometryVersion,
    required int currentTick,
    int slopeAngleUnits = 0,
  }) {
    final index = indexOf(entity);
    grounded[index] = true;
    supportEdgeId[index] = edge.id;
    supportPointXTicks[index] = pointXTicks;
    supportPointYTicks[index] = pointYTicks;
    supportNormalXTicks[index] = edge.outwardNormal.xTicks;
    supportNormalYTicks[index] = edge.outwardNormal.yTicks;
    supportTangentXTicks[index] = edge.tangent.xTicks;
    supportTangentYTicks[index] = edge.tangent.yTicks;
    supportSlopeAngleUnits[index] = slopeAngleUnits;
    supportGeometryVersion[index] = geometryVersion;
    lastValidSupportTick[index] = currentTick;
  }

  /// Invalidates support and snap eligibility without changing blocker results.
  void clearSupport(EntityId entity) {
    clearSupportAt(indexOf(entity));
  }

  /// Records the last body position known to be clear of invalid overlap.
  void setLastValidBodyPosition(
    EntityId entity, {
    required int xTicks,
    required int yTicks,
  }) {
    final index = indexOf(entity);
    hasLastValidBodyPosition[index] = true;
    lastValidBodyXTicks[index] = xTicks;
    lastValidBodyYTicks[index] = yTicks;
  }

  /// Retains the final capsule center/facing so offset changes sweep next tick.
  void setLastCapsuleState(
    EntityId entity, {
    required int centerXTicks,
    required int centerYTicks,
    required int facingSign,
  }) {
    if (facingSign != -1 && facingSign != 1) {
      throw ArgumentError.value(facingSign, 'facingSign', 'Must be -1 or 1.');
    }
    final index = indexOf(entity);
    hasLastCapsuleState[index] = true;
    lastCapsuleCenterXTicks[index] = centerXTicks;
    lastCapsuleCenterYTicks[index] = centerYTicks;
    lastCapsuleFacingSign[index] = facingSign;
  }

  /// Clears support and retained capsule history after an explicit teleport.
  void clearForTeleport(EntityId entity) {
    final index = indexOf(entity);
    clearSupportAt(index);
    beganTickGrounded[index] = false;
    hasLastValidBodyPosition[index] = false;
    hasLastCapsuleState[index] = false;
  }

  void clearSupportAt(int index) {
    grounded[index] = false;
    supportEdgeId[index] = null;
    supportPointXTicks[index] = 0;
    supportPointYTicks[index] = 0;
    supportNormalXTicks[index] = 0;
    supportNormalYTicks[index] = 0;
    supportTangentXTicks[index] = 0;
    supportTangentYTicks[index] = 0;
    supportSlopeAngleUnits[index] = 0;
    supportGeometryVersion[index] = -1;
    snapEligibleAtTickStart[index] = false;
  }

  @override
  void onDenseAdded(int denseIndex) {
    grounded.add(false);
    supportEdgeId.add(null);
    supportPointXTicks.add(0);
    supportPointYTicks.add(0);
    supportNormalXTicks.add(0);
    supportNormalYTicks.add(0);
    supportTangentXTicks.add(0);
    supportTangentYTicks.add(0);
    supportSlopeAngleUnits.add(0);
    supportGeometryVersion.add(-1);
    lastValidSupportTick.add(-1);

    hitCeiling.add(false);
    hitLeft.add(false);
    hitRight.add(false);
    wallNormalXTicks.add(0);
    wallNormalYTicks.add(0);
    ceilingNormalXTicks.add(0);
    ceilingNormalYTicks.add(0);

    beganTickGrounded.add(false);
    snapEligibleAtTickStart.add(false);
    usedStep.add(false);
    usedSnap.add(false);
    usedRecovery.add(false);

    hasLastValidBodyPosition.add(false);
    lastValidBodyXTicks.add(0);
    lastValidBodyYTicks.add(0);
    hasLastCapsuleState.add(false);
    lastCapsuleCenterXTicks.add(0);
    lastCapsuleCenterYTicks.add(0);
    lastCapsuleFacingSign.add(1);

    mobilityStartedGrounded.add(false);
    mobilitySurfaceDirectionSign.add(1);

    blockingContactCount.add(0);
    blockingContactEdgeIds.add(
      List<TerrainEdgeId?>.filled(terrainMaxBlockingContacts, null),
    );
    blockingContactKinds.add(
      List<TerrainContactKind>.filled(
        terrainMaxBlockingContacts,
        TerrainContactKind.ignored,
      ),
    );
    blockingContactFeatures.add(
      List<TerrainSegmentFeature>.filled(
        terrainMaxBlockingContacts,
        TerrainSegmentFeature.face,
      ),
    );
    blockingContactNormalXTicks.add(
      List<int>.filled(terrainMaxBlockingContacts, 0),
    );
    blockingContactNormalYTicks.add(
      List<int>.filled(terrainMaxBlockingContacts, 0),
    );
    contactIterations.add(0);
    recoveryIterations.add(0);
    candidateCount.add(0);
    queryCellsVisited.add(0);
    diagnostic.add(TerrainControllerDiagnostic.none);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    grounded[removeIndex] = grounded[lastIndex];
    supportEdgeId[removeIndex] = supportEdgeId[lastIndex];
    supportPointXTicks[removeIndex] = supportPointXTicks[lastIndex];
    supportPointYTicks[removeIndex] = supportPointYTicks[lastIndex];
    supportNormalXTicks[removeIndex] = supportNormalXTicks[lastIndex];
    supportNormalYTicks[removeIndex] = supportNormalYTicks[lastIndex];
    supportTangentXTicks[removeIndex] = supportTangentXTicks[lastIndex];
    supportTangentYTicks[removeIndex] = supportTangentYTicks[lastIndex];
    supportSlopeAngleUnits[removeIndex] = supportSlopeAngleUnits[lastIndex];
    supportGeometryVersion[removeIndex] = supportGeometryVersion[lastIndex];
    lastValidSupportTick[removeIndex] = lastValidSupportTick[lastIndex];

    hitCeiling[removeIndex] = hitCeiling[lastIndex];
    hitLeft[removeIndex] = hitLeft[lastIndex];
    hitRight[removeIndex] = hitRight[lastIndex];
    wallNormalXTicks[removeIndex] = wallNormalXTicks[lastIndex];
    wallNormalYTicks[removeIndex] = wallNormalYTicks[lastIndex];
    ceilingNormalXTicks[removeIndex] = ceilingNormalXTicks[lastIndex];
    ceilingNormalYTicks[removeIndex] = ceilingNormalYTicks[lastIndex];

    beganTickGrounded[removeIndex] = beganTickGrounded[lastIndex];
    snapEligibleAtTickStart[removeIndex] = snapEligibleAtTickStart[lastIndex];
    usedStep[removeIndex] = usedStep[lastIndex];
    usedSnap[removeIndex] = usedSnap[lastIndex];
    usedRecovery[removeIndex] = usedRecovery[lastIndex];

    hasLastValidBodyPosition[removeIndex] = hasLastValidBodyPosition[lastIndex];
    lastValidBodyXTicks[removeIndex] = lastValidBodyXTicks[lastIndex];
    lastValidBodyYTicks[removeIndex] = lastValidBodyYTicks[lastIndex];
    hasLastCapsuleState[removeIndex] = hasLastCapsuleState[lastIndex];
    lastCapsuleCenterXTicks[removeIndex] = lastCapsuleCenterXTicks[lastIndex];
    lastCapsuleCenterYTicks[removeIndex] = lastCapsuleCenterYTicks[lastIndex];
    lastCapsuleFacingSign[removeIndex] = lastCapsuleFacingSign[lastIndex];

    mobilityStartedGrounded[removeIndex] = mobilityStartedGrounded[lastIndex];
    mobilitySurfaceDirectionSign[removeIndex] =
        mobilitySurfaceDirectionSign[lastIndex];

    blockingContactCount[removeIndex] = blockingContactCount[lastIndex];
    blockingContactEdgeIds[removeIndex] = blockingContactEdgeIds[lastIndex];
    blockingContactKinds[removeIndex] = blockingContactKinds[lastIndex];
    blockingContactFeatures[removeIndex] = blockingContactFeatures[lastIndex];
    blockingContactNormalXTicks[removeIndex] =
        blockingContactNormalXTicks[lastIndex];
    blockingContactNormalYTicks[removeIndex] =
        blockingContactNormalYTicks[lastIndex];
    contactIterations[removeIndex] = contactIterations[lastIndex];
    recoveryIterations[removeIndex] = recoveryIterations[lastIndex];
    candidateCount[removeIndex] = candidateCount[lastIndex];
    queryCellsVisited[removeIndex] = queryCellsVisited[lastIndex];
    diagnostic[removeIndex] = diagnostic[lastIndex];

    grounded.removeLast();
    supportEdgeId.removeLast();
    supportPointXTicks.removeLast();
    supportPointYTicks.removeLast();
    supportNormalXTicks.removeLast();
    supportNormalYTicks.removeLast();
    supportTangentXTicks.removeLast();
    supportTangentYTicks.removeLast();
    supportSlopeAngleUnits.removeLast();
    supportGeometryVersion.removeLast();
    lastValidSupportTick.removeLast();

    hitCeiling.removeLast();
    hitLeft.removeLast();
    hitRight.removeLast();
    wallNormalXTicks.removeLast();
    wallNormalYTicks.removeLast();
    ceilingNormalXTicks.removeLast();
    ceilingNormalYTicks.removeLast();

    beganTickGrounded.removeLast();
    snapEligibleAtTickStart.removeLast();
    usedStep.removeLast();
    usedSnap.removeLast();
    usedRecovery.removeLast();

    hasLastValidBodyPosition.removeLast();
    lastValidBodyXTicks.removeLast();
    lastValidBodyYTicks.removeLast();
    hasLastCapsuleState.removeLast();
    lastCapsuleCenterXTicks.removeLast();
    lastCapsuleCenterYTicks.removeLast();
    lastCapsuleFacingSign.removeLast();

    mobilityStartedGrounded.removeLast();
    mobilitySurfaceDirectionSign.removeLast();

    blockingContactCount.removeLast();
    blockingContactEdgeIds.removeLast();
    blockingContactKinds.removeLast();
    blockingContactFeatures.removeLast();
    blockingContactNormalXTicks.removeLast();
    blockingContactNormalYTicks.removeLast();
    contactIterations.removeLast();
    recoveryIterations.removeLast();
    candidateCount.removeLast();
    queryCellsVisited.removeLast();
    diagnostic.removeLast();
  }
}
