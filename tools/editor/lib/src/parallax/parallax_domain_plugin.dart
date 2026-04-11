import '../domain/authoring_types.dart';
import '../workspace/editor_workspace.dart';
import 'parallax_domain_models.dart';
import 'parallax_store.dart';
import 'parallax_validation.dart';

class ParallaxDomainPlugin implements AuthoringDomainPlugin {
  ParallaxDomainPlugin({ParallaxStore store = const ParallaxStore()})
    : _store = store;

  static const String pluginId = 'parallax';

  final ParallaxStore _store;
  String? _preferredActiveLevelId;

  @override
  String get id => pluginId;

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    final loaded = await _store.load(
      workspace,
      preferredActiveLevelId: _preferredActiveLevelId,
    );
    _preferredActiveLevelId = loaded.activeLevelId;
    return loaded;
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    return validateParallaxDocument(_asParallaxDocument(document));
  }

  @override
  EditableScene buildEditableScene(AuthoringDocument document) {
    final parallaxDocument = _asParallaxDocument(document);
    final activeThemeId = resolveActiveThemeId(parallaxDocument);
    final activeTheme = findParallaxThemeById(
      parallaxDocument.themes,
      activeThemeId,
    );
    return ParallaxScene(
      themes: parallaxDocument.themes,
      availableLevelIds: parallaxDocument.availableLevelIds,
      activeLevelId: parallaxDocument.activeLevelId,
      levelOptionSource: parallaxDocument.levelOptionSource,
      themeIdByLevelId: parallaxDocument.themeIdByLevelId,
      activeThemeId: activeThemeId,
      activeTheme: activeTheme,
      activeThemeUsageLevelIds: levelIdsUsingThemeId(
        parallaxDocument.themeIdByLevelId,
        activeThemeId,
      ),
      sourcePath:
          parallaxDocument.baseline?.sourcePath ?? ParallaxStore.defsPath,
      workspaceRootPath: parallaxDocument.workspaceRootPath,
    );
  }

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) {
    final parallaxDocument = _asParallaxDocument(document);
    switch (command.kind) {
      case 'set_active_level':
        return _setActiveLevel(parallaxDocument, command.payload);
      case 'ensure_active_theme':
        return _ensureActiveTheme(parallaxDocument, command.payload);
      case 'update_ground_material_asset_path':
        return _updateGroundMaterialAssetPath(parallaxDocument, command.payload);
      case 'create_layer':
        return _createLayer(parallaxDocument, command.payload);
      case 'duplicate_layer':
        return _duplicateLayer(parallaxDocument, command.payload);
      case 'remove_layer':
        return _removeLayer(parallaxDocument, command.payload);
      case 'update_layer':
        return _updateLayer(parallaxDocument, command.payload);
      case 'reorder_layer':
        return _reorderLayer(parallaxDocument, command.payload);
      default:
        return _clearOperationIssuesIfNeeded(parallaxDocument);
    }
  }

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) async {
    final parallaxDocument = _asParallaxDocument(document);
    final blockingIssues = validateParallaxDocument(
      parallaxDocument,
    ).where((issue) => issue.severity == ValidationSeverity.error).toList();
    if (blockingIssues.isNotEmpty) {
      throw StateError(
        'Cannot export parallax while validation has '
        '${blockingIssues.length} blocking issue(s).',
      );
    }

    final savePlan = _store.buildSavePlan(workspace, document: parallaxDocument);
    if (!savePlan.hasChanges) {
      return ExportResult(
        applied: false,
        artifacts: const <ExportArtifact>[
          ExportArtifact(
            title: 'parallax_summary.md',
            content:
                '# Parallax Export\n\nchangedThemes: 0\n\nNo parallax edits detected.',
          ),
        ],
      );
    }

    await _store.save(workspace, document: parallaxDocument, savePlan: savePlan);
    return ExportResult(
      applied: true,
      artifacts: <ExportArtifact>[
        ExportArtifact(
          title: 'parallax_summary.md',
          content: _buildSummary(savePlan),
        ),
      ],
    );
  }

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) {
    final parallaxDocument = _asParallaxDocument(document);
    final savePlan = _store.buildSavePlan(workspace, document: parallaxDocument);
    if (!savePlan.hasChanges) {
      return PendingChanges.empty;
    }

    return PendingChanges(
      changedItemIds: savePlan.changedThemeIds,
      fileDiffs: savePlan.writes
          .map(
            (write) => PendingFileDiff(
              relativePath: write.relativePath,
              editCount: 1,
              unifiedDiff: _buildUnifiedDiff(write),
            ),
          )
          .toList(growable: false),
    );
  }

  ParallaxDefsDocument _setActiveLevel(
    ParallaxDefsDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final levelId = _normalizedString(payload['levelId']);
    if (levelId.isEmpty || !document.availableLevelIds.contains(levelId)) {
      return _withOperationIssue(
        document,
        code: 'set_active_level_invalid',
        message:
            'Cannot set active level to "$levelId". Choose a known level option.',
      );
    }
    if (document.activeLevelId == levelId) {
      return document;
    }
    _preferredActiveLevelId = levelId;
    return document.copyWith(activeLevelId: levelId);
  }

  ParallaxDefsDocument _ensureActiveTheme(
    ParallaxDefsDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final activeThemeId = resolveActiveThemeId(document);
    final activeLevelId = document.activeLevelId ?? '';
    if (activeThemeId == null || activeThemeId.isEmpty) {
      return _withOperationIssue(
        document,
        code: 'missing_active_theme_mapping',
        message:
            'Active level "$activeLevelId" does not resolve to a themeId in '
            'level_registry.dart.',
      );
    }
    if (findParallaxThemeById(document.themes, activeThemeId) != null) {
      return document;
    }
    final groundMaterialAssetPath = _normalizedString(
      payload['groundMaterialAssetPath'],
    );
    final nextTheme = ParallaxThemeDef(
      themeId: activeThemeId,
      revision: 1,
      groundMaterialAssetPath: groundMaterialAssetPath,
      layers: const <ParallaxLayerDef>[],
    );
    final nextThemes = List<ParallaxThemeDef>.from(document.themes)
      ..add(nextTheme)
      ..sort(compareParallaxThemesDeterministic);
    return document.copyWith(
      themes: List<ParallaxThemeDef>.unmodifiable(nextThemes),
    );
  }

  ParallaxDefsDocument _updateGroundMaterialAssetPath(
    ParallaxDefsDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final activeThemeId = resolveActiveThemeId(document);
    if (activeThemeId == null || activeThemeId.isEmpty) {
      return _withOperationIssue(
        document,
        code: 'missing_active_theme_mapping',
        message: 'Active level does not resolve to a themeId.',
      );
    }
    final theme = findParallaxThemeById(document.themes, activeThemeId);
    if (theme == null) {
      return _withOperationIssue(
        document,
        code: 'missing_active_theme',
        message: 'Resolved themeId "$activeThemeId" is not authored yet.',
      );
    }
    final nextPath = _normalizedString(
      payload['groundMaterialAssetPath'],
      fallback: theme.groundMaterialAssetPath,
    );
    final nextTheme = theme.copyWith(
      groundMaterialAssetPath: nextPath,
    ).normalized();
    if (parallaxThemeEquals(nextTheme, theme, ignoreRevision: true)) {
      return document;
    }
    return _replaceTheme(
      document,
      themeId: activeThemeId,
      nextTheme: _bumpThemeRevision(nextTheme, fromTheme: theme),
    );
  }

  ParallaxDefsDocument _createLayer(
    ParallaxDefsDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final activeTheme = _requireActiveTheme(document);
    if (activeTheme == null) {
      return _withOperationIssue(
        document,
        code: 'create_layer_no_theme',
        message: 'Create layer requires an active authored theme.',
      );
    }
    final group = _normalizedString(
      payload['group'],
      fallback: parallaxGroupBackground,
    );
    final existingKeys = activeTheme.layers
        .map((layer) => layer.layerKey)
        .toSet();
    final preferredLayerKey = _normalizedString(
      payload['layerKey'],
      fallback: '${activeTheme.themeId}_${group}_layer',
    );
    final layerKey = _allocateUniqueLayerKey(existingKeys, preferredLayerKey);
    final nextZOrder = _nextZOrderForGroup(activeTheme, group);
    final layer = ParallaxLayerDef(
      layerKey: layerKey,
      assetPath: _normalizedString(payload['assetPath']),
      group: group,
      parallaxFactor: _doubleOrDefault(
        payload['parallaxFactor'],
        fallback: group == parallaxGroupForeground ? 1.0 : 0.5,
      ),
      zOrder: _intOrDefault(payload['zOrder'], fallback: nextZOrder),
      opacity: _doubleOrDefault(payload['opacity'], fallback: 1.0),
      yOffset: _doubleOrDefault(payload['yOffset'], fallback: 0.0),
    ).normalized();
    final nextTheme = activeTheme.copyWith(
      layers: List<ParallaxLayerDef>.from(activeTheme.layers)..add(layer),
    ).normalized();
    return _replaceTheme(
      document,
      themeId: activeTheme.themeId,
      nextTheme: _bumpThemeRevision(nextTheme, fromTheme: activeTheme),
    );
  }

  ParallaxDefsDocument _duplicateLayer(
    ParallaxDefsDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final activeTheme = _requireActiveTheme(document);
    final layerKey = _normalizedString(payload['layerKey']);
    if (activeTheme == null || layerKey.isEmpty) {
      return _withOperationIssue(
        document,
        code: 'duplicate_layer_invalid_payload',
        message: 'Duplicate layer requires an active theme and source layerKey.',
      );
    }
    final sourceLayer = _findLayer(activeTheme, layerKey);
    if (sourceLayer == null) {
      return _withOperationIssue(
        document,
        code: 'duplicate_layer_missing_source',
        message: 'Cannot duplicate unknown layerKey "$layerKey".',
      );
    }
    final existingKeys = activeTheme.layers
        .map((layer) => layer.layerKey)
        .toSet();
    final duplicated = sourceLayer.copyWith(
      layerKey: _allocateUniqueLayerKey(
        existingKeys,
        '${sourceLayer.layerKey}_copy',
      ),
    );
    final nextTheme = activeTheme.copyWith(
      layers: List<ParallaxLayerDef>.from(activeTheme.layers)..add(duplicated),
    ).normalized();
    return _replaceTheme(
      document,
      themeId: activeTheme.themeId,
      nextTheme: _bumpThemeRevision(nextTheme, fromTheme: activeTheme),
    );
  }

  ParallaxDefsDocument _removeLayer(
    ParallaxDefsDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final activeTheme = _requireActiveTheme(document);
    final layerKey = _normalizedString(payload['layerKey']);
    if (activeTheme == null || layerKey.isEmpty) {
      return _withOperationIssue(
        document,
        code: 'remove_layer_invalid_payload',
        message: 'Remove layer requires an active theme and layerKey.',
      );
    }
    if (_findLayer(activeTheme, layerKey) == null) {
      return _withOperationIssue(
        document,
        code: 'remove_layer_missing_source',
        message: 'Cannot remove unknown layerKey "$layerKey".',
      );
    }
    final nextTheme = activeTheme.copyWith(
      layers: activeTheme.layers
          .where((layer) => layer.layerKey != layerKey)
          .toList(growable: false),
    ).normalized();
    return _replaceTheme(
      document,
      themeId: activeTheme.themeId,
      nextTheme: _bumpThemeRevision(nextTheme, fromTheme: activeTheme),
    );
  }

  ParallaxDefsDocument _updateLayer(
    ParallaxDefsDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final activeTheme = _requireActiveTheme(document);
    final layerKey = _normalizedString(payload['layerKey']);
    if (activeTheme == null || layerKey.isEmpty) {
      return _withOperationIssue(
        document,
        code: 'update_layer_invalid_payload',
        message: 'Update layer requires an active theme and layerKey.',
      );
    }
    final sourceLayer = _findLayer(activeTheme, layerKey);
    if (sourceLayer == null) {
      return _withOperationIssue(
        document,
        code: 'update_layer_missing_source',
        message: 'Cannot update unknown layerKey "$layerKey".',
      );
    }
    final nextLayer = sourceLayer.copyWith(
      layerKey: _normalizedString(
        payload['nextLayerKey'],
        fallback: sourceLayer.layerKey,
      ),
      assetPath: _normalizedString(
        payload['assetPath'],
        fallback: sourceLayer.assetPath,
      ),
      group: _normalizedString(payload['group'], fallback: sourceLayer.group),
      parallaxFactor: _doubleOrDefault(
        payload['parallaxFactor'],
        fallback: sourceLayer.parallaxFactor,
      ),
      zOrder: _intOrDefault(payload['zOrder'], fallback: sourceLayer.zOrder),
      opacity: _doubleOrDefault(payload['opacity'], fallback: sourceLayer.opacity),
      yOffset: _doubleOrDefault(payload['yOffset'], fallback: sourceLayer.yOffset),
    ).normalized();
    if (parallaxLayerEquals(nextLayer, sourceLayer)) {
      return document;
    }
    final nextLayers = activeTheme.layers
        .map((layer) => layer.layerKey == layerKey ? nextLayer : layer)
        .toList(growable: false);
    final nextTheme = activeTheme.copyWith(layers: nextLayers).normalized();
    return _replaceTheme(
      document,
      themeId: activeTheme.themeId,
      nextTheme: _bumpThemeRevision(nextTheme, fromTheme: activeTheme),
    );
  }

  ParallaxDefsDocument _reorderLayer(
    ParallaxDefsDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final activeTheme = _requireActiveTheme(document);
    final layerKey = _normalizedString(payload['layerKey']);
    final direction = _intOrDefault(payload['direction'], fallback: 0);
    if (activeTheme == null || layerKey.isEmpty || direction == 0) {
      return _withOperationIssue(
        document,
        code: 'reorder_layer_invalid_payload',
        message: 'Reorder layer requires layerKey and non-zero direction.',
      );
    }
    final sourceLayer = _findLayer(activeTheme, layerKey);
    if (sourceLayer == null) {
      return _withOperationIssue(
        document,
        code: 'reorder_layer_missing_source',
        message: 'Cannot reorder unknown layerKey "$layerKey".',
      );
    }

    final groupLayers = activeTheme.layers
        .where((layer) => layer.group == sourceLayer.group)
        .toList(growable: false)
      ..sort(compareParallaxLayersDeterministic);
    final index = groupLayers.indexWhere((layer) => layer.layerKey == layerKey);
    final swapIndex = index + (direction < 0 ? -1 : 1);
    if (index < 0 || swapIndex < 0 || swapIndex >= groupLayers.length) {
      return document;
    }

    final mutableGroupLayers = List<ParallaxLayerDef>.from(groupLayers);
    final swapLayer = mutableGroupLayers[index];
    mutableGroupLayers[index] = mutableGroupLayers[swapIndex];
    mutableGroupLayers[swapIndex] = swapLayer;

    final updatedByLayerKey = <String, ParallaxLayerDef>{};
    for (var i = 0; i < mutableGroupLayers.length; i += 1) {
      final layer = mutableGroupLayers[i];
      updatedByLayerKey[layer.layerKey] = layer.copyWith(zOrder: (i + 1) * 10);
    }
    final nextLayers = activeTheme.layers
        .map((layer) => updatedByLayerKey[layer.layerKey] ?? layer)
        .toList(growable: false);
    final nextTheme = activeTheme.copyWith(layers: nextLayers).normalized();
    if (parallaxThemeEquals(nextTheme, activeTheme, ignoreRevision: true)) {
      return document;
    }
    return _replaceTheme(
      document,
      themeId: activeTheme.themeId,
      nextTheme: _bumpThemeRevision(nextTheme, fromTheme: activeTheme),
    );
  }

  ParallaxThemeDef? _requireActiveTheme(ParallaxDefsDocument document) {
    final activeThemeId = resolveActiveThemeId(document);
    if (activeThemeId == null || activeThemeId.isEmpty) {
      return null;
    }
    return findParallaxThemeById(document.themes, activeThemeId);
  }

  ParallaxDefsDocument _replaceTheme(
    ParallaxDefsDocument document, {
    required String themeId,
    required ParallaxThemeDef nextTheme,
  }) {
    final nextThemes = document.themes
        .map((theme) => theme.themeId == themeId ? nextTheme : theme)
        .toList(growable: false)
      ..sort(compareParallaxThemesDeterministic);
    return document.copyWith(
      themes: List<ParallaxThemeDef>.unmodifiable(nextThemes),
    );
  }

  ParallaxLayerDef? _findLayer(ParallaxThemeDef theme, String layerKey) {
    for (final layer in theme.layers) {
      if (layer.layerKey == layerKey) {
        return layer;
      }
    }
    return null;
  }

  String _buildSummary(ParallaxSavePlan savePlan) {
    final lines = <String>[
      '# Parallax Export',
      '',
      'changedThemes: ${savePlan.changedThemeIds.length}',
      'changedFiles: ${savePlan.writes.length}',
      '',
      '## Files',
      ...savePlan.writes.map((write) => '- ${write.relativePath}'),
    ];
    return lines.join('\n');
  }

  String _buildUnifiedDiff(ParallaxFileWrite write) {
    final path = write.relativePath.replaceAll('\\', '/');
    final beforeLines = _splitLines(write.beforeContent ?? '');
    final afterLines = _splitLines(write.afterContent);
    final lines = <String>[
      'diff --git a/$path b/$path',
      '--- a/$path',
      '+++ b/$path',
      '@@ -1,${beforeLines.length} +1,${afterLines.length} @@',
      ...beforeLines.map((line) => '-$line'),
      ...afterLines.map((line) => '+$line'),
    ];
    return lines.join('\n');
  }

  List<String> _splitLines(String content) {
    final normalized = content.replaceAll('\r\n', '\n');
    final lines = normalized.split('\n');
    if (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    return lines;
  }

  ParallaxDefsDocument _clearOperationIssuesIfNeeded(
    ParallaxDefsDocument document,
  ) {
    if (document.operationIssues.isEmpty) {
      return document;
    }
    return document.copyWith(clearOperationIssues: true);
  }

  ParallaxDefsDocument _withOperationIssue(
    ParallaxDefsDocument document, {
    required String code,
    required String message,
  }) {
    return document.copyWith(
      operationIssues: <ValidationIssue>[
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: code,
          message: message,
          sourcePath: document.baseline?.sourcePath ?? ParallaxStore.defsPath,
        ),
      ],
    );
  }

  ParallaxDefsDocument _asParallaxDocument(AuthoringDocument document) {
    if (document is! ParallaxDefsDocument) {
      throw StateError(
        'ParallaxDomainPlugin expected ParallaxDefsDocument but got '
        '${document.runtimeType}.',
      );
    }
    return document;
  }
}

