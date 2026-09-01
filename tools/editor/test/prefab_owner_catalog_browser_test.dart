import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/v3/prefab_owner_catalog_browser.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_models.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';

void main() {
  testWidgets(
    'prefab library searches source and tags, filters, and selects by keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String selectedPrefabKey = 'obstacle';
      String? expandedPrefabKey = 'obstacle';
      var selectionCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: PrefabOwnerCatalogBrowser(
                  prefabs: _prefabs,
                  prefabData: PrefabV3FileData(
                    slices: _slices,
                    prefabs: _prefabs,
                  ),
                  tileData: _tileData,
                  visualBoundsByPrefabKey: _visualBounds,
                  workspaceRootPath: 'missing_workspace',
                  selectedPrefabKey: selectedPrefabKey,
                  expandedPrefabKey: expandedPrefabKey,
                  changedPrefabKeys: const <String>['platform'],
                  downstreamImpacts: <PrefabV3DownstreamImpact>[
                    PrefabV3DownstreamImpact(
                      prefabKey: 'obstacle',
                      referencingChunkKeys: const <String>['forest'],
                      placementCount: 2,
                    ),
                  ],
                  onSelected: (prefab) {
                    selectionCount += 1;
                    setState(() {
                      selectedPrefabKey = prefab.prefabKey;
                      expandedPrefabKey = prefab.prefabKey;
                    });
                  },
                  selectedDetailsBuilder: (context, prefab) =>
                      Text('Inline editor for ${prefab.id}'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 of 3 prefabs'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('prefab_owner_catalog_preview_obstacle'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('prefab_owner_catalog_preview_platform'),
        ),
        findsOneWidget,
      );
      expect(find.text('Inline editor for dark_rock'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey<String>('prefab_owner_catalog_search')),
        'module_a',
      );
      await tester.pump();
      expect(find.text('1 of 3 prefabs'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('prefab_polygon_owner_platform')),
        findsOneWidget,
      );
      expect(selectedPrefabKey, 'obstacle');
      expect(selectionCount, 0);

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(selectedPrefabKey, 'platform');
      expect(selectionCount, 1);
      expect(find.text('Inline editor for grass_platform'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_owner_catalog_clear_search')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('prefab_owner_catalog_kind_obstacle'),
        ),
      );
      await tester.pump();
      expect(find.text('1 of 3 prefabs'), findsOneWidget);
      expect(find.text('dark_rock'), findsWidgets);
      expect(find.text('grass_platform'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_owner_catalog_kind_all')),
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>('prefab_owner_catalog_status_deprecated'),
        ),
      );
      await tester.pump();
      expect(find.text('1 of 3 prefabs'), findsOneWidget);
      expect(find.text('old_statue'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey<String>('prefab_owner_catalog_search')),
        'missing owner',
      );
      await tester.pump();
      expect(find.text('0 of 3 prefabs'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('prefab_owner_catalog_empty')),
        findsOneWidget,
      );
      expect(selectedPrefabKey, 'platform');
    },
  );

  testWidgets('expanded prefab library handles a representative catalog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefabs = <PrefabV3Def>[
      for (var index = 0; index < 180; index += 1)
        PrefabV3Def(
          prefabKey: 'owner_${index.toString().padLeft(3, '0')}',
          id: 'catalog_owner_${index.toString().padLeft(3, '0')}',
          revision: 1,
          status: index.isEven ? PrefabStatus.active : PrefabStatus.deprecated,
          kind: PrefabKind.obstacle,
          visualSource: const PrefabVisualSource.atlasSlice('rock_slice'),
          anchorXPx: 16,
          anchorYPx: 16,
          collisionShapes: const [],
          tags: const <String>['fixture'],
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PrefabOwnerCatalogBrowser(
              prefabs: prefabs,
              prefabData: PrefabV3FileData(slices: _slices, prefabs: prefabs),
              tileData: PrefabTileFileData(
                tileSlices: const <AtlasSliceDef>[],
                platformModules: const <TileModuleDef>[],
              ),
              visualBoundsByPrefabKey: <String, PrefabV3VisualBounds>{
                for (final prefab in prefabs)
                  prefab.prefabKey: const PrefabV3VisualBounds(
                    widthPx: 32,
                    heightPx: 32,
                  ),
              },
              workspaceRootPath: 'missing_workspace',
              selectedPrefabKey: prefabs.first.prefabKey,
              expandedPrefabKey: null,
              changedPrefabKeys: const <String>[],
              downstreamImpacts: const <PrefabV3DownstreamImpact>[],
              onSelected: (_) {},
              selectedDetailsBuilder: (_, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('180 of 180 prefabs'), findsOneWidget);
    final builtPreviewCount = find
        .byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              ((widget.key! as ValueKey<String>).value).startsWith(
                'prefab_owner_catalog_preview_',
              ),
        )
        .evaluate()
        .length;
    expect(builtPreviewCount, greaterThan(0));
    expect(builtPreviewCount, 180);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long prefab metadata remains readable at sidebar width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const sourceId =
        'ancient_forest_ruins_obstacle_source_with_a_long_repository_name';
    const ownerId =
        'ancient_forest_ruins_obstacle_with_a_long_descriptive_owner_id';
    const ownerKey = 'owner_with_a_long_stable_repository_identity_001';
    const slice = AtlasSliceDef(
      id: sourceId,
      sourceImagePath:
          'assets/levels/ancient_forest/props/very_long_missing_source.png',
      x: 0,
      y: 0,
      width: 32,
      height: 32,
    );
    final owner = PrefabV3Def(
      prefabKey: ownerKey,
      id: ownerId,
      revision: 1,
      status: PrefabStatus.deprecated,
      kind: PrefabKind.obstacle,
      visualSource: const PrefabVisualSource.atlasSlice(sourceId),
      anchorXPx: 16,
      anchorYPx: 16,
      collisionShapes: const [],
      tags: const <String>[
        'ancient_forest_ruins',
        'environmental_obstacle',
        'deprecated_reference_fixture',
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: PrefabOwnerCatalogBrowser(
              prefabs: <PrefabV3Def>[owner],
              prefabData: PrefabV3FileData(
                slices: const <AtlasSliceDef>[slice],
                prefabs: <PrefabV3Def>[owner],
              ),
              tileData: PrefabTileFileData(
                tileSlices: <AtlasSliceDef>[],
                platformModules: <TileModuleDef>[],
              ),
              visualBoundsByPrefabKey: const <String, PrefabV3VisualBounds>{
                ownerKey: PrefabV3VisualBounds(widthPx: 32, heightPx: 32),
              },
              workspaceRootPath: 'missing_workspace',
              selectedPrefabKey: ownerKey,
              expandedPrefabKey: null,
              changedPrefabKeys: const <String>[],
              downstreamImpacts: const <PrefabV3DownstreamImpact>[],
              onSelected: (_) {},
              selectedDetailsBuilder: (_, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(ownerId), findsOneWidget);
    expect(find.textContaining(sourceId), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^$ownerId,')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const List<AtlasSliceDef> _slices = <AtlasSliceDef>[
  AtlasSliceDef(
    id: 'rock_slice',
    sourceImagePath: 'assets/rock.png',
    x: 0,
    y: 0,
    width: 32,
    height: 32,
  ),
  AtlasSliceDef(
    id: 'statue_slice',
    sourceImagePath: 'assets/statue.png',
    x: 0,
    y: 0,
    width: 24,
    height: 40,
  ),
];

final PrefabTileFileData _tileData = PrefabTileFileData(
  tileSlices: <AtlasSliceDef>[
    AtlasSliceDef(
      id: 'grass_tile',
      sourceImagePath: 'assets/grass.png',
      x: 0,
      y: 0,
      width: 16,
      height: 16,
    ),
  ],
  platformModules: <TileModuleDef>[
    TileModuleDef(
      id: 'module_a',
      tileSize: 16,
      cells: <TileModuleCellDef>[
        TileModuleCellDef(sliceId: 'grass_tile', gridX: 0, gridY: 0),
        TileModuleCellDef(sliceId: 'grass_tile', gridX: 1, gridY: 0),
      ],
    ),
  ],
);

final List<PrefabV3Def> _prefabs = <PrefabV3Def>[
  PrefabV3Def(
    prefabKey: 'obstacle',
    id: 'dark_rock',
    revision: 1,
    status: PrefabStatus.active,
    kind: PrefabKind.obstacle,
    visualSource: const PrefabVisualSource.atlasSlice('rock_slice'),
    anchorXPx: 16,
    anchorYPx: 16,
    collisionShapes: const [],
    tags: const <String>['rock', 'dark', 'moss'],
  ),
  PrefabV3Def(
    prefabKey: 'platform',
    id: 'grass_platform',
    revision: 2,
    status: PrefabStatus.active,
    kind: PrefabKind.platform,
    visualSource: const PrefabVisualSource.platformModule('module_a'),
    anchorXPx: 16,
    anchorYPx: 8,
    collisionShapes: const [],
    tags: const <String>['grass'],
  ),
  PrefabV3Def(
    prefabKey: 'decoration',
    id: 'old_statue',
    revision: 3,
    status: PrefabStatus.deprecated,
    kind: PrefabKind.decoration,
    visualSource: const PrefabVisualSource.atlasSlice('statue_slice'),
    anchorXPx: 12,
    anchorYPx: 40,
    collisionShapes: const [],
    tags: const <String>['ancient'],
  ),
];

final Map<String, PrefabV3VisualBounds> _visualBounds =
    <String, PrefabV3VisualBounds>{
      for (final prefab in _prefabs)
        prefab.prefabKey: const PrefabV3VisualBounds(widthPx: 32, heightPx: 32),
    };
