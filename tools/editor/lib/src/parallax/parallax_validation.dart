import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/authoring_types.dart';
import '../workspace/editor_workspace.dart';
import 'parallax_domain_models.dart';

List<ValidationIssue> validateParallaxDocument(ParallaxDefsDocument document) {
  final issues = <ValidationIssue>[
    ...document.loadIssues,
    ...document.operationIssues,
  ];
  final sourcePath = document.baseline?.sourcePath ?? parallaxDefsSourcePath;
  final sortedThemes = List<ParallaxThemeDef>.from(document.themes)
    ..sort(compareParallaxThemesDeterministic);

  if (document.availableLevelIds.isEmpty) {
    issues.add(
      const ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'missing_level_options',
        message:
            'No active level options are available. Export is blocked until '
            'a level source can be resolved.',
      ),
    );
  }

  final activeLevelId = document.activeLevelId;
  if (activeLevelId == null || activeLevelId.isEmpty) {
    issues.add(
      const ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'missing_active_level',
        message: 'Active level context is missing.',
      ),
    );
  } else if (!document.availableLevelIds.contains(activeLevelId)) {
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'unknown_level_id',
        message: 'Active level "$activeLevelId" is not in the known level set.',
        sourcePath: sourcePath,
      ),
    );
  }

  final activeParallaxThemeId = resolveActiveParallaxThemeId(document);
  if (activeLevelId != null &&
      activeLevelId.isNotEmpty &&
      activeParallaxThemeId == null) {
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'missing_active_theme_mapping',
        message:
            'Level "$activeLevelId" does not resolve to a parallaxThemeId in '
            'level_registry.dart.',
        sourcePath: sourcePath,
      ),
    );
  }

  if (!_themeOrderingMatches(document.themes)) {
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'non_canonical_theme_order',
        message: 'Themes must be ordered deterministically by parallaxThemeId.',
        sourcePath: sourcePath,
      ),
    );
  }

  final themeIds = <String>{};
  final workspace = EditorWorkspace(rootPath: document.workspaceRootPath);
  for (final theme in sortedThemes) {
    if (theme.parallaxThemeId.isEmpty) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'missing_theme_id',
          message: 'A parallax theme is missing parallaxThemeId.',
          sourcePath: sourcePath,
        ),
      );
    } else if (!themeIds.add(theme.parallaxThemeId)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'duplicate_theme_id',
          message: 'Duplicate parallaxThemeId "${theme.parallaxThemeId}".',
          sourcePath: sourcePath,
        ),
      );
    }

    if (theme.revision <= 0) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_revision',
          message: 'Theme "${theme.parallaxThemeId}" has invalid revision ${theme.revision}.',
          sourcePath: sourcePath,
        ),
      );
    }

    _validateAssetPath(
      issues,
      workspace: workspace,
      sourcePath: sourcePath,
      code: 'invalid_ground_material_asset_path',
      fieldLabel: 'groundMaterialAssetPath',
      value: theme.groundMaterialAssetPath,
      ownerLabel: 'Theme "${theme.parallaxThemeId}"',
    );

    if (!_layerOrderingMatches(theme.layers)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'non_canonical_layer_order',
          message:
              'Theme "${theme.parallaxThemeId}" layers must be ordered by group, '
              'zOrder, then layerKey.',
          sourcePath: sourcePath,
        ),
      );
    }

    final layerKeys = <String>{};
    for (final layer in theme.layers) {
      if (layer.layerKey.isEmpty) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'missing_layer_key',
            message: 'Theme "${theme.parallaxThemeId}" contains a layer without layerKey.',
            sourcePath: sourcePath,
          ),
        );
      } else if (!layerKeys.add(layer.layerKey)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'duplicate_layer_key',
            message:
                'Theme "${theme.parallaxThemeId}" has duplicate layerKey "${layer.layerKey}".',
            sourcePath: sourcePath,
          ),
        );
      }

      _validateAssetPath(
        issues,
        workspace: workspace,
        sourcePath: sourcePath,
        code: 'invalid_layer_asset_path',
        fieldLabel: 'assetPath',
        value: layer.assetPath,
        ownerLabel: 'Layer "${layer.layerKey}"',
      );

      if (layer.group != parallaxGroupBackground &&
          layer.group != parallaxGroupForeground) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'invalid_layer_group',
            message:
                'Layer "${layer.layerKey}" must use "$parallaxGroupBackground" '
                'or "$parallaxGroupForeground".',
            sourcePath: sourcePath,
          ),
        );
      }

      if (!layer.parallaxFactor.isFinite ||
          layer.parallaxFactor < minParallaxFactor ||
          layer.parallaxFactor > maxParallaxFactor) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'parallax_factor_out_of_range',
            message:
                'Layer "${layer.layerKey}" parallaxFactor must be between '
                '$minParallaxFactor and $maxParallaxFactor.',
            sourcePath: sourcePath,
          ),
        );
      }

      if (!layer.opacity.isFinite ||
          layer.opacity < minOpacity ||
          layer.opacity > maxOpacity) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'opacity_out_of_range',
            message:
                'Layer "${layer.layerKey}" opacity must be between '
                '$minOpacity and $maxOpacity.',
            sourcePath: sourcePath,
          ),
        );
      }

      if (!layer.yOffset.isFinite || layer.yOffset.abs() > maxAbsYOffset) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'y_offset_out_of_range',
            message:
                'Layer "${layer.layerKey}" yOffset must be finite and between '
                '-$maxAbsYOffset and $maxAbsYOffset.',
            sourcePath: sourcePath,
          ),
        );
      }

      if (layer.opacity > 0 && layer.opacity < 0.15) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.warning,
            code: 'very_low_opacity',
            message:
                'Layer "${layer.layerKey}" is almost invisible at opacity '
                '${formatCanonicalParallaxNumber(layer.opacity)}.',
            sourcePath: sourcePath,
          ),
        );
      }

      if (layer.parallaxFactor > 1.5) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.warning,
            code: 'extreme_parallax_factor',
            message:
                'Layer "${layer.layerKey}" uses a very aggressive '
                'parallaxFactor ${formatCanonicalParallaxNumber(layer.parallaxFactor)}.',
            sourcePath: sourcePath,
          ),
        );
      }

      if (layer.yOffset.abs() > 1024) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.warning,
            code: 'large_y_offset',
            message:
                'Layer "${layer.layerKey}" uses a large yOffset '
                '${formatCanonicalParallaxNumber(layer.yOffset)}.',
            sourcePath: sourcePath,
          ),
        );
      }
    }
  }

  if (activeParallaxThemeId != null &&
      activeParallaxThemeId.isNotEmpty &&
      findParallaxThemeById(document.themes, activeParallaxThemeId) == null) {
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'missing_active_theme',
        message:
            'Resolved parallaxThemeId "$activeParallaxThemeId" for level "$activeLevelId" is '
            'not defined in parallax_defs.json.',
        sourcePath: sourcePath,
      ),
    );
  }

  issues.sort(_compareIssues);
  return issues;
}

