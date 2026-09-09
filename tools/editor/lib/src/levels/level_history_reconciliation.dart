import '../domain/authoring_history_revision.dart';
import '../parallax/parallax_domain_models.dart';
import '../parallax/parallax_history_reconciliation.dart';
import 'level_domain_models.dart';

/// Content-only history result consumed by the Level plugin's normal compound
/// candidate builder. Source baselines and dependent documents are never output.
final class LevelHistoryContent {
  const LevelHistoryContent({
    required this.levels,
    required this.themes,
    required this.createdThemeIds,
    required this.hasChanges,
  });

  final List<LevelDef> levels;
  final List<ParallaxThemeDef>? themes;
  final Set<String> createdThemeIds;
  final bool hasChanges;
}

/// Reconciles Level values and Level-owned unsaved theme creation with current
/// persistence. A first save seals new identities without erasing value history.
/// Foreign workspaces and conflicting stable ordinals form a history boundary.
LevelHistoryContent? reconcileLevelHistoryContent({
  required LevelDefsDocument current,
  required LevelDefsDocument historical,
}) {
  if (current.workspaceRootPath != historical.workspaceRootPath) return null;
  final currentById = <String, LevelDef>{
    for (final level in current.levels) level.levelId: level,
  };
  final persistedById = <String, LevelDef>{
    for (final level in current.baselineLevels) level.levelId: level,
  };
  final desiredById = <String, LevelDef>{
    for (final level in historical.levels) level.levelId: level,
  };
  final ids = <String>{...persistedById.keys, ...desiredById.keys}.toList()
    ..sort();
  final levels = <LevelDef>[];
  final ordinals = <int>{};
  for (final id in ids) {
    final desired = desiredById[id];
    final existing = currentById[id];
    final persisted = persistedById[id];
    final LevelDef next;
    if (desired == null) {
      next = existing ?? persisted!;
    } else {
      final value = desired.copyWith(
        enumOrdinal: persisted?.enumOrdinal ?? existing?.enumOrdinal,
      );
      final revision = reconcileAuthoringHistoryRevision(
        currentRevision: existing?.revision,
        persistedRevision: persisted?.revision,
        restoresPersistedContent:
            persisted != null &&
            levelDefEquals(value, persisted, ignoreRevision: true),
        preservesCurrentContent:
            existing != null &&
            levelDefEquals(value, existing, ignoreRevision: true),
      );
      next = value.copyWith(revision: revision).normalized();
    }
    if (!ordinals.add(next.enumOrdinal)) return null;
    levels.add(next);
  }

  final currentParallax = current.parallaxDocument;
  final persistedThemeIds = <String>{
    for (final theme
        in currentParallax?.baselineThemes ?? const <ParallaxThemeDef>[])
      theme.parallaxThemeId,
  };
  final pendingThemeIds = <String>{
    ...current.sessionCreatedParallaxThemeIds,
    ...historical.sessionCreatedParallaxThemeIds,
  }.difference(persistedThemeIds);
  final usedThemeIds = levels.map((level) => level.visualThemeId).toSet();
  final createdThemeIds = historical.sessionCreatedParallaxThemeIds
      .intersection(usedThemeIds)
      .difference(persistedThemeIds);
  final List<ParallaxThemeDef>? themes;
  if (currentParallax == null) {
    if (createdThemeIds.isNotEmpty) return null;
    themes = null;
  } else {
    // Existing theme layers belong to Parallax. Level history can change only
    // themes created within this session, never an older loaded layer snapshot.
    themes = <ParallaxThemeDef>[
      for (final theme in currentParallax.themes)
        if (!pendingThemeIds.contains(theme.parallaxThemeId)) theme,
    ];
    for (final id in createdThemeIds) {
      final desired = findParallaxThemeById(
        historical.parallaxDocument?.themes ?? const <ParallaxThemeDef>[],
        id,
      );
      if (desired == null) return null;
      themes.add(
        reconcileParallaxThemeHistory(
          desired: desired,
          current: findParallaxThemeById(currentParallax.themes, id),
          persisted: null,
        ),
      );
    }
    themes.sort(compareParallaxThemesDeterministic);
  }
  final hasChanges =
      renderCanonicalLevelDefsJson(levels) !=
          renderCanonicalLevelDefsJson(current.levels) ||
      (themes != null &&
          renderCanonicalParallaxDefsJson(themes) !=
              renderCanonicalParallaxDefsJson(currentParallax!.themes));
  return LevelHistoryContent(
    levels: List<LevelDef>.unmodifiable(levels),
    themes: themes == null ? null : List<ParallaxThemeDef>.unmodifiable(themes),
    createdThemeIds: Set<String>.unmodifiable(createdThemeIds),
    hasChanges: hasChanges,
  );
}
