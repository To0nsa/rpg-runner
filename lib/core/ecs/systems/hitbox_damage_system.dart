import '../../combat/damage.dart';
import '../../events/game_event.dart';
import '../hit/hit_resolver.dart';
import '../spatial/broadphase_grid.dart';
import '../world.dart';

/// Detects collisions between active hitboxes (melee strikes) and vulnerable targets.
///
/// **Responsibilities**:
/// *   Iterate over all active hitboxes (entities with `HitboxStore`).
/// *   Perform broadphase/narrowphase collision checks against potential targets.
/// *   Filter hits based on faction (Friendly fire prevention).
/// *   Enforce "Hit Once" logic to prevent a single frame of strike from dealing damage every tick.
/// *   Queue [DamageRequest]s for resolved hits.
class HitboxDamageSystem {
  /// Helper for spatial queries and overlap sorting.
  final HitResolver _resolver = HitResolver();
  
  /// Reused buffer to store indices of overlapping entities each frame.
  final List<int> _overlaps = <int>[];

  /// Executes the system logic.
  ///
  /// [queueDamage] is a callback to the central event system to register damage.
  /// [broadphase] provides the spatial index of all damageable entities this frame.
  void step(
    EcsWorld world,
    void Function(DamageRequest request) queueDamage,
    BroadphaseGrid broadphase,
  ) {
    final hitboxes = world.hitbox;
    // Early exit if no active strikes exist.
    if (hitboxes.denseEntities.isEmpty) return;

    // Early exit if there are no targets to hit.
    if (broadphase.targets.isEmpty) return;

    // Process each active hitbox.
    for (var hi = 0; hi < hitboxes.denseEntities.length; hi += 1) {
      final hb = hitboxes.denseEntities[hi];
      
      // Hitboxes must have a position (Transform) to overlap anything.
      if (!world.transform.has(hb)) continue;
      
      // Hitboxes must have a HitOnce state to track who they've already damaged.
      // This prevents "machine gun" damage from a lingering sword swing.
      if (!world.hitOnce.has(hb)) continue;

      final hbTi = world.transform.indexOf(hb);
      final hbCx = world.transform.posX[hbTi];
      final hbCy = world.transform.posY[hbTi];
      final hbHalfX = hitboxes.halfX[hi];
      final hbHalfY = hitboxes.halfY[hi];
      final hbDirX = hitboxes.dirX[hi];
      final hbDirY = hitboxes.dirY[hi];

      // Calculate capsule segment endpoints.
      // We interpret `halfX` as the half-length along the direction vector,
      // and `halfY` as the capsule radius (thickness).
      // This effectively creates a capsule centered at (hbCx, hbCy) oriented along (hbDirX, hbDirY).
      final ax = hbCx - hbDirX * hbHalfX;
      final ay = hbCy - hbDirY * hbHalfX;
      final bx = hbCx + hbDirX * hbHalfX;
      final by = hbCy + hbDirY * hbHalfX;

      final owner = hitboxes.owner[hi];
      final sourceFaction = hitboxes.faction[hi];

      if (world.deathState.has(owner)) continue;
      
      // Resolve enemy ID efficiently if the owner is an enemy.
      // This is used for kill credit/stats.
      final enemyIndex = world.enemy.tryIndexOf(owner);
      final enemyId = enemyIndex != null
          ? world.enemy.enemyId[enemyIndex]
          : null;

      // Ensure buffer is clear before collection (safety measure).
      _overlaps.clear();
      
      // Query the spatial grid for potential overlaps.
      // This handles the geometric check (Capsule vs Target Bounds) and Faction check.
      _resolver.collectOrderedOverlapsCapsule(
        broadphase: broadphase,
        ax: ax,
        ay: ay,
        bx: bx,
        by: by,
        radius: hbHalfY,
        owner: owner,
        sourceFaction: sourceFaction,
        outTargetIndices: _overlaps,
      );
      if (_overlaps.isEmpty) continue;

      // Register hits for verified overlaps.
      for (var i = 0; i < _overlaps.length; i += 1) {
        final ti = _overlaps[i];
        final target = broadphase.targets.entities[ti];
        
        // "Hit Once" Check: Has this specific hitbox entity already struck this specific target entity?
        if (world.hitOnce.hasHit(hb, target)) continue;
        
        // Mark as hit so we don't damage them again this swing.
        world.hitOnce.markHit(hb, target);

        // Send the damage request.
        queueDamage(
          DamageRequest(
            target: target,
            amount100: hitboxes.damage100[hi],
            damageType: hitboxes.damageType[hi],
            statusProfileId: hitboxes.statusProfileId[hi],
            procs: hitboxes.procs[hi],
            source: owner,
            sourceKind: DeathSourceKind.meleeHitbox,
            sourceEnemyId: enemyId,
          ),
        );
      }
    }
  }
}
