import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/contracts/render_contract.dart';
import 'package:runner_core/game_core.dart';
import '../support/test_level.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';

void main() {
  test('snapshot exposes typed camera contract', () {
    final core = GameCore(
      seed: 7,
      levelDefinition: LevelRegistry.byId(LevelId.field),
      playerCharacter: testPlayerCharacter,
    );
    final snapshot = core.buildSnapshot();

    expect(snapshot.camera.centerX, closeTo(virtualWidth * 0.5, 1e-9));
    expect(
      snapshot.camera.centerY,
      closeTo(LevelRegistry.byId(LevelId.field).cameraCenterY, 1e-9),
    );
    expect(snapshot.camera.viewWidth, closeTo(virtualWidth.toDouble(), 1e-9));
    expect(snapshot.camera.viewHeight, closeTo(virtualHeight.toDouble(), 1e-9));
  });

  test('typed camera bounds are internally consistent', () {
    final core = GameCore(
      seed: 11,
      levelDefinition: LevelRegistry.byId(LevelId.forest),
      playerCharacter: testPlayerCharacter,
    );
    final snapshot = core.buildSnapshot();
    final camera = snapshot.camera;

    expect(camera.left, closeTo(camera.centerX - camera.viewWidth * 0.5, 1e-9));
    expect(
      camera.right,
      closeTo(camera.centerX + camera.viewWidth * 0.5, 1e-9),
    );
    expect(camera.top, closeTo(camera.centerY - camera.viewHeight * 0.5, 1e-9));
    expect(
      camera.bottom,
      closeTo(camera.centerY + camera.viewHeight * 0.5, 1e-9),
    );
  });
}
