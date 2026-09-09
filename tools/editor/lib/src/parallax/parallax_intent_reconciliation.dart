import '../domain/authoring_intent_reconciliation.dart';
import '../domain/authoring_types.dart';
import 'parallax_domain_models.dart';

/// Reapplies only changed layers onto current themes and current Level mappings.
AuthoringReapplyPlan planParallaxIntentReapply({
  required ParallaxDefsDocument current,
  required ParallaxDefsDocument original,
  required Map<String, AuthoringConflictChoice> resolutions,
}) {
  if (current.workspaceRootPath != original.workspaceRootPath) {
    throw StateError('Cannot reapply a background in another workspace.');
  }
  final merger = AuthoringIntentMerger(resolutions);
  final commands = <AuthoringCommand>[];
  for (final intended in original.themes) {
    final baseline = findParallaxThemeById(
      original.baselineThemes,
      intended.parallaxThemeId,
    );
    final saved = findParallaxThemeById(
      current.themes,
      intended.parallaxThemeId,
    );
    final before = {
      for (final layer in baseline?.layers ?? <ParallaxLayerDef>[])
        layer.layerKey: layer.toJson(),
    };
    final after = {
      for (final layer in intended.layers) layer.layerKey: layer.toJson(),
    };
    final disk = {
      for (final layer in saved?.layers ?? <ParallaxLayerDef>[])
        layer.layerKey: layer.toJson(),
    };
    final levelId = current.parallaxThemeIdByLevelId.entries
        .where((entry) => entry.value == intended.parallaxThemeId)
        .firstOrNull
        ?.key;
    if (saved == null || levelId == null) {
      merger.conflict(
        'Background ${intended.parallaxThemeId} / unavailable',
        saved?.toJson(),
        intended.toJson(),
        canUseIntended: false,
      );
      continue;
    }
    commands.add(
      AuthoringCommand(kind: 'set_active_level', payload: {'levelId': levelId}),
    );
    for (final key in {...before.keys, ...after.keys}) {
      final value = merger.merge(
        'Background ${intended.parallaxThemeId}/$key',
        before[key],
        disk[key],
        after[key],
      );
      if (value == null) {
        if (disk.containsKey(key)) {
          commands.add(
            AuthoringCommand(kind: 'remove_layer', payload: {'layerKey': key}),
          );
        }
      } else {
        commands.add(
          AuthoringCommand(
            kind: disk.containsKey(key) ? 'update_layer' : 'create_layer',
            payload: value as Map<String, Object?>,
          ),
        );
      }
    }
  }
  return AuthoringReapplyPlan(
    commands: List.unmodifiable(commands),
    conflicts: List.unmodifiable(merger.conflicts),
    unresolvedPaths: Set.unmodifiable(merger.unresolvedPaths),
  );
}
