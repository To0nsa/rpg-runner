import 'weapon_id.dart';
import 'weapon_def.dart';
import 'weapon_data.generated.dart';

/// Typed runtime definitions compiled from the single item authoring source.
class WeaponCatalog {
  const WeaponCatalog();
  WeaponDef get(WeaponId id) => authoredWeaponIdDefinitions[id]!;
  WeaponDef? tryGet(WeaponId id) => authoredWeaponIdDefinitions[id];
}
