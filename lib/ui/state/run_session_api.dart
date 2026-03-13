import 'package:runner_core/levels/level_id.dart';
import 'package:run_protocol/run_mode.dart';
import 'package:run_protocol/run_ticket.dart';

import 'run_start_remote_exception.dart';

abstract class RunSessionApi {
  Future<RunTicket> createRunSession({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  });
}

class NoopRunSessionApi implements RunSessionApi {
  const NoopRunSessionApi();

  @override
  Future<RunTicket> createRunSession({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  }) {
    throw const RunStartRemoteException(
      code: 'unimplemented',
      message: 'Run session API is not configured for this environment.',
    );
  }
}
