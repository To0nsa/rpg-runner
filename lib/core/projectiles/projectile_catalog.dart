import '../abilities/ability_def.dart' show WeaponType;
import '../combat/damage_type.dart';
import '../combat/status/status.dart';
import '../projectiles/projectile_id.dart';
import '../weapons/weapon_proc.dart';
import 'projectile_item_def.dart';

/// Lookup table for projectile slot items (spells + throwing weapons).
class ProjectileCatalog {
  const ProjectileCatalog();

  ProjectileItemDef get(ProjectileId id) {
    switch (id) {
      case ProjectileId.unknown:
        throw ArgumentError.value(
          id,
          'id',
          'ProjectileId.unknown has no catalog entry.',
        );

      // Spells
      case ProjectileId.iceBolt:
        return const ProjectileItemDef(
          id: ProjectileId.iceBolt,
          weaponType: WeaponType.spell,
          speedUnitsPerSecond: 600.0,
          lifetimeSeconds: 1.3,
          colliderSizeX: 18.0,
          colliderSizeY: 8.0,
          originOffset: 30.0,
          damageType: DamageType.ice,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.slowOnHit,
            ),
          ],
        );
      case ProjectileId.fireBolt:
        return const ProjectileItemDef(
          id: ProjectileId.fireBolt,
          weaponType: WeaponType.spell,
          speedUnitsPerSecond: 600.0,
          lifetimeSeconds: 1.3,
          colliderSizeX: 18.0,
          colliderSizeY: 8.0,
          originOffset: 30.0,
          damageType: DamageType.fire,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.burnOnHit,
            ),
          ],
        );
      case ProjectileId.acidBolt:
        return const ProjectileItemDef(
          id: ProjectileId.acidBolt,
          weaponType: WeaponType.spell,
          speedUnitsPerSecond: 500.0,
          lifetimeSeconds: 1.3,
          colliderSizeX: 18.0,
          colliderSizeY: 8.0,
          originOffset: 30.0,
          damageType: DamageType.acid,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.acidOnHit,
            ),
          ],
        );
      case ProjectileId.darkBolt:
        return const ProjectileItemDef(
          id: ProjectileId.darkBolt,
          weaponType: WeaponType.spell,
          speedUnitsPerSecond: 550.0,
          lifetimeSeconds: 1.3,
          colliderSizeX: 18.0,
          colliderSizeY: 8.0,
          originOffset: 30.0,
          damageType: DamageType.dark,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.weakenOnHit,
            ),
          ],
        );
      case ProjectileId.earthBolt:
        return const ProjectileItemDef(
          id: ProjectileId.earthBolt,
          weaponType: WeaponType.spell,
          speedUnitsPerSecond: 500.0,
          lifetimeSeconds: 1.3,
          colliderSizeX: 18.0,
          colliderSizeY: 8.0,
          originOffset: 30.0,
          damageType: DamageType.earth,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.stunOnHit,
            ),
          ],
        );
      case ProjectileId.holyBolt:
        return const ProjectileItemDef(
          id: ProjectileId.holyBolt,
          weaponType: WeaponType.spell,
          speedUnitsPerSecond: 550.0,
          lifetimeSeconds: 1.3,
          colliderSizeX: 18.0,
          colliderSizeY: 8.0,
          originOffset: 30.0,
          damageType: DamageType.holy,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.silenceOnHit,
            ),
          ],
        );
      case ProjectileId.waterBolt:
        return const ProjectileItemDef(
          id: ProjectileId.waterBolt,
          weaponType: WeaponType.spell,
          speedUnitsPerSecond: 550.0,
          lifetimeSeconds: 1.3,
          colliderSizeX: 18.0,
          colliderSizeY: 8.0,
          originOffset: 22.0,
          damageType: DamageType.water,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.drenchOnHit,
            ),
          ],
        );
      case ProjectileId.thunderBolt:
        return const ProjectileItemDef(
          id: ProjectileId.thunderBolt,
          weaponType: WeaponType.spell,
          speedUnitsPerSecond: 650.0,
          lifetimeSeconds: 1.3,
          colliderSizeX: 18.0,
          colliderSizeY: 8.0,
          originOffset: 30.0,
          damageType: DamageType.thunder,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.stunOnHit,
            ),
          ],
        );

      // Throwing weapons
      case ProjectileId.throwingKnife:
        return const ProjectileItemDef(
          id: ProjectileId.throwingKnife,
          weaponType: WeaponType.throwingWeapon,
          speedUnitsPerSecond: 600.0,
          lifetimeSeconds: 3.0,
          colliderSizeX: 18.0,
          colliderSizeY: 8.0,
          originOffset: 30.0,
          ballistic: true,
          gravityScale: 0.6,
          damageType: DamageType.physical,
        );
      case ProjectileId.throwingAxe:
        return const ProjectileItemDef(
          id: ProjectileId.throwingAxe,
          weaponType: WeaponType.throwingWeapon,
          speedUnitsPerSecond: 600.0,
          lifetimeSeconds: 3.0,
          colliderSizeX: 18.0,
          colliderSizeY: 8.0,
          originOffset: 30.0,
          ballistic: true,
          gravityScale: 0.7,
          damageType: DamageType.physical,
        );
    }
  }

  ProjectileItemDef? tryGet(ProjectileId id) {
    try {
      return get(id);
    } catch (_) {
      return null;
    }
  }
}
