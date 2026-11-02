import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_runner/ui/assets/ui_asset_lifecycle.dart';
import 'package:rpg_runner/ui/components/enemy_portrait.dart';
import 'package:rpg_runner/ui/pages/selectCharacter/training_opponent_dialog.dart';
import 'package:rpg_runner/ui/theme/ui_theme.dart';
import 'package:runner_core/enemies/enemy_id.dart';

void main() {
  testWidgets('opponents scroll on a small screen with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(568, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final assets = UiAssetLifecycle();
    addTearDown(assets.dispose);
    final enemies = EnemyId.values.where((id) => !id.isArenaOnly).toList();
    await tester.runAsync(() async {
      for (final enemy in enemies) {
        await assets.getEnemyPortrait(enemy);
      }
    });
    EnemyId? chosen;
    var selectionCount = 0;
    await tester.pumpWidget(
      Provider<UiAssetLifecycle>.value(
        value: assets,
        child: MaterialApp(
          theme: createUiTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => TrainingOpponentDialog(
                    enemies: enemies,
                    selectedEnemy: EnemyId.derf,
                    onSelected: (enemy) {
                      chosen = enemy;
                      selectionCount++;
                      Navigator.pop(context);
                    },
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    Future<void> open() async {
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await open();
    final title = tester.getRect(find.text('Training opponent'));
    final close = tester.getRect(find.text('Close'));
    expect(find.text('Close').hitTestable(), findsOneWidget);
    // Reuse actual cached frames, including entries initially below the fold.
    final frames = tester.widgetList<RawImage>(
      find.descendant(
        of: find.byType(EnemyPortrait),
        matching: find.byType(RawImage),
      ),
    );
    expect(frames.length, enemies.length);
    expect(frames.every((frame) => frame.image != null), isTrue);
    final last = find.text(enemies.last.displayName);
    await tester.ensureVisible(last);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Training opponent')), title);
    expect(tester.getRect(find.text('Close')), close);
    expect(last.hitTestable(), findsOneWidget);
    await tester.tap(last);
    await tester.pumpAndSettle();
    expect(chosen, enemies.last);
    expect(selectionCount, 1);

    await open();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(selectionCount, 1);
    await open();
    await tester.ensureVisible(find.text('None'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('None'));
    await tester.pumpAndSettle();
    expect(selectionCount, 2);
    expect(chosen, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
