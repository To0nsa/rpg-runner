import '../combat/damage_type.dart';
import '../combat/faction.dart';
import '../combat/hit_target_policy.dart';
import '../combat/status/status.dart';
import '../ecs/entity_id.dart';
import '../ecs/stores/collider_aabb_store.dart';
import '../ecs/stores/lifetime_store.dart';
import '../ecs/stores/projectile_store.dart';
import '../ecs/world.dart';
import '../projectiles/projectile_id.dart';
import '../weapons/weapon_proc.dart';
import 'trap_catalog.dart';
import 'trap_placement.dart';

/// Small environmental spawn policy; common projectile systems own all motion,
/// collision, damage and expiry after this point.
EntityId spawnTrapDart(
  EcsWorld world, {
  required TrapSourceRef source,
  required double x,
  required double y,
  required double directionX,
  required int tick,
  required int tickHz,
}) {
  final entity = world.createEntity();
  world.transform.add(
    entity,
    posX: x,
    posY: y,
    velX: directionX * TrapCatalog.dartSpeed,
    velY: 0,
  );
  world.projectile.add(
    entity,
    ProjectileEntityDef(
      projectileId: ProjectileId.poisonDart,
      faction: Faction.player,
      owner: 0,
      targetPolicy: HitTargetPolicy.allActors,
      sourceTrap: source,
      firstHitTick: tick + 1,
      dirX: directionX,
      dirY: 0,
      speedUnitsPerSecond: TrapCatalog.dartSpeed,
      damage100: TrapCatalog.dartDamage100,
      damageType: DamageType.poison,
      procs: const [
        WeaponProc(
          hook: ProcHook.onHit,
          statusProfileId: StatusProfileId.poisonOnHit,
        ),
      ],
    ),
  );
  world.colliderAabb.add(
    entity,
    const ColliderAabbDef(
      halfX: TrapCatalog.dartHalfLength,
      halfY: TrapCatalog.dartRadius,
    ),
  );
  // Cleanup runs on the spawn tick, before the first eligible motion tick.
  world.lifetime.add(
    entity,
    LifetimeDef(
      ticksLeft: (TrapCatalog.dartLifetimeSeconds * tickHz).ceil() + 1,
    ),
  );
  return entity;
}
