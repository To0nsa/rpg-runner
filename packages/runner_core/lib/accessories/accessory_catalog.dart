import 'accessory_id.dart';
import 'accessory_def.dart';
import 'accessory_data.generated.dart';

/// Typed runtime definitions compiled from the single item authoring source.
class AccessoryCatalog {
  const AccessoryCatalog();
  AccessoryDef get(AccessoryId id) => authoredAccessoryIdDefinitions[id]!;
  AccessoryDef? tryGet(AccessoryId id) => authoredAccessoryIdDefinitions[id];
}
