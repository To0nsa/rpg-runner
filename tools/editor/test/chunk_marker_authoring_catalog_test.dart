import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/enemies/enemy_terrain_profile.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
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
      expect(unoco.renderScale, 0.5);
      final derf = chunkMarkerEnemyCatalogEntryFor('derf')!;
      expect(derf.motionKind, EnemyTerrainMotionKind.groundedDynamic);
      expect(derf.previewSourcePath, 'entities/enemies/derf/caster_sheet.png');
      expect(derf.previewRow, 0);
      expect(derf.renderAnim.frameWidth, 91);

      expect(
        chunkMarkerDefaultPlacementFor('derf'),
        markerPlacementObstacleTop,
      );
      for (final markerId in <String>['grojib', 'hashash', 'unocoDemon']) {
        expect(chunkMarkerDefaultPlacementFor(markerId), markerPlacementGround);
      }

      expect(chunkMarkerEnemyCatalogEntryFor('UnocoDemon'), isNull);
      expect(chunkMarkerDefaultPlacementFor('unknown'), markerPlacementGround);
      for (final id in EnemyId.values.where((id) => id.isArenaOnly)) {
        expect(chunkMarkerEnemyCatalogEntryFor(id.name), isNull);
      }
    },
  );
}
