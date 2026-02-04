import '../../core/projectiles/projectile_item_catalog.dart';
import '../../core/projectiles/projectile_item_id.dart';
import '../../core/abilities/ability_def.dart' show WeaponType;

String? throwingWeaponAssetPath(
  ProjectileItemId id, {
  ProjectileItemCatalog catalog = const ProjectileItemCatalog(),
}) {
  final def = catalog.tryGet(id);
  if (def == null || def.weaponType != WeaponType.throwingWeapon) return null;
  return switch (id) {
    ProjectileItemId.throwingKnife =>
      'assets/images/weapons/throwingWeapons/throwingKnife.png',
    ProjectileItemId.throwingAxe =>
      'assets/images/weapons/throwingWeapons/throwingAxe.png',
    ProjectileItemId.iceBolt => null,
    ProjectileItemId.fireBolt => null,
    ProjectileItemId.thunderBolt => null,
  };
}
