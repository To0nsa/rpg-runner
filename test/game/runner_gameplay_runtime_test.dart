import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:rpg_runner/game/runner_gameplay_runtime.dart';

import '../support/test_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('never-mounted graph owns one cache and releases it exactly once', () {
    final images = _Images();
    final runtime = RunnerGameplayRuntime(
      core: GameCore(
        seed: 1,
        levelDefinition: testFieldLevel(),
        playerCharacter: PlayerCharacterRegistry.eloise,
      ),
      createImages: () => images,
    );
    expect(runtime.controller.tick, 0);
    expect(runtime.controller.snapshot.paused, isTrue);
    runtime.stop();
    expect(images.clears, 0);
    runtime.dispose();
    runtime.dispose();
    expect(images.clears, 1);
  });
  test('cache construction failure propagates without a partial runtime', () {
    expect(
      () => RunnerGameplayRuntime(
        core: GameCore(
          seed: 1,
          levelDefinition: testFieldLevel(),
          playerCharacter: PlayerCharacterRegistry.eloise,
        ),
        createImages: () => throw StateError('cache unavailable'),
      ),
      throwsStateError,
    );
  });
}

class _Images extends Images {
  int clears = 0;
  @override
  void clearCache() {
    clears++;
    super.clearCache();
  }
}
