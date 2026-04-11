import 'package:flutter/foundation.dart';

import '../domain/authoring_types.dart';

const int parallaxSchemaVersion = 1;
const String parallaxDefsSourcePath = 'assets/authoring/level/parallax_defs.json';
const String parallaxGroupBackground = 'background';
const String parallaxGroupForeground = 'foreground';
const double minParallaxFactor = 0.0;
const double maxParallaxFactor = 2.0;
const double minOpacity = 0.0;
const double maxOpacity = 1.0;
const double maxAbsYOffset = 4096.0;

@immutable
class ParallaxLayerDef {
  const ParallaxLayerDef({
    required this.layerKey,
    required this.assetPath,
    required this.group,
    required this.parallaxFactor,
    required this.zOrder,
    required this.opacity,
    required this.yOffset,
  });

  final String layerKey;
  final String assetPath;
  final String group;
  final double parallaxFactor;
  final int zOrder;
  final double opacity;
  final double yOffset;

  ParallaxLayerDef copyWith({
    String? layerKey,
    String? assetPath,
    String? group,
    double? parallaxFactor,
    int? zOrder,
    double? opacity,
    double? yOffset,
  }) {
    return ParallaxLayerDef(
      layerKey: layerKey ?? this.layerKey,
      assetPath: assetPath ?? this.assetPath,
      group: group ?? this.group,
      parallaxFactor: parallaxFactor ?? this.parallaxFactor,
      zOrder: zOrder ?? this.zOrder,
      opacity: opacity ?? this.opacity,
      yOffset: yOffset ?? this.yOffset,
    );
  }

  ParallaxLayerDef normalized() {
    return ParallaxLayerDef(
      layerKey: layerKey.trim(),
      assetPath: _normalizePath(assetPath),
      group: group.trim(),
      parallaxFactor: normalizeParallaxNumber(parallaxFactor),
      zOrder: zOrder,
      opacity: normalizeParallaxNumber(opacity),
      yOffset: normalizeParallaxNumber(yOffset),
    );
  }

  Map<String, Object?> toJson() {
    final normalized = this.normalized();
    return <String, Object?>{
      'layerKey': normalized.layerKey,
      'assetPath': normalized.assetPath,
      'group': normalized.group,
      'parallaxFactor': normalized.parallaxFactor,
      'zOrder': normalized.zOrder,
      'opacity': normalized.opacity,
      'yOffset': normalized.yOffset,
    };
  }
}

@immutable
class ParallaxThemeDef {
  const ParallaxThemeDef({
    required this.themeId,
    required this.revision,
    required this.groundMaterialAssetPath,
    required this.layers,
  });

  final String themeId;
  final int revision;
  final String groundMaterialAssetPath;
  final List<ParallaxLayerDef> layers;

  ParallaxThemeDef copyWith({
    String? themeId,
    int? revision,
    String? groundMaterialAssetPath,
    List<ParallaxLayerDef>? layers,
  }) {
    return ParallaxThemeDef(
      themeId: themeId ?? this.themeId,
      revision: revision ?? this.revision,
      groundMaterialAssetPath:
          groundMaterialAssetPath ?? this.groundMaterialAssetPath,
      layers: layers ?? this.layers,
    );
  }

  ParallaxThemeDef normalized() {
    final sortedLayers = List<ParallaxLayerDef>.from(
      layers.map((layer) => layer.normalized()),
    )..sort(compareParallaxLayersDeterministic);
    return ParallaxThemeDef(
      themeId: themeId.trim(),
      revision: revision,
      groundMaterialAssetPath: _normalizePath(groundMaterialAssetPath),
      layers: List<ParallaxLayerDef>.unmodifiable(sortedLayers),
    );
  }

  Map<String, Object?> toJson() {
    final normalized = this.normalized();
    return <String, Object?>{
      'themeId': normalized.themeId,
      'revision': normalized.revision,
      'groundMaterialAssetPath': normalized.groundMaterialAssetPath,
      'layers': normalized.layers
          .map((layer) => layer.toJson())
          .toList(growable: false),
    };
  }
}

@immutable
class ParallaxSourceBaseline {
  const ParallaxSourceBaseline({
    required this.sourcePath,
    required this.fingerprint,
  });

  final String sourcePath;
  final String fingerprint;
}

