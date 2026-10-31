import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../firebase_app_check_bootstrap.dart';
import '../../firebase_options.dart';
import '../../firebase_environment.dart';
import '../../firebase_crash_reporting.dart';
import '../state/app/app_state.dart';
import '../state/inbox/firebase_inbox_api.dart';
import '../state/settings/control_settings.dart';
import '../state/developer/developer_profile_store.dart';
import '../state/auth/firebase_auth_api.dart';
import '../state/boards/firebase_ghost_api.dart';
import '../state/boards/firebase_leaderboard_api.dart';
import '../state/boards/firebase_run_boards_api.dart';
import '../state/ownership/firebase_loadout_ownership_api.dart';
import '../state/ownership/ownership_outbox_store.dart';
import '../state/profile/firebase_account_deletion_api.dart';
import '../state/profile/firebase_user_profile_remote_api.dart';
import '../state/run/firebase_run_session_api.dart';
import '../state/run/firebase_run_completion_source.dart';
import 'app_services.dart';

/// Builds the standalone app's production dependencies without starting I/O.
/// Debug launches with `DEVELOPER_PRACTICE=true` start locally without changing
/// the saved mode. Online clients require Firebase and App Check initialization.
AppServices createAppServices() => AppServices(
  controlSettingsStore: SharedPrefsControlSettingsStore(),
  developerProfileStore: kDebugMode ? SharedPrefsDeveloperProfileStore() : null,
  startInDeveloperMode:
      kDebugMode && const bool.fromEnvironment('DEVELOPER_PRACTICE'),
  initialize: () async {
    // App Check can fail after Firebase succeeds; retry that stage safely.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        // Android selects its registered Firebase app through the build's
        // google-services.json; Dart must not override it with the release ID.
        options: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? null
            : DefaultFirebaseOptions.currentPlatform,
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final environment = FirebaseEnvironment.fromAndroidFlavor(appFlavor);
      environment.verifyProject(Firebase.app().options.projectId);
      await initializeAndroidCrashReporting(environment);
    }
    await activateFirebaseAppCheck();
  },
  createAppState: () {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
    return AppState(
      authApi: FirebaseAuthApi(),
      inboxApi: FirebaseInboxApi(
        source: PluginFirebaseInboxSource(functions: functions),
      ),
      accountDeletionApi: FirebaseAccountDeletionApi(
        source: PluginFirebaseAccountDeletionSource(functions: functions),
      ),
      userProfileRemoteApi: FirebaseUserProfileRemoteApi(
        source: PluginFirebaseUserProfileRemoteSource(functions: functions),
      ),
      loadoutOwnershipApi: FirebaseLoadoutOwnershipApi(
        source: PluginFirebaseLoadoutOwnershipSource(functions: functions),
      ),
      ownershipOutboxStore: SharedPrefsOwnershipOutboxStore(),
      runBoardsApi: FirebaseRunBoardsApi(
        source: PluginFirebaseRunBoardsSource(functions: functions),
      ),
      runSessionApi: FirebaseRunSessionApi(
        source: PluginFirebaseRunSessionSource(functions: functions),
      ),
      runCompletionSource: FirebaseRunCompletionSource(),
      leaderboardApi: FirebaseLeaderboardApi(
        source: PluginFirebaseLeaderboardSource(functions: functions),
      ),
      ghostApi: FirebaseGhostApi(
        source: PluginFirebaseGhostSource(functions: functions),
      ),
    );
  },
);
