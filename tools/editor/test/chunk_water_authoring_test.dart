import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/terrain/water_region.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_water_panel.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/chunks/chunk_v2_models.dart';
import 'package:runner_editor/src/chunks/chunk_water_commit.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:terrain_materials/terrain_materials.dart';

import 'test_support/chunk_level_fixture.dart';

void main() {
  test(
    'plugin commits water once and includes it in the normal Save diff',
    () async {
      final workspace = await createChunkLevelFixture();
      final chunk = _example().copyWith(levelId: 'forest', waterRegions: []);
      final path =
          'assets/authoring/level/chunks/forest/water_pool_example.json';
      final file = File(workspace.resolve(path));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(ChunkV2FileCodec.encode(chunk));
      final plugin = ChunkDomainPlugin();
      final document = await plugin.loadV2FromRepo(workspace);
      final pool = WaterRegionData(
        id: 'pool',
        x: 128,
        y: 224,
        width: 320,
        height: 64,
        materialKey: 'grass_dirt',
      );
      final commit = ChunkWaterCommit(
        expectedRevision: chunk.revision,
        regions: [pool],
      );
      final command = AuthoringCommand(
        kind: ChunkDomainPlugin.commitChunkWaterCommandKind,
        payload: {'chunkKey': chunk.chunkKey, 'commit': commit},
      );
      final next = plugin.applyEdit(document, command) as ChunkV2Document;
      expect(next.chunks.single.revision, chunk.revision + 1);
      expect(next.chunks.single.waterRegions, [pool]);
      expect(
        plugin.applyEdit(next, command),
        same(next),
        reason: 'Stale edits are rejected.',
      );
      final pending = plugin.describePendingChanges(workspace, document: next);
      expect(pending.fileDiffs.single.unifiedDiff, contains('waterRegions'));
      final encoded = ChunkV2FileCodec.encode(next.chunks.single);
      expect(ChunkV2FileCodec.decode(encoded).waterRegions, [pool]);
      expect(
        next.chunks.single
            .copyWith(chunkKey: 'copy', id: 'copy', revision: 1)
            .waterRegions,
        [pool],
      );
      expect(
        ChunkWaterCommit(
          expectedRevision: next.chunks.single.revision,
          regions: [pool],
        ).apply(next.chunks.single),
        same(next.chunks.single),
      );
    },
  );

  testWidgets(
    'water form validates bounds and returns a typed rectangle edit',
    (tester) async {
      ChunkWaterCommit? commit;
      final material = _materials().byKey['biome_water']!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChunkWaterPanel(
                chunk: _example().copyWith(waterRegions: []),
                materials: TerrainMaterialCatalog(materials: [material]),
                enabled: true,
                onCommit: (value) => commit = value,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('chunk_add_water')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('water_x')), '128');
      await tester.enterText(find.byKey(const ValueKey('water_y')), '224');
      await tester.enterText(find.byKey(const ValueKey('water_width')), '900');
      await tester.enterText(find.byKey(const ValueKey('water_height')), '64');
      await tester.ensureVisible(find.byKey(const ValueKey('water_apply')));
      await tester.tap(find.byKey(const ValueKey('water_apply')));
      await tester.pumpAndSettle();
      expect(find.textContaining('must fit inside'), findsOneWidget);
      expect(commit, isNull);
      await tester.enterText(find.byKey(const ValueKey('water_width')), '320');
      await tester.tap(find.byKey(const ValueKey('water_apply')));
      await tester.pumpAndSettle();
      expect(commit!.regions.single.materialKey, 'biome_water');
      expect(commit!.regions.single.width, 320);
    },
  );
}

ChunkV2FileData _example() => ChunkV2FileCodec.decode(
  File('../../docs/examples/water_pool_chunk.json').readAsStringSync(),
);
TerrainMaterialCatalog _materials() => decodeTerrainMaterialCatalog(
  File('../../assets/authoring/level/terrain_material_defs.json')
      .readAsStringSync(),
).catalog!;
