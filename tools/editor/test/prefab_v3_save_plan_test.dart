import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/prefabs/store/prefab_store.dart';
import 'package:runner_editor/src/prefabs/store/prefab_tile_file_codec.dart';
import 'package:runner_editor/src/prefabs/store/prefab_v3_file_codec.dart';

void main() {
  const store = PrefabStore();

  test(
    'clean current source produces an immutable paired no-op plan',
    () async {
      final fixture = _Fixture.create();
      addTearDown(fixture.dispose);
      final loaded = await store.loadV3Staging(fixture.root.path);
      final plan = store.buildV3StagingSavePlan(
        prefabData: loaded.prefabData,
        tileData: loaded.tileData,
        prefabBaselineContents: fixture.prefabFile.readAsStringSync(),
        tileBaselineContents: fixture.tileFile.readAsStringSync(),
      );

      expect(plan.hasChanges, isFalse);
      expect(plan.files.map((file) => file.relativePath), <String>[
        PrefabStore.prefabDefsPath,
        PrefabStore.tileDefsPath,
      ]);
      final before = fixture.snapshot();
      store.applyV3StagingSavePlan(fixture.root.path, plan: plan);
      expect(fixture.snapshot(), before);
    },
  );

  test('paired changes apply atomically and reload byte-identically', () async {
    final fixture = _Fixture.create();
    addTearDown(fixture.dispose);
    final loaded = await store.loadV3Staging(fixture.root.path);
    final prefab = loaded.prefabData.prefabs.single;
    final module = loaded.tileData.platformModules.single;
    final nextPrefabData = loaded.prefabData.copyWith(
      prefabs: <PrefabV3Def>[
        prefab.copyWith(revision: prefab.revision + 1, tags: const ['edited']),
      ],
    );
    final nextTileData = loaded.tileData.copyWith(
      platformModules: <TileModuleDef>[
        module.copyWith(
          revision: module.revision + 1,
          status: TileModuleStatus.deprecated,
        ),
      ],
    );
    final plan = store.buildV3StagingSavePlan(
      prefabData: nextPrefabData,
      tileData: nextTileData,
      prefabBaselineContents: fixture.prefabFile.readAsStringSync(),
      tileBaselineContents: fixture.tileFile.readAsStringSync(),
    );

    expect(plan.files.where((file) => file.hasChanges), hasLength(2));
    store.applyV3StagingSavePlan(fixture.root.path, plan: plan);

    expect(
      fixture.prefabFile.readAsStringSync(),
      PrefabV3FileCodec.encode(nextPrefabData),
    );
    expect(
      fixture.tileFile.readAsStringSync(),
      PrefabTileFileCodec.encode(nextTileData),
    );
    final reloaded = await store.loadV3Staging(fixture.root.path);
    expect(
      PrefabV3FileCodec.encode(reloaded.prefabData),
      PrefabV3FileCodec.encode(nextPrefabData),
    );
    expect(
      PrefabTileFileCodec.encode(reloaded.tileData),
      PrefabTileFileCodec.encode(nextTileData),
    );
    final noOp = store.buildV3StagingSavePlan(
      prefabData: reloaded.prefabData,
      tileData: reloaded.tileData,
      prefabBaselineContents: fixture.prefabFile.readAsStringSync(),
      tileBaselineContents: fixture.tileFile.readAsStringSync(),
    );
    expect(noOp.hasChanges, isFalse);
    expect(fixture.transactionFiles, isEmpty);
  });

  test(
    'tile-only plan preserves prefab bytes and installs one artifact',
    () async {
      final fixture = _Fixture.create();
      addTearDown(fixture.dispose);
      final loaded = await store.loadV3Staging(fixture.root.path);
      final prefabBefore = fixture.prefabFile.readAsBytesSync();
      final module = loaded.tileData.platformModules.single;
      final nextTileData = loaded.tileData.copyWith(
        platformModules: <TileModuleDef>[
          module.copyWith(
            revision: module.revision + 1,
            status: TileModuleStatus.deprecated,
          ),
        ],
      );
      final plan = store.buildV3StagingSavePlan(
        prefabData: loaded.prefabData,
        tileData: nextTileData,
        prefabBaselineContents: fixture.prefabFile.readAsStringSync(),
        tileBaselineContents: fixture.tileFile.readAsStringSync(),
      );

      expect(
        plan.files.where((file) => file.hasChanges).single.relativePath,
        PrefabStore.tileDefsPath,
      );
      store.applyV3StagingSavePlan(fixture.root.path, plan: plan);
      expect(fixture.prefabFile.readAsBytesSync(), prefabBefore);
      expect(
        fixture.tileFile.readAsStringSync(),
        PrefabTileFileCodec.encode(nextTileData),
      );
      expect(fixture.transactionFiles, isEmpty);
    },
  );

  test(
    'source drift rejects before replacement and preserves drifted bytes',
    () async {
      final fixture = _Fixture.create();
      addTearDown(fixture.dispose);
      final loaded = await store.loadV3Staging(fixture.root.path);
      final prefab = loaded.prefabData.prefabs.single;
      final plan = store.buildV3StagingSavePlan(
        prefabData: loaded.prefabData.copyWith(
          prefabs: <PrefabV3Def>[
            prefab.copyWith(revision: prefab.revision + 1),
          ],
        ),
        tileData: loaded.tileData,
        prefabBaselineContents: fixture.prefabFile.readAsStringSync(),
        tileBaselineContents: fixture.tileFile.readAsStringSync(),
      );
      const drift = '{"external":"change"}\n';
      fixture.prefabFile.writeAsStringSync(drift);
      final tileBefore = fixture.tileFile.readAsBytesSync();

      expect(
        () => store.applyV3StagingSavePlan(fixture.root.path, plan: plan),
        throwsA(
          isA<PrefabV3StagingSaveException>().having(
            (error) => error.code,
            'code',
            'prefab_v3_save_source_drift',
          ),
        ),
      );
      expect(fixture.prefabFile.readAsStringSync(), drift);
      expect(fixture.tileFile.readAsBytesSync(), tileBefore);
      expect(fixture.transactionFiles, isEmpty);
    },
  );

  test('missing or non-current baselines and incomplete plans fail closed', () {
    final fixture = _Fixture.create();
    addTearDown(fixture.dispose);

    expect(
      () => store.buildV3StagingSavePlan(
        prefabData: fixture.prefabData,
        tileData: fixture.tileData,
        prefabBaselineContents: null,
        tileBaselineContents: fixture.tileFile.readAsStringSync(),
      ),
      throwsA(
        isA<PrefabV3StagingSaveException>().having(
          (error) => error.code,
          'code',
          'prefab_v3_save_baseline_missing',
        ),
      ),
    );
    expect(
      () => store.buildV3StagingSavePlan(
        prefabData: fixture.prefabData,
        tileData: fixture.tileData,
        prefabBaselineContents: '{"schemaVersion":2}\n',
        tileBaselineContents: fixture.tileFile.readAsStringSync(),
      ),
      throwsA(
        isA<PrefabV3StagingSaveException>().having(
          (error) => error.code,
          'code',
          'prefab_v3_save_baseline_invalid',
        ),
      ),
    );
    final incomplete = PrefabV3StagingSavePlan(<PrefabV3StagingSaveFile>[
      PrefabV3StagingSaveFile(
        relativePath: PrefabStore.prefabDefsPath,
        beforeContents: fixture.prefabFile.readAsStringSync(),
        afterContents: fixture.prefabFile.readAsStringSync(),
      ),
    ]);
    expect(
      () => store.applyV3StagingSavePlan(fixture.root.path, plan: incomplete),
      throwsA(
        isA<PrefabV3StagingSaveException>().having(
          (error) => error.code,
          'code',
          'prefab_v3_save_plan_invalid',
        ),
      ),
    );
    final noncanonical = PrefabV3StagingSavePlan(<PrefabV3StagingSaveFile>[
      PrefabV3StagingSaveFile(
        relativePath: PrefabStore.prefabDefsPath,
        beforeContents: fixture.prefabFile.readAsStringSync(),
        afterContents: fixture.prefabFile
            .readAsStringSync()
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim(),
      ),
      PrefabV3StagingSaveFile(
        relativePath: PrefabStore.tileDefsPath,
        beforeContents: fixture.tileFile.readAsStringSync(),
        afterContents: fixture.tileFile.readAsStringSync(),
      ),
    ]);
    expect(
      () => store.applyV3StagingSavePlan(fixture.root.path, plan: noncanonical),
      throwsA(
        isA<PrefabV3StagingSaveException>().having(
          (error) => error.code,
          'code',
          'prefab_v3_save_plan_output_invalid',
        ),
      ),
    );
  });
}

