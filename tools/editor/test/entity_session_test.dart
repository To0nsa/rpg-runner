import 'package:flutter_test/flutter_test.dart';

import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/entities/entity_domain_models.dart';

import 'test_support/entity_test_support.dart';

void main() {
  test(
    'session controller loads parsed collider scene from workspace',
    () async {
      final controller = buildEntitiesController();

      await controller.loadWorkspace();

      expect(controller.loadError, isNull);
      expect(controller.scene, isA<EntityScene>());

      final entries = (controller.scene! as EntityScene).entries;
      final ids = entries.map((entry) => entry.id).join(', ');
      final enemyCount = entries
          .where((entry) => entry.entityType == EntityType.enemy)
          .length;
      final playerCount = entries
          .where((entry) => entry.entityType == EntityType.player)
          .length;
      final projectileCount = entries
          .where((entry) => entry.entityType == EntityType.projectile)
          .length;
      final issueSummary = controller.issues
          .map((issue) => '${issue.code}:${issue.sourcePath}')
          .join(' | ');
      expect(entries, isNotEmpty);
      expect(
        entries.any((entry) => entry.entityType == EntityType.enemy),
        isTrue,
        reason:
            'ids=[$ids], counts(enemy=$enemyCount, player=$playerCount, '
            'projectile=$projectileCount), issues=[$issueSummary]',
      );
      expect(
        entries.any((entry) => entry.entityType == EntityType.player),
        isTrue,
        reason:
            'ids=[$ids], counts(enemy=$enemyCount, player=$playerCount, '
            'projectile=$projectileCount), issues=[$issueSummary]',
      );
      expect(
        entries.any((entry) => entry.entityType == EntityType.projectile),
        isTrue,
      );
      final entriesWithAnimKeys = entries
          .where(
            (entry) => (entry.referenceVisual?.animViewsByKey.length ?? 0) > 1,
          )
          .length;
      expect(
        entriesWithAnimKeys,
        greaterThan(0),
        reason: 'Expected parsed render metadata to include anim-key variants.',
      );
      final playerEloise = entries.firstWhere(
        (entry) => entry.id == 'player.eloise',
      );
      expect(playerEloise.referenceVisual, isNotNull);
      expect(playerEloise.referenceVisual!.renderScale, closeTo(0.75, 0.0001));
      expect(playerEloise.artFacingDirection, EntityArtFacingDirection.right);
      expect(playerEloise.isCaster, isTrue);
      expect(playerEloise.castOriginOffset, closeTo(30.0, 0.0001));
      expect(playerEloise.castOriginOffsetBinding, isNotNull);

      final enemyUnoco = entries.firstWhere(
        (entry) => entry.id == 'enemy.unocoDemon',
      );
      expect(enemyUnoco.artFacingDirection, EntityArtFacingDirection.left);
      expect(enemyUnoco.isCaster, isTrue);
      expect(enemyUnoco.castOriginOffset, closeTo(20.0, 0.0001));
      expect(enemyUnoco.castOriginOffsetBinding, isNotNull);
    },
  );

  test('pending changes contain edited castOriginOffset snippet', () async {
    final controller = buildEntitiesController();
    await controller.loadWorkspace();

    final player = (controller.scene! as EntityScene).entries.firstWhere(
      (entry) =>
          entry.id == 'player.eloise' && entry.castOriginOffsetBinding != null,
    );
    final baselineCastOriginOffset = player.castOriginOffset;
    expect(baselineCastOriginOffset, isNotNull);

    controller.applyCommand(
      AuthoringCommand(
        kind: 'update_entry',
        payload: {
          'id': player.id,
          'halfX': player.halfX,
          'halfY': player.halfY,
          'offsetX': player.offsetX,
          'offsetY': player.offsetY,
          'castOriginOffset': baselineCastOriginOffset! + 5.0,
        },
      ),
    );

    final pendingFileDiffs = controller.pendingChanges.fileDiffs;
    expect(pendingFileDiffs, isNotEmpty);
    final combinedDiff = pendingFileDiffs
        .map((fileDiff) => fileDiff.unifiedDiff)
        .join('\n');
    expect(combinedDiff, contains('castOriginOffset'));
    expect(combinedDiff, contains('35.0'));
  });

  test('pending changes contain edited collider snippet', () async {
    final controller = buildEntitiesController();
    await controller.loadWorkspace();

    final entry = (controller.scene! as EntityScene).entries.first;
    controller.applyCommand(
      AuthoringCommand(
        kind: 'update_entry',
        payload: {
          'id': entry.id,
          'halfX': entry.halfX + 1.0,
          'halfY': entry.halfY,
          'offsetX': entry.offsetX,
          'offsetY': entry.offsetY,
        },
      ),
    );

    final pending = controller.pendingChanges;
    expect(pending.changedItemIds, contains(entry.id));
    expect(pending.changedItemIds.length, 1);
    expect(pending.fileDiffs, isNotEmpty);
    final combinedDiff = pending.fileDiffs
        .map((fileDiff) => fileDiff.unifiedDiff)
        .join('\n');
    expect(combinedDiff, contains('diff --git a/'));
    expect(combinedDiff, contains('@@ -'));
  });

  test(
    'session controller supports undo and redo for collider edits',
    () async {
      final controller = buildEntitiesController();
      await controller.loadWorkspace();

      final enemy = (controller.scene! as EntityScene).entries.firstWhere(
        (entry) => entry.id.startsWith('enemy.'),
      );
      final originalHalfX = enemy.halfX;

      controller.applyCommand(
        AuthoringCommand(
          kind: 'update_entry',
          payload: {
            'id': enemy.id,
            'halfX': originalHalfX + 2.0,
            'halfY': enemy.halfY,
            'offsetX': enemy.offsetX,
            'offsetY': enemy.offsetY,
          },
        ),
      );

      final edited = (controller.scene! as EntityScene).entries.firstWhere(
        (entry) => entry.id == enemy.id,
      );
      expect(edited.halfX, originalHalfX + 2.0);
      expect(controller.canUndo, isTrue);
      expect(controller.canRedo, isFalse);
      expect(controller.dirtyItemIds, contains(enemy.id));
      expect(controller.pendingChanges.fileDiffs, isNotEmpty);

      controller.undo();

      final undone = (controller.scene! as EntityScene).entries.firstWhere(
        (entry) => entry.id == enemy.id,
      );
      expect(undone.halfX, originalHalfX);
      expect(controller.canRedo, isTrue);
      expect(controller.dirtyItemIds, isNot(contains(enemy.id)));

      controller.redo();

      final redone = (controller.scene! as EntityScene).entries.firstWhere(
        (entry) => entry.id == enemy.id,
      );
      expect(redone.halfX, originalHalfX + 2.0);
      expect(controller.dirtyItemIds, contains(enemy.id));
    },
  );
}
