import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:runner_editor/src/app/pages/entities/inspector/entity_inspector_panel.dart';
import 'package:runner_editor/src/entities/entity_domain_models.dart';

void main() {
  testWidgets('actor inspector explains upright capsule fields', (
    tester,
  ) async {
    await tester.pumpWidget(_inspector(_entry(EntityType.player)));

    expect(
      find.text('Collider "upright capsule + enclosing AABB"'),
      findsOneWidget,
    );
    expect(
      find.text(
        'halfX is radius; halfY − halfX is the vertical half-spine. '
        'offsetX mirrors with facing.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('projectile inspector explains horizontal capsule fields', (
    tester,
  ) async {
    await tester.pumpWidget(_inspector(_entry(EntityType.projectile)));

    expect(
      find.text('Collider "horizontal capsule + enclosing AABB"'),
      findsOneWidget,
    );
    expect(
      find.text(
        'halfX is the horizontal half-spine; halfY is radius. The scene '
        'shows the canonical horizontal orientation.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('invalid actor capsule is explicit in the inspector', (
    tester,
  ) async {
    await tester.pumpWidget(
      _inspector(_entry(EntityType.enemy).copyWith(halfX: 12, halfY: 10)),
    );

    expect(
      find.text('Invalid capsule dimensions. Actors require halfY ≥ halfX.'),
      findsOneWidget,
    );
  });
}

Widget _inspector(EntityEntry entry) {
  TextEditingController controller(String value) =>
      TextEditingController(text: value);
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: EntityInspectorPanel(
          selectedEntry: entry,
          isDirty: false,
          halfXController: controller('${entry.halfX}'),
          halfYController: controller('${entry.halfY}'),
          offsetXController: controller('${entry.offsetX}'),
          offsetYController: controller('${entry.offsetY}'),
          anchorXPxController: controller(''),
          anchorYPxController: controller(''),
          frameWidthController: controller(''),
          frameHeightController: controller(''),
          renderScaleController: controller(''),
          castOriginOffsetController: controller(''),
          castOriginPreviewAngleDegrees: 0,
          onCastOriginPreviewAngleChanged: (_) {},
          onApply: null,
        ),
      ),
    ),
  );
}

EntityEntry _entry(EntityType type) => EntityEntry(
  id: '${type.name}.test',
  label: '${type.name}: Test',
  entityType: type,
  halfX: type == EntityType.projectile ? 9 : 10,
  halfY: type == EntityType.projectile ? 4 : 20,
  offsetX: 0,
  offsetY: 0,
  sourcePath: 'source.dart',
  sourceBinding: EntitySourceBinding(
    kind: type == EntityType.projectile
        ? EntitySourceBindingKind.projectileArgs
        : EntitySourceBindingKind.playerArgs,
    sourcePath: 'source.dart',
    startOffset: 0,
    endOffset: 10,
    sourceSnippet: 'collider',
  ),
);
