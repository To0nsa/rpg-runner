import 'package:flutter/foundation.dart';

import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/domain/prefab_platform_pairing.dart';
import '../../../../prefabs/models/models.dart';
import 'prefab_owner_order.dart';

/// Deterministic presentation catalog for the Collision workflow.
///
/// The catalog filters immutable document data only. Pairing authority and
/// mutations remain in the Prefab domain command layer.
@immutable
final class PrefabCollisionCatalog {
  const PrefabCollisionCatalog._({
    required this.prefabs,
    required this.prefabsNeedingCollision,
    required this.unpairedModules,
  });

  factory PrefabCollisionCatalog.fromDocument(PrefabV3Document document) {
    final prefabs =
        document.data.prefabs
            .where(canAuthorPrefabCollision)
            .toList(growable: false)
          ..sort(comparePrefabOwners);
    final prefabsNeedingCollision = prefabs
        .where((prefab) => prefab.collisionShapes.isEmpty)
        .toList(growable: false);
    final unpairedModules = document.tileData.platformModules
        .where(
          (module) => PrefabPlatformPairing.ownersForModule(
            document.data,
            module.id,
          ).isEmpty,
        )
        .toList(growable: false);
    return PrefabCollisionCatalog._(
      prefabs: List<PrefabV3Def>.unmodifiable(prefabs),
      prefabsNeedingCollision: List<PrefabV3Def>.unmodifiable(
        prefabsNeedingCollision,
      ),
      unpairedModules: List<TileModuleDef>.unmodifiable(unpairedModules),
    );
  }

  final List<PrefabV3Def> prefabs;
  final List<PrefabV3Def> prefabsNeedingCollision;
  final List<TileModuleDef> unpairedModules;
}
