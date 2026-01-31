import '../state/app_state.dart';

class BootstrapResult {
  const BootstrapResult._({required this.ok, this.error, this.stackTrace});

  final bool ok;
  final Object? error;
  final StackTrace? stackTrace;

  static const BootstrapResult success = BootstrapResult._(ok: true);

  factory BootstrapResult.failure(Object error, StackTrace stackTrace) {
    return BootstrapResult._(ok: false, error: error, stackTrace: stackTrace);
  }
}

class AppBootstrapper {
  const AppBootstrapper();

  Future<BootstrapResult> run(AppState appState, {required bool force}) async {
    try {
      await appState.bootstrap(force: force);
      return BootstrapResult.success;
    } catch (error, stackTrace) {
      return BootstrapResult.failure(error, stackTrace);
    }
  }
}
