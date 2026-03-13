import 'package:runner_core/levels/level_id.dart';
import 'package:run_protocol/board_manifest.dart';
import 'package:run_protocol/run_mode.dart';

import 'run_start_remote_exception.dart';

abstract class RunBoardsApi {
  Future<BoardManifest> loadActiveBoard({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  });
}

class NoopRunBoardsApi implements RunBoardsApi {
  const NoopRunBoardsApi();

  @override
  Future<BoardManifest> loadActiveBoard({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  }) {
    throw const RunStartRemoteException(
      code: 'unimplemented',
      message: 'Run boards API is not configured for this environment.',
    );
  }
}
