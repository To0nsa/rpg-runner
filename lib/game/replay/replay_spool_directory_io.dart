import 'dart:io';

/// Dedicated native recorder storage; also used for account artifact cleanup.
Directory defaultReplaySpoolDirectory() {
  return Directory(
    '${Directory.systemTemp.path}'
    '${Platform.pathSeparator}rpg_runner'
    '${Platform.pathSeparator}replay_spool',
  );
}
