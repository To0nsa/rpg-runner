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

  /// Keeps player-facing run UI hidden until Flame's initial world is ready.
  bool get showLoadingOverlay => !runLoaded;

  bool get showReadyOverlay => !started && runLoaded;

  bool get showPauseOverlay => started && paused && !gameOver;
}
