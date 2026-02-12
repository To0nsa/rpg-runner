import '../../core/projectiles/projectile_item_catalog.dart';
import '../../core/projectiles/projectile_id.dart';
import '../../core/abilities/ability_def.dart' show WeaponType;

String? throwingWeaponAssetPath(
  ProjectileId id, {
  ProjectileItemCatalog catalog = const ProjectileItemCatalog(),
}) {
  final def = catalog.tryGet(id);
  if (def == null || def.weaponType != WeaponType.throwingWeapon) return null;
  return switch (id) {
    ProjectileId.throwingKnife =>
      'assets/images/weapons/throwingWeapons/throwingKnife.png',
    ProjectileId.throwingAxe =>
      'assets/images/weapons/throwingWeapons/throwingAxe.png',
    ProjectileId.iceBolt => null,
    ProjectileId.fireBolt => null,
    ProjectileId.acidBolt => null,
    ProjectileId.thunderBolt => null,
  };
}
