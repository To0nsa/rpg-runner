import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/shared/atlas_grid_controls.dart';
import 'package:runner_editor/src/atlas/atlas_grid.dart';

void main() {
  testWidgets('advanced grid values stay hidden until requested', (
    tester,
  ) async {
    var latest = const AtlasGridSettings();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: AtlasGridControls(
              settings: latest,
              onChanged: (settings) => latest = settings,
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('atlas_grid_cell_width')),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey<String>('atlas_grid_cell_height')),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey<String>('atlas_grid_origin_x')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('atlas_grid_gutter_x')),
      findsNothing,
    );

    final advancedToggle = find.byKey(
      const ValueKey<String>('atlas_grid_advanced_toggle'),
    );
    await tester.tap(advancedToggle);
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('atlas_grid_origin_x')), findsOne);
    expect(find.byKey(const ValueKey<String>('atlas_grid_origin_y')), findsOne);
    expect(find.byKey(const ValueKey<String>('atlas_grid_gutter_x')), findsOne);
    expect(find.byKey(const ValueKey<String>('atlas_grid_gutter_y')), findsOne);

    await tester.enterText(
      find.byKey(const ValueKey<String>('atlas_grid_origin_x')),
      '4',
    );
    expect(latest.originX, 4);

    await tester.tap(advancedToggle);
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('atlas_grid_origin_x')),
      findsNothing,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('atlas_grid_cell_width')),
      '48',
    );
    expect(latest.cellWidth, 48);
    expect(latest.originX, 4);
  });
}
