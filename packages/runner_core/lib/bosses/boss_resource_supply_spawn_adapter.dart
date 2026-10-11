import '../collision/terrain/terrain_capsule_controller.dart';
import '../collision/terrain/terrain_motion_request.dart';
import '../collision/terrain/terrain_numeric.dart';
import '../collision/terrain/terrain_traversal_profile.dart';
import '../ecs/collider_aabb_utils.dart';
import '../ecs/entity_id.dart';
import '../ecs/stores/restoration_item_store.dart';
import '../ecs/systems/world_motion_authority.dart';
import '../ecs/world.dart';
import '../navigation/terrain_runtime_bundle.dart';
import '../navigation/terrain_spawn_placement.dart';
import '../spawn_service.dart';
import '../tuning/restoration_item_tuning.dart';
import 'boss_resource_supply_system.dart';

/// Places supply on the player's current support after a capsule walk preview.
/// Airborne, stale, or blocked support defers the earned gem until a later tick.
final class BossResourceSupplySpawnAdapter {
  BossResourceSupplySpawnAdapter({
    required this.motion,
    required this.runtimeBundle,
    required this.spawns,
    required this.playerProfile,
    required RestorationItemTuning tuning,
  }) : _itemProfile = TerrainItemSpawnPlacementProfile.fromWorld(
         itemKind: TerrainSpawnItemKind.restoration,
         width: tuning.itemSize,
         height: tuning.itemSize,
         supportClearance: tuning.surfaceClearanceY,
         noSpawnMargin: tuning.noSpawnMargin,
         traversalProfile: playerProfile,
       );

  final WorldMotionAuthority motion;
  final TerrainRuntimeBundle Function() runtimeBundle;
  final SpawnService spawns;
  final TerrainTraversalProfile playerProfile;
  final TerrainItemSpawnPlacementProfile _itemProfile;
  TerrainRuntimeBundle? _previewBundle;
  TerrainCapsuleController? _preview;
  final _result = TerrainCapsuleMotionResult();

  /// Returns a normal restoration entity only after support, item clearance,
  /// arena confinement, and the player's complete walking capsule are checked.
  /// Candidates prefer the arena center; no gameplay RNG stream is consumed.
  EntityId? spawn(
    EcsWorld world, {
    required EntityId player,
    required BossResourceSupplyEncounter encounter,
    required RestorationStat stat,
  }) {
    final contact = world.terrainContact;
    final ci = contact.tryIndexOf(player);
    final ti = world.transform.tryIndexOf(player);
    final capsule = world.worldContactCapsule;
    final pi = capsule.tryIndexOf(player);
    final bundle = runtimeBundle();
    if (ci == null ||
        ti == null ||
        pi == null ||
        !contact.grounded[ci] ||
        contact.supportGeometryVersion[ci] != bundle.version ||
        contact.supportEdgeId[ci] == null) {
      return null;
    }
    if (!identical(bundle, _previewBundle)) {
      _previewBundle = bundle;
      _preview = TerrainCapsuleController(
        geometry: bundle.geometry,
        index: bundle.edgeIndex,
        profile: playerProfile,
      );
    }
    final facing = colliderFacingSign(world, player);
    final x =
        physicsCoordinateToTicks(world.transform.posX[ti]) +
        capsule.offsetXTicks[pi] * facing;
    final y =
        physicsCoordinateToTicks(world.transform.posY[ti]) +
        capsule.offsetYTicks[pi];
    final min = physicsCoordinateToTicks(encounter.minX);
    final max = physicsCoordinateToTicks(encounter.maxX);
    final towardCenter = x * 2 <= min + max ? 1 : -1;
    final inset = _itemProfile.halfWidthTicks + _itemProfile.noSpawnMarginTicks;

    // 64 world units makes collection deliberate; 96/32 are bounded fallbacks
    // for obstacles and narrow supports, always checking both sides in order.
    for (final distance in const [64, 96, 32]) {
      for (final direction in [towardCenter, -towardCenter]) {
        final targetX =
            x + distance * direction * terrainPhysicsTicksPerWorldUnit;
        if (targetX - inset < min || targetX + inset > max) continue;
        if ((targetX - x).abs() <= capsule.radiusTicks[pi] + inset) continue;
        final placement = motion.resolveSpawnPlacement(
          TerrainSpawnPlacementRequest(
            profile: _itemProfile,
            desiredBodyCenter: TerrainPoint(targetX, y),
            supportSelection: TerrainSpawnSupportSelection.deferredEdge,
            intendedSupportEdgeId: contact.supportEdgeId[ci],
          ),
        );
        if (!placement.accepted) continue;
        _preview!.moveAtValues(
          centerXTicks: x,
          centerYTicks: y,
          radiusTicks: capsule.radiusTicks[pi],
          verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks[pi],
          displacementXTicks: targetX - x,
          displacementYTicks: 0,
          surfaceDirectionSign: direction,
          mode: TerrainMotionMode.groundedHorizontal,
          horizontalBounds: TerrainHorizontalBounds(
            minXTicks: min,
            maxXTicks: max,
          ),
          beganGrounded: true,
          priorSupportEdgeId: contact.supportEdgeId[ci],
          priorSupportGeometryVersion: bundle.version,
          lastValidCapsuleCenterXTicks: x,
          lastValidCapsuleCenterYTicks: y,
          out: _result,
        );
        if (!_result.grounded ||
            _result.supportEdgeId != contact.supportEdgeId[ci] ||
            (_result.finalCenterXTicks - targetX).abs() >
                terrainCollisionSkinTicks + terrainContactEpsilonTicks) {
          continue;
        }
        final body = placement.bodyCenter!;
        return spawns.spawnRestorationItemAt(
          body.xTicks / terrainPhysicsTicksPerWorldUnit,
          body.yTicks / terrainPhysicsTicksPerWorldUnit,
          stat,
        );
      }
    }
    return null;
  }
}
