import '../abilities/ability_def.dart' show WeaponType;
import '../combat/damage_type.dart';
import '../combat/status/status.dart';
import '../projectiles/projectile_id.dart';
import '../weapons/weapon_proc.dart';
import 'projectile_item_def.dart';

/// Projectile physics and payloads; player membership uses the explicit ID list.
class ProjectileCatalog {
  const ProjectileCatalog();

  ProjectileItemDef get(ProjectileId id) {
    switch (id) {
      case ProjectileId.hunterPistol:
        return const ProjectileItemDef(
          id: ProjectileId.hunterPistol,
          weaponType: WeaponType.firearm,
          speedUnitsPerSecond: 720,
          lifetimeSeconds: .9,
          colliderSizeX: 8,
          colliderSizeY: 3,
        );
      case ProjectileId.hunterCrossbow:
        return const ProjectileItemDef(
          id: ProjectileId.hunterCrossbow,
          weaponType: WeaponType.crossbow,
          speedUnitsPerSecond: 600,
          lifetimeSeconds: 1.4,
          colliderSizeX: 16,
          colliderSizeY: 3,
          damageScaleBp: 11500,
        );
      case ProjectileId.hunterShotgun:
        return const ProjectileItemDef(
          id: ProjectileId.hunterShotgun,
          weaponType: WeaponType.firearm,
          speedUnitsPerSecond: 620,
          lifetimeSeconds: .42,
          colliderSizeX: 6,
          colliderSizeY: 3,
          shotCount: 3,
          spreadRadians: .18,
          damageScaleBp: 13000,
        );
      case ProjectileId.hunterRoadsidePistol:
        return const ProjectileItemDef(
          id: ProjectileId.hunterRoadsidePistol,
          weaponType: WeaponType.firearm,
          speedUnitsPerSecond: 850,
          lifetimeSeconds: 0.55,
          colliderSizeX: 8,
          colliderSizeY: 3,
          damageScaleBp: 11000,
          shotCount: 1,
          spreadRadians: 0,
        );
      case ProjectileId.hunterLongbarrelPistol:
        return const ProjectileItemDef(
          id: ProjectileId.hunterLongbarrelPistol,
          weaponType: WeaponType.firearm,
          speedUnitsPerSecond: 800,
          lifetimeSeconds: 1.0,
          colliderSizeX: 8,
          colliderSizeY: 3,
          damageScaleBp: 9000,
          shotCount: 1,
          spreadRadians: 0,
        );
      case ProjectileId.hunterLongwatchCrossbow:
        return const ProjectileItemDef(
          id: ProjectileId.hunterLongwatchCrossbow,
          weaponType: WeaponType.crossbow,
          speedUnitsPerSecond: 720,
          lifetimeSeconds: 1.35,
          colliderSizeX: 16,
          colliderSizeY: 3,
          damageScaleBp: 10000,
          shotCount: 1,
          spreadRadians: 0,
        );
      case ProjectileId.hunterHeavyLimbCrossbow:
        return const ProjectileItemDef(
          id: ProjectileId.hunterHeavyLimbCrossbow,
          weaponType: WeaponType.crossbow,
          speedUnitsPerSecond: 500,
          lifetimeSeconds: 1.0,
          colliderSizeX: 16,
          colliderSizeY: 3,
          damageScaleBp: 12500,
          shotCount: 1,
          spreadRadians: 0,
        );
      case ProjectileId.hunterBrushgun:
        return const ProjectileItemDef(
          id: ProjectileId.hunterBrushgun,
          weaponType: WeaponType.firearm,
          speedUnitsPerSecond: 620,
          lifetimeSeconds: 0.55,
          colliderSizeX: 6,
          colliderSizeY: 3,
          damageScaleBp: 11000,
          shotCount: 5,
          spreadRadians: 0.28,
        );
      case ProjectileId.hunterBomb:
        return const ProjectileItemDef(
          id: ProjectileId.hunterBomb,
          weaponType: WeaponType.bombKit,
          speedUnitsPerSecond: 0,
          lifetimeSeconds: 3,
          colliderSizeX: 6,
          colliderSizeY: 6,
          ballistic: true,
        );
      case ProjectileId.unknown:
      case ProjectileId.poisonDart:
        throw ArgumentError.value(
          id,
          'id',
          'Projectile is not a player-equippable item.',
        );

      // Spells
      case ProjectileId.npcSpear:
        return const ProjectileItemDef(
          id: ProjectileId.npcSpear,
          weaponType: WeaponType.spear,
          speedUnitsPerSecond: 420,
          // Seconds: allow missed throws to land; bound flight across deep gaps.
          lifetimeSeconds: 6,
          ballistic: true,
          // Half of level gravity gives a visible arc within the 260px AI range.
          gravityScale: .5,
          colliderSizeX: 55.5,
          colliderSizeY: 7.5,
        );
      case ProjectileId.goddessOrb:
        return const ProjectileItemDef(
          id: ProjectileId.goddessOrb,
          weaponType: WeaponType.spell,
          // World units/second: crosses 300 units in about 0.63 seconds.
          speedUnitsPerSecond: 480,
          lifetimeSeconds: 2,
          colliderSizeX: 30,
          colliderSizeY: 30,
          damageType: DamageType.dark,
        );
      case ProjectileId.shoggothOrb:
        return ProjectileItemDef(
          id: id,
          weaponType: WeaponType.spell,
          speedUnitsPerSecond: 340,
          lifetimeSeconds: 2,
          colliderSizeX: 30,
          colliderSizeY: 30,
          damageType: DamageType.dark,
        );
      case ProjectileId.voidClaw:
        return const ProjectileItemDef(
          id: ProjectileId.voidClaw,
          weaponType: WeaponType.spell,
          speedUnitsPerSecond: 300,
          lifetimeSeconds: 2,
          colliderSizeX: 60,
          colliderSizeY: 36,
          damageType: DamageType.fire,
        );
      case ProjectileId.npcArrow:
        return const ProjectileItemDef(
          id: ProjectileId.npcArrow,
          weaponType: WeaponType.bow,
          speedUnitsPerSecond: 550,
          lifetimeSeconds: 1.2,
          colliderSizeX: 28.5,
          colliderSizeY: 4.5,
        );

      case ProjectileId.iceBolt:
        return const ProjectileItemDef(
          id: ProjectileId.iceBolt,
          weaponType: WeaponType.spell,
          speedUnitsPerSecond: 600.0,
          lifetimeSeconds: 1.3,
          colliderSizeX: 25.0,
          colliderSizeY: 9.0,
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
          colliderSizeX: 31.5,
          colliderSizeY: 10.8438,
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
          colliderSizeX: 2.0,
          colliderSizeY: 12.0,
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
          colliderSizeX: 14.625,
          colliderSizeY: 13.5,
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
          colliderSizeY: 10.0,
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
          colliderSizeX: 27.5,
          colliderSizeY: 9.0,
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
          colliderSizeX: 23.0,
          colliderSizeY: 10.5,
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
          colliderSizeX: 26.5,
          colliderSizeY: 8.0,
          damageType: DamageType.thunder,
          procs: <WeaponProc>[
            WeaponProc(
              hook: ProcHook.onHit,
              statusProfileId: StatusProfileId.stunOnHit,
            ),
          ],
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
