import 'dart:convert';
import 'dart:io';

import '../domain/authoring_types.dart';
import '../workspace/editor_workspace.dart';
import '../workspace/level_context_resolver.dart' as level_context;
import '../workspace/workspace_file_io.dart';
import 'parallax_domain_models.dart';

class ParallaxStore {
  static const String defsPath = parallaxDefsSourcePath;

  const ParallaxStore();

  Future<ParallaxDefsDocument> load(
    EditorWorkspace workspace, {
    String? preferredActiveLevelId,
  }) async {
    final file = File(workspace.resolve(defsPath));
    final loadIssues = <ValidationIssue>[];
    String? raw;
    ParallaxSourceBaseline? baseline;

    if (file.existsSync()) {
      try {
        raw = await file.readAsString();
        baseline = ParallaxSourceBaseline(
          sourcePath: defsPath,
          fingerprint: WorkspaceFileIo.fingerprint(raw),
        );
      } on Object catch (error) {
        loadIssues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'parallax_read_failed',
            message: 'Failed to read $defsPath: $error',
            sourcePath: defsPath,
          ),
        );
      }
    } else {
      loadIssues.add(
        const ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'missing_parallax_defs_file',
          message: 'Required parallax_defs.json file is missing.',
          sourcePath: defsPath,
        ),
      );
    }

    final themes = <ParallaxThemeDef>[];
    if (raw != null) {
      final parsed = _parseRoot(raw, sourcePath: defsPath, issues: loadIssues);
      themes.addAll(parsed);
      final canonical = renderCanonicalParallaxDefsJson(themes);
      if (_normalizeNewlines(raw) != canonical) {
        loadIssues.add(
          const ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'non_canonical_parallax_defs',
            message:
                'parallax_defs.json must use canonical field order, list '
                'ordering, path normalization, and numeric formatting.',
            sourcePath: defsPath,
          ),
        );
      }
    }

    final levelOptions = level_context.resolveLevelOptions(workspace);
    final activeLevelId = level_context.resolveActiveLevelId(
      options: levelOptions.options,
      preferredLevelId: preferredActiveLevelId,
    );
    final parallaxThemeIdByLevelId = level_context.extractLevelVisualThemeIds(
      workspace,
    );
    final sortedThemes = List<ParallaxThemeDef>.from(themes)
      ..sort(compareParallaxThemesDeterministic);

    return ParallaxDefsDocument(
      workspaceRootPath: workspace.rootPath,
      themes: List<ParallaxThemeDef>.unmodifiable(sortedThemes),
      baseline: baseline,
      availableLevelIds: List<String>.unmodifiable(levelOptions.options),
      activeLevelId: activeLevelId,
      levelOptionSource: levelOptions.source,
      parallaxThemeIdByLevelId: parallaxThemeIdByLevelId,
      loadIssues: List<ValidationIssue>.unmodifiable(loadIssues),
    );
  }

  ParallaxSavePlan buildSavePlan(
    EditorWorkspace workspace, {
    required ParallaxDefsDocument document,
  }) {
    final file = File(workspace.resolve(defsPath));
    final beforeContent = file.existsSync() ? file.readAsStringSync() : null;
    final afterContent = renderCanonicalParallaxDefsJson(document.themes);
    if (_normalizeNewlines(beforeContent ?? '') == afterContent) {
      return const ParallaxSavePlan(
        changedParallaxThemeIds: <String>[],
        writes: <ParallaxFileWrite>[],
      );
    }

    return ParallaxSavePlan(
      changedParallaxThemeIds: document.themes
          .map((theme) => theme.parallaxThemeId)
          .where((parallaxThemeId) => parallaxThemeId.isNotEmpty)
          .toList(growable: false),
      writes: <ParallaxFileWrite>[
        ParallaxFileWrite(
          relativePath: defsPath,
          beforeContent: beforeContent,
          afterContent: afterContent,
        ),
      ],
    );
  }

  Future<void> save(
    EditorWorkspace workspace, {
    required ParallaxDefsDocument document,
    required ParallaxSavePlan savePlan,
  }) async {
    if (savePlan.writes.isEmpty) {
      return;
    }
    _verifyNoSourceDrift(workspace, document: document);
    for (final write in savePlan.writes) {
      final file = File(workspace.resolve(write.relativePath));
      WorkspaceFileIo.atomicWrite(file, write.afterContent);
    }
  }

  List<ParallaxThemeDef> _parseRoot(
    String raw, {
    required String sourcePath,
    required List<ValidationIssue> issues,
  }) {
    final decoded = _parseJsonMap(raw);
    if (decoded == null) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_parallax_defs_json',
          message: '$sourcePath is not a valid JSON object.',
          sourcePath: sourcePath,
        ),
      );
      return const <ParallaxThemeDef>[];
    }

    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion is! int || schemaVersion != parallaxSchemaVersion) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_schema_version',
          message:
              'schemaVersion must be the integer $parallaxSchemaVersion in '
              '$sourcePath.',
          sourcePath: sourcePath,
        ),
      );
    }

    final rawThemes = decoded['themes'];
    if (rawThemes is! List<Object?>) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_themes_array',
          message: 'themes must be an array of objects.',
          sourcePath: sourcePath,
        ),
      );
      return const <ParallaxThemeDef>[];
    }

    final themes = <ParallaxThemeDef>[];
    final themeIds = <String>{};
    for (var i = 0; i < rawThemes.length; i += 1) {
      final rawTheme = rawThemes[i];
      if (rawTheme is! Map<String, Object?>) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'invalid_theme_entry',
            message: 'themes[$i] must be an object.',
            sourcePath: sourcePath,
          ),
        );
        continue;
      }
      final theme = _parseTheme(
        rawTheme,
        sourcePath: sourcePath,
        issues: issues,
        themeIndex: i,
      );
      if (theme == null) {
        continue;
      }
      if (!themeIds.add(theme.parallaxThemeId)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'duplicate_theme_id',
            message:
                'parallaxThemeId "${theme.parallaxThemeId}" is duplicated.',
            sourcePath: sourcePath,
          ),
        );
        continue;
      }
      themes.add(theme);
    }
    themes.sort(compareParallaxThemesDeterministic);
    return themes;
  }

  ParallaxThemeDef? _parseTheme(
    Map<String, Object?> raw, {
    required String sourcePath,
    required List<ValidationIssue> issues,
    required int themeIndex,
  }) {
    final prefix = 'themes[$themeIndex]';
    final parallaxThemeId = _readRequiredString(
      raw,
      field: 'parallaxThemeId',
      sourcePath: sourcePath,
      prefix: prefix,
      issues: issues,
    );
    final revision = _readRequiredInt(
      raw,
      field: 'revision',
      sourcePath: sourcePath,
      prefix: prefix,
      issues: issues,
    );
    final groundMaterialAssetPath = _readRequiredString(
      raw,
      field: 'groundMaterialAssetPath',
      sourcePath: sourcePath,
      prefix: prefix,
      issues: issues,
    );

    final rawLayers = raw['layers'];
    if (rawLayers is! List<Object?>) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_layers_array',
          message: '$prefix.layers must be an array of objects.',
          sourcePath: sourcePath,
        ),
      );
      return null;
    }

    final layers = <ParallaxLayerDef>[];
    final layerKeys = <String>{};
    for (var i = 0; i < rawLayers.length; i += 1) {
      final rawLayer = rawLayers[i];
      if (rawLayer is! Map<String, Object?>) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'invalid_layer_entry',
            message: '$prefix.layers[$i] must be an object.',
            sourcePath: sourcePath,
          ),
        );
        continue;
      }
      final layer = _parseLayer(
        rawLayer,
        sourcePath: sourcePath,
        issues: issues,
        prefix: '$prefix.layers[$i]',
      );
      if (layer == null) {
        continue;
      }
      if (!layerKeys.add(layer.layerKey)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'duplicate_layer_key',
            message: '$prefix contains duplicate layerKey "${layer.layerKey}".',
            sourcePath: sourcePath,
          ),
        );
        continue;
      }
      layers.add(layer);
    }

    if (parallaxThemeId.isEmpty ||
        revision == null ||
        groundMaterialAssetPath.isEmpty) {
      return null;
    }

    return ParallaxThemeDef(
      parallaxThemeId: parallaxThemeId,
      revision: revision,
      groundMaterialAssetPath: groundMaterialAssetPath,
      layers: List<ParallaxLayerDef>.unmodifiable(layers),
    ).normalized();
  }

  ParallaxLayerDef? _parseLayer(
    Map<String, Object?> raw, {
    required String sourcePath,
    required List<ValidationIssue> issues,
    required String prefix,
  }) {
    final layerKey = _readRequiredString(
      raw,
      field: 'layerKey',
      sourcePath: sourcePath,
      prefix: prefix,
      issues: issues,
    );
    final assetPath = _readRequiredString(
      raw,
      field: 'assetPath',
      sourcePath: sourcePath,
      prefix: prefix,
      issues: issues,
    );
    final group = _readRequiredString(
      raw,
      field: 'group',
      sourcePath: sourcePath,
      prefix: prefix,
      issues: issues,
    );
    final parallaxFactor = _readRequiredDouble(
      raw,
      field: 'parallaxFactor',
      sourcePath: sourcePath,
      prefix: prefix,
      issues: issues,
    );
    final zOrder = _readRequiredInt(
      raw,
      field: 'zOrder',
      sourcePath: sourcePath,
      prefix: prefix,
      issues: issues,
    );
    final opacity = _readRequiredDouble(
      raw,
      field: 'opacity',
      sourcePath: sourcePath,
      prefix: prefix,
      issues: issues,
    );
    final yOffset = _readRequiredDouble(
      raw,
      field: 'yOffset',
      sourcePath: sourcePath,
      prefix: prefix,
      issues: issues,
    );

    if (layerKey.isEmpty ||
        assetPath.isEmpty ||
        group.isEmpty ||
        parallaxFactor == null ||
        zOrder == null ||
        opacity == null ||
        yOffset == null) {
      return null;
    }

    return ParallaxLayerDef(
      layerKey: layerKey,
      assetPath: assetPath,
      group: group,
      parallaxFactor: parallaxFactor,
      zOrder: zOrder,
      opacity: opacity,
      yOffset: yOffset,
    ).normalized();
  }

  String _readRequiredString(
    Map<String, Object?> raw, {
    required String field,
    required String sourcePath,
    required String prefix,
    required List<ValidationIssue> issues,
  }) {
    final value = raw[field];
    if (value is String) {
      final normalized = value.trim().replaceAll('\\', '/');
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'missing_$field',
        message: '$prefix.$field must be a non-empty string.',
        sourcePath: sourcePath,
      ),
    );
    return '';
  }

  int? _readRequiredInt(
    Map<String, Object?> raw, {
    required String field,
    required String sourcePath,
    required String prefix,
    required List<ValidationIssue> issues,
  }) {
    final value = raw[field];
    if (value is int) {
      return value;
    }
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'invalid_$field',
        message: '$prefix.$field must be an integer.',
        sourcePath: sourcePath,
      ),
    );
    return null;
  }

  double? _readRequiredDouble(
    Map<String, Object?> raw, {
    required String field,
    required String sourcePath,
    required String prefix,
    required List<ValidationIssue> issues,
  }) {
    final value = raw[field];
    if (value is num && value.isFinite) {
      return value.toDouble();
    }
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'invalid_$field',
        message: '$prefix.$field must be a finite number.',
        sourcePath: sourcePath,
      ),
    );
    return null;
  }

  Map<String, Object?>? _parseJsonMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
    } on Object {
      return null;
    }
    return null;
  }

  void _verifyNoSourceDrift(
    EditorWorkspace workspace, {
    required ParallaxDefsDocument document,
  }) {
    final baseline = document.baseline;
    if (baseline == null) {
      return;
    }
    final file = File(workspace.resolve(baseline.sourcePath));
    if (!file.existsSync()) {
      throw StateError(
        'Source drift detected for ${baseline.sourcePath}: file no longer '
        'exists. Reload before export.',
      );
    }
    final currentFingerprint = WorkspaceFileIo.fingerprint(
      file.readAsStringSync(),
    );
    if (currentFingerprint != baseline.fingerprint) {
      throw StateError(
        'Source drift detected for ${baseline.sourcePath}. Reload before '
        'export.',
      );
    }
  }
}

class ParallaxSavePlan {
  const ParallaxSavePlan({
    required this.changedParallaxThemeIds,
    required this.writes,
  });

  final List<String> changedParallaxThemeIds;
  final List<ParallaxFileWrite> writes;

  bool get hasChanges => writes.isNotEmpty;
}

class ParallaxFileWrite {
  const ParallaxFileWrite({
    required this.relativePath,
    required this.beforeContent,
    required this.afterContent,
  });

  final String relativePath;
  final String? beforeContent;
  final String afterContent;
}

String _normalizeNewlines(String raw) {
  return raw.replaceAll('\r\n', '\n');
}
