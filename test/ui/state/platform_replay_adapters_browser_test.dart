@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/replay/run_recorder.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/boards/ghost_replay_cache.dart';
import 'package:rpg_runner/ui/state/developer/developer_profile_store.dart';
import 'package:rpg_runner/ui/state/run/local_replay_artifact_store.dart';
import 'package:rpg_runner/ui/state/run/run_replay_uploader.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('browser adapters construct without touching native APIs', () async {
    expect(createGhostReplayCache(), isA<UnavailableGhostReplayCache>());
    expect(createRunReplayUploader(), isA<RunReplayUploader>());
    await expectLater(
      createLocalReplayArtifactStore().clear(),
      throwsUnsupportedError,
    );
    await expectLater(
      RunRecorder.create(
        header: const RunRecorderHeader(
          runSessionId: 'unsupported',
          tickHz: 60,
          seed: 1,
          levelId: 'field',
          playerCharacterId: 'eloise',
          loadoutSnapshot: {},
        ),
      ),
      throwsUnsupportedError,
    );
  });

  test(
    'local profile bootstraps without allocating a filesystem cache',
    () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState.developer(
        store: SharedPrefsDeveloperProfileStore(),
      );
      addTearDown(state.dispose);
      await state.bootstrap();
      expect(state.isDeveloperMode, isTrue);
      expect(state.authSession.isAuthenticated, isFalse);
      expect(
        (await state.prepareRunStartDescriptor()).isDeveloperPractice,
        isTrue,
      );
    },
  );
}
