import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/enemies/enemy_terrain_profile.dart';
import 'package:runner_editor/src/chunks/chunk_marker_authoring_catalog.dart';

void main() {
  test(
    'enemy marker catalog projects stable Core IDs and preview metadata',
    () {
      expect(chunkMarkerEnemyCatalog.map((entry) => entry.markerId), <String>[
        'derf',
        'grojib',
        'hashash',
        'unocoDemon',
      ]);
      expect(chunkMarkerEnemyIds, <String>[
        'derf',
        'grojib',
        'hashash',
        'unocoDemon',
      ]);

      final unoco = chunkMarkerEnemyCatalogEntryFor('unocoDemon')!;
      expect(unoco.displayName, 'Unoco Demon');
      expect(unoco.motionKind, EnemyTerrainMotionKind.flyingDynamic);
      expect(unoco.roleLabel, 'Flying');
      expect(unoco.previewSourcePath, 'entities/enemies/unoco/flying.png');
      expect(unoco.renderAnim.frameWidth, 81);
      expect(unoco.renderAnim.frameHeight, 71);

      expect(chunkMarkerEnemyCatalogEntryFor('UnocoDemon'), isNull);
    },
  );
}
