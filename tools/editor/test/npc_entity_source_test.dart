import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_core/npcs/npc_catalog.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_editor/src/entities/entity_domain_models.dart';
import 'package:runner_editor/src/entities/entity_domain_plugin.dart';
import 'package:runner_editor/src/entities/entity_source_parser.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

import 'test_support/entity_test_support.dart';

void main() {
  test(
    'NPC source bindings match runtime and save only the selected archetype',
    () async {
      final root = Directory.systemTemp.createTempSync('npc_entities_');
      addTearDown(() => root.deleteSync(recursive: true));
      writeEntityColliderFixture(root.path);
      final workspace = EditorWorkspace(rootPath: root.path);
      final plugin = EntityDomainPlugin();
      final document = await plugin.loadFromRepo(workspace) as EntityDocument;
      final npcs = document.entries.where(
        (e) => e.entityType == EntityType.npc,
      );
      expect(npcs, hasLength(3));
      for (final id in NpcId.values) {
        final entry = npcs.singleWhere((e) => e.id == 'npc.${id.name}');
        final actual = const NpcCatalog().get(id);
        expect(entry.halfX, actual.collider.halfX);
        expect(entry.halfY, actual.collider.halfY);
        expect(entry.offsetX, actual.collider.offsetX);
        expect(entry.artFacingDirection, EntityArtFacingDirection.right);
        expect(entry.referenceVisual!.renderScale, actual.renderScale);
        expect(
          entry.referenceVisual!.anchorXPx,
          actual.renderAnim.anchorPoint.x,
        );
        expect(entry.castOriginOffsetY, actual.castOriginOffsetY);
      }
      final huntress = npcs.singleWhere((e) => e.id == 'npc.huntress');
      final edited = plugin.applyEdit(
        document,
        buildEntityUpdateCommand(
          huntress,
          halfX: 14,
          offsetX: 2,
          anchorXPx: 76,
          anchorYPx: huntress.referenceVisual!.anchorYPx,
          renderScale: 1.6,
        ),
      );
      final result = await plugin.exportToRepo(workspace, document: edited);
      expect(result.applied, isTrue);
      final reloaded = await plugin.loadFromRepo(workspace) as EntityDocument;
      final next = reloaded.entries.singleWhere((e) => e.id == huntress.id);
      expect(next.halfX, 14);
      expect(next.offsetX, 2);
      expect(next.referenceVisual!.anchorXPx, 76);
      expect(next.referenceVisual!.renderScale, 1.6);
      expect(next.castOriginOffsetY, -31.5);
      expect(
        reloaded.entries.singleWhere((e) => e.id == 'npc.warrior').halfX,
        13.5,
      );
      expect(
        reloaded.entries.singleWhere((e) => e.id == 'npc.huntress2').halfX,
        12,
      );

      final staleEdit = plugin.applyEdit(
        reloaded,
        buildEntityUpdateCommand(next, halfX: 15),
      );
      final source = File(p.join(root.path, EntitySourceParser.npcCatalogPath));
      final drifted = source.readAsStringSync().replaceFirst(
        'halfX: 14',
        'halfX: 16',
      );
      source.writeAsStringSync(drifted);
      final rejected = await plugin.exportToRepo(
        workspace,
        document: staleEdit,
      );
      expect(rejected.applied, isFalse);
      expect(source.readAsStringSync(), drifted);
    },
  );
}
