import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:rpg_runner/ui/assets/ui_asset_lifecycle.dart';

void main() {
  testWidgets(
    'every enemy has a nonempty cached idle portrait and purge releases it',
    (tester) async {
      final owner = UiAssetLifecycle();
      addTearDown(owner.dispose);
      await tester.runAsync(() async {
        for (final id in EnemyId.values) {
          final first = owner.getEnemyPortrait(id);
          final concurrent = owner.getEnemyPortrait(id);
          expect(identical(first, concurrent), isTrue);
          final image = await first;
          expect(image.width, greaterThan(0), reason: id.name);
          expect(image.height, greaterThan(0), reason: id.name);
          expect(identical(image, await owner.getEnemyPortrait(id)), isTrue);
        }
        final old = await owner.getEnemyPortrait(EnemyId.grojib);
        owner.purgeAll();
        expect(old.debugDisposed, isTrue);
        expect(
          identical(old, await owner.getEnemyPortrait(EnemyId.grojib)),
          isFalse,
        );
        owner.purgeAll();
        final pending = owner.getEnemyPortrait(EnemyId.shoggoth);
        owner.purgeAll();
        await expectLater(pending, throwsStateError);
        final replacement = await owner.getEnemyPortrait(EnemyId.shoggoth);
        expect(replacement.debugDisposed, isFalse);
      });
    },
  );
}
