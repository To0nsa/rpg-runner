import '../abilities/ability_def.dart' show WeaponType;
import '../combat/damage_type.dart';
import '../combat/status/status.dart';
import '../projectiles/projectile_id.dart';
import '../weapons/weapon_proc.dart';
import 'projectile_item_def.dart';
import 'projectile_item_id.dart';

/// Lookup table for projectile slot items (spells + throwing weapons).
class ProjectileItemCatalog {
  const ProjectileItemCatalog();

  ProjectileItemDef get(ProjectileItemId id) {
    switch (id) {
      // Spells
      case ProjectileItemId.iceBolt:
        return const ProjectileItemDef(
          id: ProjectileItemId.iceBolt,
          weaponType: WeaponType.projectileSpell,
          projectileId: ProjectileId.iceBolt,
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
      case ProjectileItemId.fireBolt:
        return const ProjectileItemDef(
          id: ProjectileItemId.fireBolt,
          weaponType: WeaponType.projectileSpell,
          projectileId: ProjectileId.fireBolt,
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
      case ProjectileItemId.thunderBolt:
        return const ProjectileItemDef(
          id: ProjectileItemId.thunderBolt,
          weaponType: WeaponType.projectileSpell,
          projectileId: ProjectileId.thunderBolt,
          ballistic: false,
          gravityScale: 1.0,
          damageType: DamageType.thunder,
        );

      // Throwing weapons
      case ProjectileItemId.throwingKnife:
        return const ProjectileItemDef(
          id: ProjectileItemId.throwingKnife,
          weaponType: WeaponType.throwingWeapon,
          projectileId: ProjectileId.throwingKnife,
          originOffset: 6.0,
          ballistic: true,
          gravityScale: 0.9,
          damageType: DamageType.physical,
        );
      case ProjectileItemId.throwingAxe:
        return const ProjectileItemDef(
          id: ProjectileItemId.throwingAxe,
          weaponType: WeaponType.throwingWeapon,
          projectileId: ProjectileId.throwingAxe,
          originOffset: 8.0,
          ballistic: true,
          gravityScale: 1.0,
          damageType: DamageType.physical,
        );
    }
  }

  ProjectileItemDef? tryGet(ProjectileItemId id) {
    try {
      return get(id);
    } catch (_) {
      return null;
    }
  }
}
