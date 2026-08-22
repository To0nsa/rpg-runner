import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:test/test.dart';

void main() {
  test('enemy catalog owns complete runtime sprite footprint metadata', () {
    const expectedScales = <EnemyId, double>{
      EnemyId.unocoDemon: 0.5,
      EnemyId.grojib: 1.5,
      EnemyId.hashash: 1.5,
      EnemyId.derf: 1.5,
    };
    const catalog = EnemyCatalog();

    for (final id in EnemyId.values) {
      final archetype = catalog.get(id);
      expect(archetype.renderScale, expectedScales[id]);
      expect(archetype.renderScale.isFinite, isTrue);
      expect(archetype.renderScale, greaterThan(0));
      expect(archetype.renderAnim.sourcesByKey[AnimKey.idle], isNotEmpty);
      expect(
        archetype.renderAnim.anchorPoint.x,
        inInclusiveRange(0, archetype.renderAnim.frameWidth),
      );
      expect(
        archetype.renderAnim.anchorPoint.y,
        inInclusiveRange(0, archetype.renderAnim.frameHeight),
      );
    }
  });
}
