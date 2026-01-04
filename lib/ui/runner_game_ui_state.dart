class RunnerGameUiState {
  const RunnerGameUiState({
    required this.started,
    required this.paused,
    required this.gameOver,
  });

  final bool started;
  final bool paused;
  final bool gameOver;

  bool get canRun => started && !gameOver;

  bool get isRunning => canRun && !paused;

  bool get showReadyOverlay => !started;

  bool get showPauseOverlay => started && paused && !gameOver;
}
