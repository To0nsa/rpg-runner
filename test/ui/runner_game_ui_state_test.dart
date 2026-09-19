import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/runner_game_ui_state.dart';

void main() {
  test('loading state suppresses run overlays until the world is ready', () {
    const loading = RunnerGameUiState(
      started: false,
      paused: true,
      gameOver: false,
      runLoaded: false,
    );

    expect(loading.showLoadingOverlay, isTrue);
    expect(loading.showReadyOverlay, isFalse);

    const ready = RunnerGameUiState(
      started: false,
      paused: true,
      gameOver: false,
      runLoaded: true,
    );

    expect(ready.showLoadingOverlay, isFalse);
    expect(ready.showReadyOverlay, isTrue);
  });
}
