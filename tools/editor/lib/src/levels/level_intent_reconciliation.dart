import 'dart:convert';

import '../domain/authoring_intent_reconciliation.dart';
import '../domain/authoring_types.dart';
import '../parallax/parallax_domain_models.dart';
import 'level_domain_models.dart';

/// Replays only Level-owned values and pending theme creation. The current
/// plugin remains responsible for references, ordinals, revision bumps and Save
/// admission. Loaded Chunk/Parallax data never comes from the recovery copy;
/// a never-persisted theme retains the immutable layers originally copied into it.
AuthoringReapplyPlan planLevelIntentReapply({
  required LevelDefsDocument current,
  required LevelDefsDocument original,
  required Map<String, AuthoringConflictChoice> resolutions,
}) {
  if (current.workspaceRootPath != original.workspaceRootPath) {
    throw StateError('Cannot reapply edits into a different workspace.');
  }
  final merger = AuthoringIntentMerger(resolutions);
  final commands = <AuthoringCommand>[];
  final currentThemes = {
    for (final theme in current.parallaxDocument?.themes ?? [])
      theme.parallaxThemeId,
  };
  final originalPersistedThemes = {
    for (final theme in original.parallaxDocument?.baselineThemes ?? [])
      theme.parallaxThemeId,
  };
  final usedOrdinals = {for (final level in current.levels) level.enumOrdinal};
  final recreatedThemes = <String>{};
  for (final intended in original.levels) {
    final id = intended.levelId;
    final baseline = findLevelDefById(original.baselineLevels, id);
    final saved = findLevelDefById(current.levels, id);
    if (baseline != null &&
        levelDefEquals(baseline, intended, ignoreRevision: true)) {
      continue;
    }
    if (baseline != null && saved == null) {
      merger.conflict(
        'Level $id / removed identity',
        null,
        _content(intended),
        canUseIntended: false,
      );
      continue;
    }
    if (baseline == null && saved != null) {
      merger.conflict(
        'Level $id / identity already created',
        _content(saved),
        _content(intended),
        canUseIntended: false,
      );
      continue;
    }
    if (baseline == null && usedOrdinals.contains(intended.enumOrdinal)) {
      merger.conflict(
        'Level $id / ordinal already allocated',
        intended.enumOrdinal,
        _content(intended),
        canUseIntended: false,
      );
      continue;
    }
    final merged = merger.merge(
      'Level $id',
      baseline == null ? null : _content(baseline),
      saved == null ? null : _content(saved),
      _content(intended),
    ) as Map<String, Object?>;
    // Persisted identity slots cannot be changed by a field conflict resolution.
    merged['enumOrdinal'] = saved?.enumOrdinal ?? intended.enumOrdinal;
    final themeId = merged['visualThemeId']! as String;
    final intendedTheme = findParallaxThemeById(
      original.parallaxDocument?.themes ?? const <ParallaxThemeDef>[],
      themeId,
    );
    final ownsPendingTheme =
        !originalPersistedThemes.contains(themeId) &&
        original.sessionCreatedParallaxThemeIds.contains(themeId);
    if (ownsPendingTheme &&
        currentThemes.contains(themeId) &&
        !recreatedThemes.contains(themeId)) {
      merger.conflict(
        'Background $themeId / identity already created',
        findParallaxThemeById(
          current.parallaxDocument?.themes ?? const <ParallaxThemeDef>[],
          themeId,
        )?.toJson(),
        intendedTheme?.toJson(),
        canUseIntended: false,
      );
    }
    final createsTheme = !currentThemes.contains(themeId) && ownsPendingTheme;
    if (saved == null) {
      commands.add(
        AuthoringCommand(
          kind: 'create_level',
          payload: {
            ...merged,
            'levelId': id,
            'themeMode': createsTheme ? 'create' : 'existing',
            if (createsTheme) 'createdThemeSnapshot': intendedTheme,
          },
        ),
      );
      usedOrdinals.add(intended.enumOrdinal);
    } else if (createsTheme) {
      commands.add(
        AuthoringCommand(
          kind: 'create_and_assign_theme',
          payload: {
            'levelId': id,
            'visualThemeId': themeId,
            'createdThemeSnapshot': intendedTheme,
          },
        ),
      );
    }
    if (createsTheme) {
      currentThemes.add(themeId);
      recreatedThemes.add(themeId);
    }
    commands.add(
      AuthoringCommand(
        kind: 'update_level',
        payload: {...merged, 'levelId': id},
      ),
    );
  }
  return AuthoringReapplyPlan(
    commands: List.unmodifiable(commands),
    conflicts: List.unmodifiable(merger.conflicts),
    unresolvedPaths: Set.unmodifiable(merger.unresolvedPaths),
  );
}

Map<String, Object?> _content(LevelDef level) {
  final source =
      jsonDecode(renderCanonicalLevelDefsJson([level])) as Map<String, dynamic>;
  return Map<String, Object?>.from((source['levels'] as List).single as Map)
    ..remove('revision')
    ..putIfAbsent('assembly', () => null);
}
