import 'package:flutter/foundation.dart';

enum RunLoadPhase {
  start,
  themeResolved,
  parallaxMounted,
  playerAnimationsLoaded,
  registriesLoaded,
  worldReady,
}

@immutable
class RunLoadState {
  const RunLoadState({required this.phase, required this.progress});

  final RunLoadPhase phase;
  final double progress;

  static const RunLoadState initial = RunLoadState(
    phase: RunLoadPhase.start,
    progress: 0.0,
  );
}
