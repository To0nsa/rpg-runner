class RunnerGameUiState {
  const RunnerGameUiState({
    required this.started,
    required this.paused,
    required this.gameOver,
    required this.runLoaded,
  });

  final bool started;
  final bool paused;
  final bool gameOver;
  final bool runLoaded;

  bool get canRun => started && !gameOver;

  bool get isRunning => canRun && !paused;

  bool get showReadyOverlay => !started && runLoaded;

  bool get showPauseOverlay => started && paused && !gameOver;
}