int _nextZOrderForGroup(ParallaxThemeDef theme, String group) {
  final groupLayers = theme.layers.where((layer) => layer.group == group);
  var maxZOrder = 0;
  for (final layer in groupLayers) {
    if (layer.zOrder > maxZOrder) {
      maxZOrder = layer.zOrder;
    }
  }
  if (maxZOrder <= 0) {
    return 10;
  }
  return ((maxZOrder / 10).floor() + 1) * 10;
}

String _allocateUniqueLayerKey(Set<String> existingKeys, String preferredSeed) {
  final base = _slugify(preferredSeed, fallback: 'layer');
  if (!existingKeys.contains(base)) {
    return base;
  }
  var counter = 2;
  while (true) {
    final candidate = '${base}_$counter';
    if (!existingKeys.contains(candidate)) {
      return candidate;
    }
    counter += 1;
  }
}

String _slugify(String raw, {required String fallback}) {
  final lower = raw.toLowerCase().trim();
  if (lower.isEmpty) {
    return fallback;
  }
  final normalized = lower.replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
  if (normalized.isEmpty) {
    return fallback;
  }
  return normalized;
}

String _normalizedString(Object? raw, {String fallback = ''}) {
  if (raw is String) {
    final normalized = raw.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return fallback;
}

int _intOrDefault(Object? raw, {required int fallback}) {
  if (raw is int) {
    return raw;
  }
  if (raw is num && raw.isFinite) {
    return raw.toInt();
  }
  if (raw is String) {
    final parsed = int.tryParse(raw.trim());
    if (parsed != null) {
      return parsed;
    }
  }
  return fallback;
}

double _doubleOrDefault(Object? raw, {required double fallback}) {
  if (raw is num && raw.isFinite) {
    return raw.toDouble();
  }
  if (raw is String) {
    final parsed = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (parsed != null && parsed.isFinite) {
      return parsed;
    }
  }
  return fallback;
}

ParallaxThemeDef _bumpThemeRevision(
  ParallaxThemeDef nextTheme, {
  required ParallaxThemeDef fromTheme,
}) {
  final nextRevision = fromTheme.revision <= 0 ? 1 : fromTheme.revision + 1;
  return nextTheme.copyWith(revision: nextRevision);
}
