import 'projectile_data.generated.dart';
import '../abilities/ability_def.dart' show WeaponType;
import '../combat/damage_type.dart';
import '../projectiles/projectile_id.dart';
import 'projectile_item_def.dart';

/// Projectile physics and payloads; player membership uses the explicit ID list.
class ProjectileCatalog {
  const ProjectileCatalog();

  ProjectileItemDef get(ProjectileId id) {
    final authored = authoredProjectileIdDefinitions[id];
    if (authored != null) return authored;
    switch (id) {
      case ProjectileId.hunterBomb:
        return const ProjectileItemDef(
          id: ProjectileId.hunterBomb,
          weaponType: WeaponType.bombKit,
          // Maximum launch speed; closer targets use a slower lob.
          speedUnitsPerSecond: 520,
          lifetimeSeconds: 3,
          colliderSizeX: 6,
          colliderSizeY: 6,
          ballistic: true,
          gravityScale: 0.6,
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

      default:
        throw ArgumentError.value(id, 'id', 'No projectile definition.');
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
