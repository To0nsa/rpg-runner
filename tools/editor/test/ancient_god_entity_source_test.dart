import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_editor/src/entities/entity_domain_models.dart';
import 'package:runner_editor/src/entities/entity_domain_plugin.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

import 'test_support/entity_test_support.dart';

void main() {
  test(
    'shared Ancient God visuals retain exact writable source bindings',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'ancient_god_entities_',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      writeEntityColliderFixture(root.path);
      const catalog = 'packages/runner_core/lib/enemies/enemy_catalog.dart';
      const render =
          'packages/runner_core/lib/enemies/ancient_god_render_catalog.dart';
      for (final path in [catalog, render]) {
        final file = File(p.join(root.path, path));
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(
          File(p.join(resolveEntitiesWorkspacePath(), path)).readAsStringSync(),
        );
      }
      final workspace = EditorWorkspace(rootPath: root.path);
      final plugin = EntityDomainPlugin();
      final document = await plugin.loadFromRepo(workspace) as EntityDocument;
      for (final id in [
        EnemyId.voidbornGoddess,
        EnemyId.shoggoth,
        EnemyId.voidcaller,
        EnemyId.shoggothMinion,
        EnemyId.voidTentacle,
      ]) {
        final e = document.entries.singleWhere(
          (e) => e.id == 'enemy.${id.name}',
        );
        final actual = const EnemyCatalog().get(id);
        expect(e.halfX, actual.collider.halfX);
        expect(e.referenceVisual, isNotNull, reason: id.name);
        expect(e.referenceVisual!.renderScale, actual.renderScale);
        expect(e.referenceVisual!.anchorXPx, actual.renderAnim.anchorPoint.x);
        expect(e.referenceVisual!.anchorYPx, actual.renderAnim.anchorPoint.y);
      }
      final goddess = document.entries.singleWhere(
        (e) => e.id == 'enemy.voidbornGoddess',
      );
      final edited = plugin.applyEdit(
        document,
        buildEntityUpdateCommand(
          goddess,
          halfX: 14,
          anchorXPx: 70,
          anchorYPx: 63,
          renderScale: 1.6,
        ),
      );
      final saved = await plugin.exportToRepo(workspace, document: edited);
      expect(saved.applied, isTrue);
      final next = await plugin.loadFromRepo(workspace) as EntityDocument;
      final updated = next.entries.singleWhere((e) => e.id == goddess.id);
      expect(updated.halfX, 14);
      expect(updated.referenceVisual!.anchorXPx, 70);
      expect(updated.referenceVisual!.renderScale, 1.6);
      final shoggoth = next.entries.singleWhere(
        (e) => e.id == 'enemy.shoggoth',
      );
      expect(shoggoth.referenceVisual!.anchorXPx, 79);
      expect(shoggoth.referenceVisual!.renderScale, 1.5);
      expect(
        File(p.join(root.path, render)).readAsStringSync(),
        contains('Vec2(70'),
      );
      final staleEdit = plugin.applyEdit(
        next,
        buildEntityUpdateCommand(
          updated,
          halfX: 15,
          anchorXPx: 71,
          anchorYPx: 63,
        ),
      );
      final source = File(p.join(root.path, render));
      final content = source.readAsStringSync();
      final drifted = content.replaceFirst(
        RegExp(r'Vec2\(70(?:\.0)?,'),
        'Vec2(70.25,',
      );
      expect(drifted, isNot(content));
      source.writeAsStringSync(drifted);
      final enemyBefore = File(p.join(root.path, catalog)).readAsStringSync();
      final rejected = await plugin.exportToRepo(
        workspace,
        document: staleEdit,
      );
      expect(rejected.applied, isFalse);
      expect(File(p.join(root.path, catalog)).readAsStringSync(), enemyBefore);
      expect(source.readAsStringSync(), drifted);
    },
  );
}
