import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/prefab_runtime_adapter.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';

void main() {
  test('buildRuntimePrefabContracts maps and orders valid prefabs', () {
    final data = PrefabData(
      prefabs: [
        PrefabDef(
          prefabKey: 'z_key',
          id: 'z_id',
          revision: 2,
          status: PrefabStatus.active,
          kind: PrefabKind.platform,
          visualSource: PrefabVisualSource.platformModule('module_a'),
          anchorXPx: 0,
          anchorYPx: 0,
          colliders: const [
            PrefabColliderDef(offsetX: 0, offsetY: 0, width: 16, height: 16),
          ],
          tags: const ['z'],
        ),
        PrefabDef(
          prefabKey: 'a_key',
          id: 'a_id',
          revision: 1,
          status: PrefabStatus.active,
          kind: PrefabKind.obstacle,
          visualSource: PrefabVisualSource.atlasSlice('slice_a'),
          anchorXPx: 8,
          anchorYPx: 8,
          colliders: const [
            PrefabColliderDef(offsetX: 0, offsetY: 0, width: 8, height: 8),
          ],
        ),
      ],
    );

    final contracts = buildRuntimePrefabContracts(data);
    expect(contracts.map((contract) => contract.prefabKey), ['a_key', 'z_key']);
    expect(contracts.first.visualSourceType, 'atlas_slice');
    expect(contracts.last.visualSourceType, 'platform_module');
  });

  test('mapPrefabToRuntimeContract filters deprecated by default', () {
    final prefab = PrefabDef(
      prefabKey: 'old_prefab',
      id: 'old_prefab',
      revision: 3,
      status: PrefabStatus.deprecated,
      kind: PrefabKind.obstacle,
      visualSource: PrefabVisualSource.atlasSlice('slice_a'),
      anchorXPx: 0,
      anchorYPx: 0,
      colliders: const [
        PrefabColliderDef(offsetX: 0, offsetY: 0, width: 8, height: 8),
      ],
    );

    expect(mapPrefabToRuntimeContract(prefab), isNull);
    expect(
      mapPrefabToRuntimeContract(prefab, includeDeprecated: true),
      isNotNull,
    );
  });

  test(
    'mapPlacedPrefabToRuntimeRef prefers prefabKey and keeps legacy prefabId',
    () {
      final placed = PlacedPrefabDef(
        prefabId: 'legacy_id',
        prefabKey: 'stable_key',
        x: 48,
        y: 32,
        zIndex: 3,
        snapToGrid: false,
      );

      final runtimeRef = mapPlacedPrefabToRuntimeRef(placed);
      expect(runtimeRef.prefabKey, 'stable_key');
      expect(runtimeRef.legacyPrefabId, 'legacy_id');
      expect(runtimeRef.x, 48);
      expect(runtimeRef.y, 32);
      expect(runtimeRef.zIndex, 3);
      expect(runtimeRef.snapToGrid, isFalse);
    },
  );

  test('PlacedPrefabDef parses prefabKey-only JSON with prefabId fallback', () {
    final placed = PlacedPrefabDef.fromJson(const {
      'prefabKey': 'stable_key',
      'x': 16,
      'y': 32,
    });

    expect(placed.prefabKey, 'stable_key');
    expect(placed.prefabId, 'stable_key');
    expect(placed.resolvedPrefabRef, 'stable_key');
    expect(placed.snapToGrid, isTrue);
  });
}
