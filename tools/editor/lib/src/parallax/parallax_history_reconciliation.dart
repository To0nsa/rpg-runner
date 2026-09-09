import '../domain/authoring_history_revision.dart';
import 'parallax_domain_models.dart';

/// Restores theme content while retaining current sources, dependencies and
/// selection. Persisted theme identities cannot be removed by older history.
ParallaxDefsDocument? restoreParallaxHistoryContent({
  required ParallaxDefsDocument current,
  required ParallaxDefsDocument historical,
}) {
  if (current.workspaceRootPath != historical.workspaceRootPath) return null;
  final currentById = <String, ParallaxThemeDef>{
    for (final theme in current.themes) theme.parallaxThemeId: theme,
  };
  final persistedById = <String, ParallaxThemeDef>{
    for (final theme in current.baselineThemes) theme.parallaxThemeId: theme,
  };
  final desiredById = <String, ParallaxThemeDef>{
    for (final theme in historical.themes) theme.parallaxThemeId: theme,
  };
  final ids = <String>{...persistedById.keys, ...desiredById.keys}.toList()
    ..sort();
  final themes = <ParallaxThemeDef>[
    for (final id in ids)
      if (desiredById[id] case final desired?)
        reconcileParallaxThemeHistory(
          desired: desired,
          current: currentById[id],
          persisted: persistedById[id],
        )
      else
        currentById[id] ?? persistedById[id]!,
  ];
  if (_sameThemes(current.themes, themes)) return current;
  return current.copyWith(
    themes: List<ParallaxThemeDef>.unmodifiable(themes),
    clearOperationIssues: true,
  );
}

/// Restores one theme's layers without importing its historical revision.
/// Level authoring also uses this for its own unsaved theme-creation entries.
ParallaxThemeDef reconcileParallaxThemeHistory({
  required ParallaxThemeDef desired,
  required ParallaxThemeDef? current,
  required ParallaxThemeDef? persisted,
}) {
  final revision = reconcileAuthoringHistoryRevision(
    currentRevision: current?.revision,
    persistedRevision: persisted?.revision,
    restoresPersistedContent:
        persisted != null &&
        parallaxThemeEquals(desired, persisted, ignoreRevision: true),
    preservesCurrentContent:
        current != null &&
        parallaxThemeEquals(desired, current, ignoreRevision: true),
  );
  if (current != null &&
      revision == current.revision &&
      parallaxThemeEquals(desired, current, ignoreRevision: true)) {
    return current;
  }
  return desired.copyWith(revision: revision).normalized();
}

bool _sameThemes(List<ParallaxThemeDef> left, List<ParallaxThemeDef> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (!parallaxThemeEquals(left[index], right[index])) return false;
  }
  return true;
}
