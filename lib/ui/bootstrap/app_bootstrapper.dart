import 'package:flutter/foundation.dart';

import '../app/app_services.dart';
import '../state/auth/firebase_auth_api.dart';

enum BootstrapStage { services, playerData }

/// Required-startup outcome with raw diagnostics and player-facing recovery text.
/// Only success permits navigation beyond the loader.
class BootstrapResult {
  const BootstrapResult._({
    required this.ok,
    this.error,
    this.stackTrace,
    this.stage = BootstrapStage.playerData,
  });

  final bool ok;
  final Object? error;
  final StackTrace? stackTrace;
  final BootstrapStage stage;

  static const BootstrapResult success = BootstrapResult._(ok: true);

  factory BootstrapResult.failure(
    Object error,
    StackTrace stackTrace, {
    BootstrapStage stage = BootstrapStage.playerData,
  }) {
    return BootstrapResult._(
      ok: false,
      error: error,
      stackTrace: stackTrace,
      stage: stage,
    );
  }

  bool get _needsSignIn => error is PlayGamesAuthRequiredException;

  String get errorTitle => switch (stage) {
    BootstrapStage.services => 'Unable to start the game',
    BootstrapStage.playerData =>
      _needsSignIn
          ? 'Play Games sign-in required'
          : 'Unable to load player data',
  };

  String get errorMessage {
    if (_needsSignIn) return (error as PlayGamesAuthRequiredException).message;
    if (error is UnsupportedError) {
      return 'This platform does not support the services required by the game.';
    }
    return stage == BootstrapStage.services
        ? 'Game services could not start. Check your connection and try again.'
        : 'Your player data could not be loaded. Check your connection and try again.';
  }

  String get retryLabel => _needsSignIn ? 'Retry Play Games sign-in' : 'Retry';
}

/// Initializes services before authenticating and loading player data.
/// Failures retain diagnostics and provide safe, stage-specific UI messages.
class AppBootstrapper {
  const AppBootstrapper();

  Future<BootstrapResult> run(
    AppServices services, {
    required bool force,
  }) async {
    var stage = BootstrapStage.services;
    try {
      final appState = await services.initialize();
      stage = BootstrapStage.playerData;
      await appState.bootstrap(force: force);
      return BootstrapResult.success;
    } catch (error, stackTrace) {
      debugPrint('App bootstrap (${stage.name}) failed: $error\n$stackTrace');
      return BootstrapResult.failure(error, stackTrace, stage: stage);
    }
  }
}
