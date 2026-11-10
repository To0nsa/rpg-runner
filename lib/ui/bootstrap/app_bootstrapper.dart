import 'package:rpg_runner/ui/l10n/app_localization.dart';
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

  String errorTitle(AppLocalizations l10n) => switch (stage) {
    BootstrapStage.services => l10n.bootstrapStartFailed,
    BootstrapStage.playerData => switch (error) {
      GameAccountDisabledException() => l10n.bootstrapAccountUnavailable,
      PlayGamesAuthRequiredException() => l10n.bootstrapSignInRequired,
      _ => l10n.bootstrapDataFailed,
    },
  };

  String errorMessage(AppLocalizations l10n) {
    if (error is GameAccountDisabledException) {
      return l10n.bootstrapAccountDisabled;
    }
    if (_needsSignIn) return l10n.bootstrapSignInBody;
    if (error is UnsupportedError) {
      return l10n.bootstrapUnsupported;
    }
    return stage == BootstrapStage.services
        ? l10n.bootstrapServiceFailure
        : l10n.bootstrapDataFailure;
  }

  String retryLabel(AppLocalizations l10n) => switch (error) {
    GameAccountDisabledException() => l10n.bootstrapRetry,
    PlayGamesAuthRequiredException() => l10n.bootstrapRetrySignIn,
    _ => l10n.uiRetry,
  };
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