class ParallaxDefsDocument extends AuthoringDocument {
  const ParallaxDefsDocument({
    required this.workspaceRootPath,
    required this.themes,
    required this.baseline,
    required this.availableLevelIds,
    required this.activeLevelId,
    required this.levelOptionSource,
    required this.themeIdByLevelId,
    this.loadIssues = const <ValidationIssue>[],
    this.operationIssues = const <ValidationIssue>[],
  });

  final String workspaceRootPath;
  final List<ParallaxThemeDef> themes;
  final ParallaxSourceBaseline? baseline;
  final List<String> availableLevelIds;
  final String? activeLevelId;
  final String levelOptionSource;
  final Map<String, String> themeIdByLevelId;
  final List<ValidationIssue> loadIssues;
  final List<ValidationIssue> operationIssues;

  ParallaxDefsDocument copyWith({
    String? workspaceRootPath,
    List<ParallaxThemeDef>? themes,
    ParallaxSourceBaseline? baseline,
    bool clearBaseline = false,
    List<String>? availableLevelIds,
    String? activeLevelId,
    bool clearActiveLevelId = false,
    String? levelOptionSource,
    Map<String, String>? themeIdByLevelId,
    List<ValidationIssue>? loadIssues,
    List<ValidationIssue>? operationIssues,
    bool clearOperationIssues = false,
  }) {
    return ParallaxDefsDocument(
      workspaceRootPath: workspaceRootPath ?? this.workspaceRootPath,
      themes: themes ?? this.themes,
      baseline: clearBaseline ? null : (baseline ?? this.baseline),
      availableLevelIds: availableLevelIds ?? this.availableLevelIds,
      activeLevelId: clearActiveLevelId
          ? null
          : (activeLevelId ?? this.activeLevelId),
      levelOptionSource: levelOptionSource ?? this.levelOptionSource,
      themeIdByLevelId: themeIdByLevelId ?? this.themeIdByLevelId,
      loadIssues: loadIssues ?? this.loadIssues,
      operationIssues: clearOperationIssues
          ? const <ValidationIssue>[]
          : (operationIssues ?? this.operationIssues),
    );
  }
}

class ParallaxScene extends EditableScene {
  const ParallaxScene({
    required this.themes,
    required this.availableLevelIds,
    required this.activeLevelId,
    required this.levelOptionSource,
    required this.themeIdByLevelId,
    required this.activeThemeId,
    required this.activeTheme,
    required this.activeThemeUsageLevelIds,
    required this.sourcePath,
    required this.workspaceRootPath,
  });

  final List<ParallaxThemeDef> themes;
  final List<String> availableLevelIds;
  final String? activeLevelId;
  final String levelOptionSource;
  final Map<String, String> themeIdByLevelId;
  final String? activeThemeId;
  final ParallaxThemeDef? activeTheme;
  final List<String> activeThemeUsageLevelIds;
  final String sourcePath;
  final String workspaceRootPath;
}

String? resolveActiveThemeId(ParallaxDefsDocument document) {
  final activeLevelId = document.activeLevelId;
  if (activeLevelId == null || activeLevelId.isEmpty) {
    return null;
  }
  return document.themeIdByLevelId[activeLevelId];
}

ParallaxThemeDef? findParallaxThemeById(
  Iterable<ParallaxThemeDef> themes,
  String? themeId,
) {
  if (themeId == null || themeId.isEmpty) {
    return null;
  }
  for (final theme in themes) {
    if (theme.themeId == themeId) {
      return theme;
    }
  }
  return null;
}

List<String> levelIdsUsingThemeId(
  Map<String, String> themeIdByLevelId,
  String? themeId,
) {
  if (themeId == null || themeId.isEmpty) {
    return const <String>[];
  }
  final levelIds = themeIdByLevelId.entries
      .where((entry) => entry.value == themeId)
      .map((entry) => entry.key)
      .toList(growable: false)
    ..sort();
  return List<String>.unmodifiable(levelIds);
}

int compareParallaxThemesDeterministic(
  ParallaxThemeDef a,
  ParallaxThemeDef b,
) {
  return a.themeId.compareTo(b.themeId);
}

int compareParallaxLayersDeterministic(
  ParallaxLayerDef a,
  ParallaxLayerDef b,
) {
  final groupCompare = parallaxGroupOrder(a.group).compareTo(
    parallaxGroupOrder(b.group),
  );
  if (groupCompare != 0) {
    return groupCompare;
  }
  final zOrderCompare = a.zOrder.compareTo(b.zOrder);
  if (zOrderCompare != 0) {
    return zOrderCompare;
  }
  return a.layerKey.compareTo(b.layerKey);
}

