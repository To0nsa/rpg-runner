import 'package:flutter/foundation.dart';

enum RunLoadPhase {
  start,
  themeResolved,
  parallaxMounted,
  playerAnimationsLoaded,
  registriesLoaded,
  ghostPrepared,
  worldReady,
  failed,
}

@immutable
class RunLoadState {
  const RunLoadState({
    required this.phase,
    required this.progress,
    this.error,
    this.stackTrace,
  });

  final RunLoadPhase phase;
  final double progress;

  /// The original required-load failure, retained for diagnostics.
  final Object? error;
  final StackTrace? stackTrace;

  static const RunLoadState initial = RunLoadState(
    phase: RunLoadPhase.start,
    progress: 0.0,
  );
}
