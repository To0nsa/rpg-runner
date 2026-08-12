import 'package:flutter_test/flutter_test.dart';

import 'package:runner_editor/src/entities/entity_document_pipeline.dart';
import 'package:runner_editor/src/entities/entity_domain_models.dart';

void main() {
  test('actor halfY smaller than halfX blocks export validation', () {
    const entry = EntityEntry(
      id: 'player.invalid_capsule',
      label: 'Player: Invalid Capsule',
      entityType: EntityType.player,
      halfX: 12,
      halfY: 10,
      offsetX: 0,
      offsetY: 0,
      sourcePath: 'lib/src/player.dart',
      sourceBinding: EntitySourceBinding(
        kind: EntitySourceBindingKind.playerArgs,
        sourcePath: 'lib/src/player.dart',
        startOffset: 0,
        endOffset: 10,
        sourceSnippet: 'colliderWidth: 24',
      ),
    );
    final document = EntityDocument(
      entries: const <EntityEntry>[entry],
      baselineById: const <String, EntityEntry>{
        'player.invalid_capsule': entry,
      },
      runtimeGridCellSize: 64,
    );

    expect(
      EntityDocumentPipeline().validate(document).map((issue) => issue.code),
      contains('invalid_actor_capsule_dimensions'),
    );
  });

  test('projectile half-spine may be longer than its radius', () {
    const entry = EntityEntry(
      id: 'projectile.valid_capsule',
      label: 'Projectile: Valid Capsule',
      entityType: EntityType.projectile,
      halfX: 12,
      halfY: 4,
      offsetX: 0,
      offsetY: 0,
      sourcePath: 'lib/src/projectile.dart',
      sourceBinding: EntitySourceBinding(
        kind: EntitySourceBindingKind.projectileArgs,
        sourcePath: 'lib/src/projectile.dart',
        startOffset: 0,
        endOffset: 10,
        sourceSnippet: 'colliderSizeX: 24',
      ),
    );
    final document = EntityDocument(
      entries: const <EntityEntry>[entry],
      baselineById: const <String, EntityEntry>{
        'projectile.valid_capsule': entry,
      },
      runtimeGridCellSize: 64,
    );

    expect(EntityDocumentPipeline().validate(document), isEmpty);
  });
}
