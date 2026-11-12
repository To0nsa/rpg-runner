import 'weapon_id.dart';
import 'weapon_def.dart';
import 'weapon_data.generated.dart';

/// Typed runtime definitions compiled from the single item authoring source.
class WeaponCatalog {
  const WeaponCatalog();
  WeaponDef get(WeaponId id) => authoredWeaponIdDefinitions[id]!;

  /// Keeps optional lookup consistent with injected catalog definitions.
  WeaponDef? tryGet(WeaponId id) {
    try {
      return get(id);
    } catch (_) {
      return null;
    }
  }
}
