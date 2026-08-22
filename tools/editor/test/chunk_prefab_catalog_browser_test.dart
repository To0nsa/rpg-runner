import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_prefab_catalog_browser.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_models.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';

void main() {
  testWidgets(
    'catalog searches tokens, filters kind and usage, and returns stable owner',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String selectedPrefabKey = 'prefab_apple';
      PrefabV3Def? selectedPrefab;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Padding(
                padding: const EdgeInsets.all(16),
                child: ChunkPrefabCatalogBrowser(
                  prefabs: _prefabs,
                  prefabData: PrefabV3FileData(
                    slices: _slices,
                    prefabs: _prefabs,
                  ),
                  tileData: PrefabTileFileData(
                    tileSlices: const <AtlasSliceDef>[],
                    platformModules: const <TileModuleDef>[],
                  ),
                  visualBoundsByPrefabKey: _visualBounds,
                  workspaceRootPath: 'missing_workspace',
                  selectedPrefabKey: selectedPrefabKey,
                  usedPrefabKeys: const <String>{'prefab_dark_rock'},
                  gridHeight: 420,
                  onSelected: (prefab) {
                    selectedPrefab = prefab;
                    setState(() => selectedPrefabKey = prefab.prefabKey);
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('4 of 4 prefabs'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('chunk_prefab_catalog_card_prefab_apple'),
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('chunk_prefab_catalog_search')),
        'rock dark',
      );
      await tester.pump();
      expect(find.text('1 of 4 prefabs'), findsOneWidget);
      expect(find.text('dark_rock'), findsOneWidget);
      expect(find.text('light_rock'), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(selectedPrefab, same(_prefabs[1]));
      expect(selectedPrefabKey, 'prefab_dark_rock');

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_prefab_catalog_clear_search')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('chunk_prefab_catalog_kind_decoration'),
        ),
      );
      await tester.pump();
      expect(find.text('1 of 4 prefabs'), findsOneWidget);
      expect(find.text('apple'), findsOneWidget);
      expect(find.text('dark_rock'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_prefab_catalog_kind_all')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_prefab_catalog_used')),
      );
      await tester.pump();
      expect(find.text('1 of 4 prefabs'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('chunk_prefab_catalog_card_prefab_dark_rock'),
        ),
      );
      await tester.pump();
      expect(selectedPrefab, same(_prefabs[1]));
      expect(selectedPrefabKey, 'prefab_dark_rock');
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    },
  );

  testWidgets(
    'catalog exposes an explicit empty result without losing selection',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChunkPrefabCatalogBrowser(
              prefabs: _prefabs,
              prefabData: PrefabV3FileData(slices: _slices, prefabs: _prefabs),
              tileData: PrefabTileFileData(
                tileSlices: const <AtlasSliceDef>[],
                platformModules: const <TileModuleDef>[],
              ),
              visualBoundsByPrefabKey: _visualBounds,
              workspaceRootPath: 'missing_workspace',
              selectedPrefabKey: 'prefab_apple',
              usedPrefabKeys: const <String>{},
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('chunk_prefab_catalog_search')),
        'does-not-exist',
      );
      await tester.pump();

      expect(find.text('0 of 4 prefabs'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('chunk_prefab_catalog_empty')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ChunkPrefabCatalogBrowser>(
              find.byType(ChunkPrefabCatalogBrowser),
            )
            .selectedPrefabKey,
        'prefab_apple',
      );
    },
  );
}

final List<AtlasSliceDef> _slices = <AtlasSliceDef>[
  for (final id in <String>[
    'apple_slice',
    'dark_rock_slice',
    'light_rock_slice',
    'platform_slice',
  ])
    AtlasSliceDef(
      id: id,
      sourceImagePath: 'assets/images/$id.png',
      x: 0,
      y: 0,
      width: 32,
      height: 32,
      tags: const <String>[],
    ),
];

final List<PrefabV3Def> _prefabs = <PrefabV3Def>[
  _prefab(
    key: 'prefab_apple',
    id: 'apple',
    sliceId: 'apple_slice',
    kind: PrefabKind.decoration,
    tags: const <String>['food', 'table'],
  ),
  _prefab(
    key: 'prefab_dark_rock',
    id: 'dark_rock',
    sliceId: 'dark_rock_slice',
    kind: PrefabKind.obstacle,
    tags: const <String>['rock', 'dark', 'moss'],
  ),
  _prefab(
    key: 'prefab_light_rock',
    id: 'light_rock',
    sliceId: 'light_rock_slice',
    kind: PrefabKind.obstacle,
    tags: const <String>['rock', 'light'],
  ),
  _prefab(
    key: 'prefab_platform',
    id: 'platform',
    sliceId: 'platform_slice',
    kind: PrefabKind.platform,
    tags: const <String>['grass'],
  ),
];

final Map<String, PrefabV3VisualBounds> _visualBounds =
    <String, PrefabV3VisualBounds>{
      for (final prefab in _prefabs)
        prefab.prefabKey: const PrefabV3VisualBounds(widthPx: 32, heightPx: 32),
    };

PrefabV3Def _prefab({
  required String key,
  required String id,
  required String sliceId,
  required PrefabKind kind,
  required List<String> tags,
}) => PrefabV3Def(
  prefabKey: key,
  id: id,
  revision: 1,
  status: PrefabStatus.active,
  kind: kind,
  visualSource: PrefabVisualSource.atlasSlice(sliceId),
  anchorXPx: 16,
  anchorYPx: 16,
  collisionShapes: const [],
  tags: tags,
);
