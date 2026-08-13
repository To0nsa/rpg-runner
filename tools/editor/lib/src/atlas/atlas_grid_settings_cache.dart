import 'package:path/path.dart' as p;

import 'atlas_grid.dart';

/// Session-only grid settings keyed by workspace and normalized source path.
final class AtlasGridSettingsCache {
  String? _workspacePath;
  final Map<String, AtlasGridSettings> _settingsBySourcePath =
      <String, AtlasGridSettings>{};

  void ensureWorkspace(String workspacePath) {
    final normalized = _normalize(workspacePath);
    if (_workspacePath == normalized) return;
    _workspacePath = normalized;
    _settingsBySourcePath.clear();
  }

  AtlasGridSettings settingsFor(String sourcePath) =>
      _settingsBySourcePath[_normalize(sourcePath)] ??
      const AtlasGridSettings();

  void setSettings(String sourcePath, AtlasGridSettings settings) {
    _settingsBySourcePath[_normalize(sourcePath)] = settings;
  }

  void clear() => _settingsBySourcePath.clear();

  String _normalize(String rawPath) {
    final normalized = p.normalize(rawPath).replaceAll('\\', '/');
    return p.context.style == p.Style.windows
        ? normalized.toLowerCase()
        : normalized;
  }
}
