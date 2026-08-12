import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';

import 'package:rpg_runner/game/components/staged_terrain.dart';
import 'package:rpg_runner/game/game_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('loads and caches the normal streamed terrain snapshot', (
    tester,
  ) async {
    final controller = GameController(
      core: GameCore(
        seed: 42,
        levelDefinition: LevelRegistry.byId(LevelId.field),
        playerCharacter: PlayerCharacterRegistry.eloise,
      ),
    );
    final component = StagedTerrain(
      controller: controller,
      virtualWidth: 480,
      virtualHeight: 270,
    );
    final game = FlameGame(
      camera: CameraComponent.withFixedResolution(width: 480, height: 270),
    );

    addTearDown(controller.dispose);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
    });

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(width: 480, height: 270, child: GameWidget(game: game)),
      ),
    );
    await tester.pump();
    game.camera.backdrop.add(component);
    await tester.pump();
    await tester.runAsync(() => component.loaded);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(controller.snapshot.stagedTerrainRenderSnapshot, isNotNull);
    expect(component.debugAssetsReady, isTrue);
    expect(component.debugGeometryVersion, 1);
    expect(component.debugMeshCount, greaterThan(0));
    expect(component.debugSurfaceEdgeCount, greaterThan(0));
  });
}