final class _Fixture {
  _Fixture._({
    required this.root,
    required this.prefabData,
    required this.tileData,
  });

  factory _Fixture.create() {
    final root = Directory.systemTemp.createTempSync('prefab_v3_save_plan_');
    final prefabData = PrefabV3FileData(
      slices: const <AtlasSliceDef>[
        AtlasSliceDef(
          id: 'decoration_slice',
          sourceImagePath: 'assets/images/level/test.png',
          x: 0,
          y: 0,
          width: 16,
          height: 16,
        ),
      ],
      prefabs: <PrefabV3Def>[
        PrefabV3Def(
          prefabKey: 'decoration',
          id: 'decoration',
          revision: 1,
          status: PrefabStatus.active,
          kind: PrefabKind.decoration,
          visualSource: const PrefabVisualSource.atlasSlice('decoration_slice'),
          anchorXPx: 8,
          anchorYPx: 8,
          collisionShapes: const [],
          tags: const [],
        ),
      ],
    );
    final tileData = PrefabTileFileData(
      tileSlices: const <AtlasSliceDef>[
        AtlasSliceDef(
          id: 'tile_a',
          sourceImagePath: 'assets/images/level/test.png',
          x: 16,
          y: 0,
          width: 16,
          height: 16,
        ),
      ],
      platformModules: const <TileModuleDef>[
        TileModuleDef(
          id: 'module_a',
          revision: 1,
          status: TileModuleStatus.active,
          tileSize: 16,
          cells: <TileModuleCellDef>[
            TileModuleCellDef(sliceId: 'tile_a', gridX: 0, gridY: 0),
          ],
        ),
      ],
    );
    final prefabFile = File(p.join(root.path, PrefabStore.prefabDefsPath))
      ..createSync(recursive: true)
      ..writeAsStringSync(PrefabV3FileCodec.encode(prefabData));
    File(p.join(root.path, PrefabStore.tileDefsPath))
      ..createSync(recursive: true)
      ..writeAsStringSync(PrefabTileFileCodec.encode(tileData));
    expect(prefabFile.existsSync(), isTrue);
    return _Fixture._(root: root, prefabData: prefabData, tileData: tileData);
  }

  final Directory root;
  final PrefabV3FileData prefabData;
  final PrefabTileFileData tileData;

  File get prefabFile => File(p.join(root.path, PrefabStore.prefabDefsPath));
  File get tileFile => File(p.join(root.path, PrefabStore.tileDefsPath));

  List<String> get transactionFiles => root
      .listSync(recursive: true)
      .whereType<File>()
      .map((file) => p.basename(file.path))
      .where((name) => name.contains('.authoring-') || name.endsWith('.tmp'))
      .toList(growable: false);

  Map<String, List<int>> snapshot() => <String, List<int>>{
    for (final file
        in root.listSync(recursive: true).whereType<File>().toList()
          ..sort((left, right) => left.path.compareTo(right.path)))
      p.relative(file.path, from: root.path): file.readAsBytesSync(),
  };

  void dispose() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}
