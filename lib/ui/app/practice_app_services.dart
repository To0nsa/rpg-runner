import '../state/developer/developer_profile_store.dart';
import '../state/settings/control_settings.dart';
import 'app_services.dart';

/// Browser builds always use local Practice, including optimized hosting builds.
AppServices createAppServices() => AppServices.practiceOnly(
  developerProfileStore: SharedPrefsDeveloperProfileStore(),
  controlSettingsStore: SharedPrefsControlSettingsStore(),
);
