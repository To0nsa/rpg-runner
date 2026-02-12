import '../abilities/ability_def.dart' show WeaponType;
import '../combat/damage_type.dart';
import '../combat/status/status.dart';
import '../projectiles/projectile_id.dart';
import '../weapons/weapon_proc.dart';
import 'projectile_item_def.dart';

/// Lookup table for projectile slot items (spells + throwing weapons).
class ProjectileItemCatalog {
  const ProjectileItemCatalog();

  ProjectileItemDef get(ProjectileId id) {
    switch (id) {
      // Spells
      case ProjectileId.iceBolt:
        return const ProjectileItemDef(
          id: ProjectileId.iceBolt,
          weaponType: WeaponType.projectileSpell,
          speedUnitsPerSecond: 1000.0,
          lifetimeSeconds: 1.0,
          colliderSizeX: 18.0,
          colliderSizeY: 8.0,
          ballistic: false,
          gravityScale: 1.0,
          damageType: DamageType.ice,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.slowOnHit,
              chanceBp: 10000,
            ),
          ],
        );
      case ProjectileId.fireBolt:
        return const ProjectileItemDef(
          id: ProjectileId.fireBolt,
          weaponType: WeaponType.projectileSpell,
          speedUnitsPerSecond: 900.0,
          lifetimeSeconds: 1.3,
          colliderSizeX: 20.0,
          colliderSizeY: 10.0,
          ballistic: false,
          gravityScale: 1.0,
          damageType: DamageType.fire,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.burnOnHit,
              chanceBp: 10000,
            ),
          ],
        );
      case ProjectileId.acidBolt:
        return const ProjectileItemDef(
          id: ProjectileId.acidBolt,
          weaponType: WeaponType.projectileSpell,
          speedUnitsPerSecond: 900.0,
          lifetimeSeconds: 1.3,
          colliderSizeX: 20.0,
          colliderSizeY: 10.0,
          ballistic: false,
          gravityScale: 1.0,
          damageType: DamageType.acid,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.acidOnHit,
              chanceBp: 10000,
            ),
          ],
        );
      case ProjectileId.thunderBolt:
        return const ProjectileItemDef(
          id: ProjectileId.thunderBolt,
          weaponType: WeaponType.projectileSpell,
          speedUnitsPerSecond: 1000.0,
          lifetimeSeconds: 1.2,
          colliderSizeX: 16.0,
          colliderSizeY: 8.0,
          ballistic: false,
          gravityScale: 1.0,
          damageType: DamageType.thunder,
        );

      // Throwing weapons
      case ProjectileId.throwingKnife:
        return const ProjectileItemDef(
          id: ProjectileId.throwingKnife,
          weaponType: WeaponType.throwingWeapon,
          speedUnitsPerSecond: 900.0,
          lifetimeSeconds: 1.2,
          colliderSizeX: 14.0,
          colliderSizeY: 6.0,
          originOffset: 6.0,
          ballistic: true,
          gravityScale: 0.9,
          damageType: DamageType.physical,
        );
      case ProjectileId.throwingAxe:
        return const ProjectileItemDef(
          id: ProjectileId.throwingAxe,
          weaponType: WeaponType.throwingWeapon,
          speedUnitsPerSecond: 800.0,
          lifetimeSeconds: 1.6,
          colliderSizeX: 16.0,
          colliderSizeY: 10.0,
          originOffset: 8.0,
          ballistic: true,
          gravityScale: 1.0,
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