void _validateAssetPath(
  List<ValidationIssue> issues, {
  required EditorWorkspace workspace,
  required String sourcePath,
  required String code,
  required String fieldLabel,
  required String value,
  required String ownerLabel,
}) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: code,
        message: '$ownerLabel $fieldLabel must be a non-empty asset path.',
        sourcePath: sourcePath,
      ),
    );
    return;
  }

  late final String absolutePath;
  try {
    absolutePath = workspace.resolve(normalized);
  } on ArgumentError {
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: code,
        message: '$ownerLabel $fieldLabel must stay inside the workspace.',
        sourcePath: sourcePath,
      ),
    );
    return;
  }

  if (!File(absolutePath).existsSync()) {
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: code,
        message:
            '$ownerLabel $fieldLabel references missing asset '
            '"${p.normalize(normalized)}".',
        sourcePath: sourcePath,
      ),
    );
  }
}

bool _themeOrderingMatches(List<ParallaxThemeDef> themes) {
  final expected = List<ParallaxThemeDef>.from(themes)
    ..sort(compareParallaxThemesDeterministic);
  if (expected.length != themes.length) {
    return false;
  }
  for (var i = 0; i < themes.length; i += 1) {
    if (themes[i].parallaxThemeId != expected[i].parallaxThemeId) {
      return false;
    }
  }
  return true;
}

bool _layerOrderingMatches(List<ParallaxLayerDef> layers) {
  final expected = List<ParallaxLayerDef>.from(layers)
    ..sort(compareParallaxLayersDeterministic);
  if (expected.length != layers.length) {
    return false;
  }
  for (var i = 0; i < layers.length; i += 1) {
    final current = layers[i];
    final target = expected[i];
    if (current.layerKey != target.layerKey ||
        current.group != target.group ||
        current.zOrder != target.zOrder) {
      return false;
    }
  }
  return true;
}

int _compareIssues(ValidationIssue a, ValidationIssue b) {
  final sourceCompare = (a.sourcePath ?? '').compareTo(b.sourcePath ?? '');
  if (sourceCompare != 0) {
    return sourceCompare;
  }
  final severityCompare = a.severity.index.compareTo(b.severity.index);
  if (severityCompare != 0) {
    return severityCompare;
  }
  final codeCompare = a.code.compareTo(b.code);
  if (codeCompare != 0) {
    return codeCompare;
  }
  return a.message.compareTo(b.message);
}