int parallaxGroupOrder(String group) {
  switch (group) {
    case parallaxGroupBackground:
      return 0;
    case parallaxGroupForeground:
      return 1;
    default:
      return 2;
  }
}

double normalizeParallaxNumber(double value) {
  if (value == 0) {
    return 0;
  }
  return value;
}

String formatCanonicalParallaxNumber(double value) {
  final normalized = normalizeParallaxNumber(value);
  if ((normalized - normalized.roundToDouble()).abs() < 1e-9) {
    return normalized.round().toString();
  }
  final fixed = normalized.toStringAsFixed(6);
  return fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String renderCanonicalParallaxDefsJson(Iterable<ParallaxThemeDef> themes) {
  final sortedThemes = List<ParallaxThemeDef>.from(
    themes.map((theme) => theme.normalized()),
  )..sort(compareParallaxThemesDeterministic);
  final buffer = StringBuffer()..writeln('{');
  buffer.writeln('  "schemaVersion": $parallaxSchemaVersion,');
  buffer.writeln('  "themes": [');
  for (var i = 0; i < sortedThemes.length; i += 1) {
    final theme = sortedThemes[i];
    buffer.writeln('    {');
    buffer.writeln('      "themeId": ${_quoted(theme.themeId)},');
    buffer.writeln('      "revision": ${theme.revision},');
    buffer.writeln(
      '      "groundMaterialAssetPath": '
      '${_quoted(theme.groundMaterialAssetPath)},',
    );
    buffer.writeln('      "layers": [');
    for (var j = 0; j < theme.layers.length; j += 1) {
      final layer = theme.layers[j];
      buffer.writeln('        {');
      buffer.writeln('          "layerKey": ${_quoted(layer.layerKey)},');
      buffer.writeln('          "assetPath": ${_quoted(layer.assetPath)},');
      buffer.writeln('          "group": ${_quoted(layer.group)},');
      buffer.writeln(
        '          "parallaxFactor": '
        '${formatCanonicalParallaxNumber(layer.parallaxFactor)},',
      );
      buffer.writeln('          "zOrder": ${layer.zOrder},');
      buffer.writeln(
        '          "opacity": ${formatCanonicalParallaxNumber(layer.opacity)},',
      );
      buffer.writeln(
        '          "yOffset": ${formatCanonicalParallaxNumber(layer.yOffset)}',
      );
      buffer.write('        }');
      if (j < theme.layers.length - 1) {
        buffer.write(',');
      }
      buffer.writeln();
    }
    buffer.writeln('      ]');
    buffer.write('    }');
    if (i < sortedThemes.length - 1) {
      buffer.write(',');
    }
    buffer.writeln();
  }
  buffer.writeln('  ]');
  buffer.writeln('}');
  return buffer.toString();
}

bool parallaxLayerEquals(ParallaxLayerDef a, ParallaxLayerDef b) {
  final left = a.normalized();
  final right = b.normalized();
  return left.layerKey == right.layerKey &&
      left.assetPath == right.assetPath &&
      left.group == right.group &&
      left.parallaxFactor == right.parallaxFactor &&
      left.zOrder == right.zOrder &&
      left.opacity == right.opacity &&
      left.yOffset == right.yOffset;
}

bool parallaxThemeEquals(
  ParallaxThemeDef a,
  ParallaxThemeDef b, {
  bool ignoreRevision = false,
}) {
  final left = a.normalized();
  final right = b.normalized();
  if (left.themeId != right.themeId ||
      left.groundMaterialAssetPath != right.groundMaterialAssetPath) {
    return false;
  }
  if (!ignoreRevision && left.revision != right.revision) {
    return false;
  }
  if (left.layers.length != right.layers.length) {
    return false;
  }
  for (var i = 0; i < left.layers.length; i += 1) {
    if (!parallaxLayerEquals(left.layers[i], right.layers[i])) {
      return false;
    }
  }
  return true;
}

String _normalizePath(String value) {
  return value.trim().replaceAll('\\', '/');
}

String _quoted(String value) {
  final escaped = value
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"');
  return '"$escaped"';
}
