import '../../combat/damage.dart';
import '../../events/game_event.dart';
import '../entity_id.dart';
import '../hit/hit_resolver.dart';
import '../spatial/broadphase_grid.dart';
import '../world.dart';

/// Handles collision detection for projectiles against potentially damageable targets.
///
/// **Responsibilities**:
/// - Iterates all active projectiles.
/// - Calculates a swept capsule shape for the projectile based on its velocity/direction.
/// - Queries the [BroadphaseGrid] for collisions.
/// - Queues [DamageRequest] and despawns the projectile on impact.
class ProjectileHitSystem {
  final List<EntityId> _toDespawn = <EntityId>[];
  final HitResolver _resolver = HitResolver();

  /// Runs the system logic for a single tick.
  ///
  /// [queueDamage] is a callback to the central `DamageSystem` or event queue.
  /// [broadphase] provides spatial acceleration for finding targets efficiently.
  void step(
    EcsWorld world,
    void Function(DamageRequest request) queueDamage,
    BroadphaseGrid broadphase,
  ) {
    // Optimization: If there are no targets to hit, projectiles just fly.
    if (broadphase.targets.isEmpty) return;
    
    final projectiles = world.projectile;
    if (projectiles.denseEntities.isEmpty) return;

    _toDespawn.clear();

    // Cache store references for efficient lookup (Hoisting).
    final transforms = world.transform;
    final colliders = world.colliderAabb;
    final enemies = world.enemy;
    final spellOrigins = world.spellOrigin;

    final count = projectiles.denseEntities.length;
    for (var pi = 0; pi < count; pi += 1) {
      final p = projectiles.denseEntities[pi];
      
      // Validation: Projectiles must have physical presence.
      final ti = transforms.tryIndexOf(p);
      if (ti == null) continue;

      final ci = colliders.tryIndexOf(p);
      if (ci == null) continue;

      // -- Geometry Construction --
      // Projectiles are modeled as capsules (swept circles) oriented along their velocity vector.
      // - [offsetX/Y]: Center offset relative to transform.
      // - [halfX]: Interpreted as half-length of the capsule shaft.
      // - [halfY]: Interpreted as the radius (thickness) of the projectile.
      final pcx = transforms.posX[ti] + colliders.offsetX[ci];
      final pcy = transforms.posY[ti] + colliders.offsetY[ci];
      
      final halfLength = colliders.halfX[ci];
      final radius = colliders.halfY[ci];
      
      final dirX = projectiles.dirX[pi];
      final dirY = projectiles.dirY[pi];

      // Calculate the start (A) and end (B) points of the capsule segment.
      // The segment is centered at (pcx, pcy) and extends halfLength in both directions along (dirX, dirY).
      final ax = pcx - dirX * halfLength;
      final ay = pcy - dirY * halfLength;
      final bx = pcx + dirX * halfLength;
      final by = pcy + dirY * halfLength;

      // -- Hit Resolution --
      final owner = projectiles.owner[pi];
      final sourceFaction = projectiles.faction[pi];

      // Query the broadphase for the first valid intersection.
      // This respects "Friendly Fire" rules via [sourceFaction].
      final targetIndex = _resolver.firstOrderedOverlapCapsule(
        broadphase: broadphase,
        ax: ax,
        ay: ay,
        bx: bx,
        by: by,
        radius: radius,
        owner: owner,
        sourceFaction: sourceFaction,
      );

      // -- Impact Handling --
      if (targetIndex != null) {
        // Optimization: Resolve heavy metadata (EnemyId, SpellId) ONLY when a hit actually occurs.
        // Doing this before the hit check would waste cycles for the 99% of frames a projectile is just flying.
        final ei = enemies.tryIndexOf(owner);
        final enemyId = ei != null ? enemies.enemyId[ei] : null;
        
        final si = spellOrigins.tryIndexOf(p);
        final spellId = si != null ? spellOrigins.spellId[si] : null;

        // Dispatch damage event.
        queueDamage(
          DamageRequest(
            target: broadphase.targets.entities[targetIndex],
            amount: projectiles.damage[pi],
            damageType: projectiles.damageType[pi],
            statusProfileId: projectiles.statusProfileId[pi],
            source: owner,
            sourceKind: DeathSourceKind.projectile,
            sourceEnemyId: enemyId,
            sourceProjectileId: projectiles.projectileId[pi],
            sourceSpellId: spellId,
          ),
        );
        
        // Mark projectile for removal.
        // We defer removal until after the loop or use a list to avoid modifying the collection while iterating
        // (though we are iterating by index here, deferred removal is safer/cleaner pattern).
        _toDespawn.add(p);
      }
    }

    // Process despawns.
    for (final e in _toDespawn) {
      world.destroyEntity(e);
    }
  }
}
