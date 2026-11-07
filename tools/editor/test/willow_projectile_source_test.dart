import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/projectiles/projectile_render_catalog.dart';
import 'package:runner_editor/src/entities/entity_domain_models.dart';
import 'package:runner_editor/src/entities/entity_domain_plugin.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

import 'test_support/entity_test_support.dart';

void main() {
  test(
    'Willow projectile art remains readable by the source-backed editor',
    () async {
      final document = await EntityDomainPlugin().loadFromRepo(
        EditorWorkspace(rootPath: resolveEntitiesWorkspacePath()),
      ) as EntityDocument;
      for (final id in [
        ProjectileId.hunterPistol,
        ProjectileId.hunterCrossbow,
        ProjectileId.hunterShotgun,
        ProjectileId.hunterBomb,
      ]) {
        final entry = document.entries.singleWhere(
          (e) => e.id == 'projectile.${id.name}',
        );
        final render = const ProjectileRenderCatalog().get(id);
        expect(entry.referenceVisual, isNotNull, reason: id.name);
        expect(entry.referenceVisual!.frameWidth, render.frameWidth);
        expect(entry.referenceVisual!.frameHeight, render.frameHeight);
        expect(entry.referenceVisual!.anchorXPx, render.anchorPoint.x);
        expect(entry.referenceVisual!.anchorYPx, render.anchorPoint.y);
      }
    },
  );
}
