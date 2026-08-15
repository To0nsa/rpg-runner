import 'package:flutter_test/flutter_test.dart';

import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/entities/entity_change_policy.dart';
import 'package:runner_editor/src/entities/entity_document_pipeline.dart';
import 'package:runner_editor/src/entities/entity_domain_models.dart';
import 'package:runner_editor/src/entities/entity_update.dart';

const _binding = EntitySourceBinding(
  kind: EntitySourceBindingKind.colliderScalar,
  sourcePath: 'lib/src/entity.dart',
  startOffset: 0,
  endOffset: 4,
  sourceSnippet: '24.0',
);

const _colliderBindings = EntityColliderSourceBindings(
  halfX: EntityColliderScalarBinding(sourceBinding: _binding),
  halfY: EntityColliderScalarBinding(sourceBinding: _binding),
  offsetX: EntityColliderScalarBinding(sourceBinding: _binding),
  offsetY: EntityColliderScalarBinding(sourceBinding: _binding),
);

const _entry = EntityEntry(
  id: 'player.eloise',
  label: 'Player: Eloise',
  entityType: EntityType.player,
  halfX: 11,
  halfY: 23,
  offsetX: 0,
  offsetY: 0,
  sourcePath: 'lib/src/player.dart',
  colliderBindings: _colliderBindings,
);

EntityDocument _documentFor(EntityEntry entry) => EntityDocument(
  entries: <EntityEntry>[entry],
  baselineById: const <String, EntityEntry>{'player.eloise': _entry},
  runtimeGridCellSize: 64,
);

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
      colliderBindings: _colliderBindings,
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
      colliderBindings: _colliderBindings,
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

  test('malformed known command payload is rejected atomically', () {
    final document = _documentFor(_entry);
    final malformed = AuthoringCommand(
      kind: EntityUpdate.commandKind,
      payload: <String, Object?>{
        'update': <String, Object?>{'halfX': 12.0, 'halfY': 'invalid'},
      },
    );

    expect(
      () => EntityDocumentPipeline().applyEdit(document, malformed),
      throwsArgumentError,
    );
    expect(document.entries.single, same(_entry));
  });

  test('typed update rejects an unknown target and non-finite value', () {
    final pipeline = EntityDocumentPipeline();
    final document = _documentFor(_entry);
    final unknownTarget = const EntityUpdate(
      entryId: 'player.missing',
      halfX: 11,
      halfY: 23,
      offsetX: 0,
      offsetY: 0,
    ).toCommand();
    final nonFinite = const EntityUpdate(
      entryId: 'player.eloise',
      halfX: double.nan,
      halfY: 23,
      offsetX: 0,
      offsetY: 0,
    ).toCommand();

    expect(
      () => pipeline.applyEdit(document, unknownTarget),
      throwsArgumentError,
    );
    expect(() => pipeline.applyEdit(document, nonFinite), throwsArgumentError);
    expect(document.entries.single, same(_entry));
  });

  test('typed update rejects a mixed-validity anchor pair', () {
    final document = _documentFor(_entry);
    final update = const EntityUpdate(
      entryId: 'player.eloise',
      halfX: 12,
      halfY: 23,
      offsetX: 0,
      offsetY: 0,
      anchorXPx: 5,
    ).toCommand();

    expect(
      () => EntityDocumentPipeline().applyEdit(document, update),
      throwsArgumentError,
    );
    expect(document.entries.single, same(_entry));
  });

  test('one numeric policy controls no-op history and dirty detection', () {
    final pipeline = EntityDocumentPipeline();
    final document = _documentFor(_entry);
    final belowTolerance = EntityUpdate(
      entryId: _entry.id,
      halfX: _entry.halfX + EntityNumericPolicy.tolerance * 0.5,
      halfY: _entry.halfY,
      offsetX: _entry.offsetX,
      offsetY: _entry.offsetY,
    ).toCommand();
    final aboveTolerance = EntityUpdate(
      entryId: _entry.id,
      halfX: _entry.halfX + EntityNumericPolicy.tolerance * 2,
      halfY: _entry.halfY,
      offsetX: _entry.offsetX,
      offsetY: _entry.offsetY,
    ).toCommand();

    expect(pipeline.applyEdit(document, belowTolerance), same(document));
    final changed = pipeline.applyEdit(document, aboveTolerance);
    expect(changed, isNot(same(document)));
    expect(pipeline.changedEntries(changed), hasLength(1));
    expect(
      pipeline.changeSet(changed.entries.single, _entry).halfXChanged,
      isTrue,
    );
  });
}
