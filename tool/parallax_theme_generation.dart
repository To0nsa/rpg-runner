import 'dart:convert';
import 'dart:io';

const int parallaxSchemaVersion = 1;

const String _assetsImagesPrefix = 'assets/images/';
const String _levelRegistryThemeIdPath =
    'packages/runner_core/lib/levels/level_registry.dart';

const String _backgroundGroup = 'background';
const String _foregroundGroup = 'foreground';

const double _minParallaxFactor = 0.0;
const double _maxParallaxFactor = 2.0;
const double _minOpacity = 0.0;
const double _maxOpacity = 1.0;
const double _maxAbsYOffset = 4096.0;

Future<ParallaxLoadResult> loadParallaxThemes({
  required String defsPath,
  String levelRegistryPath = _levelRegistryThemeIdPath,
}) async {
  final issues = <ParallaxValidationIssue>[];
  final file = File(defsPath);
  if (!await file.exists()) {
    issues.add(
      ParallaxValidationIssue(
        path: defsPath,
        code: 'missing_file',
        message: 'Required file is missing.',
      ),
    );
    return ParallaxLoadResult(
      themes: const <ParallaxThemeSource>[],
      issues: issues,
    );
  }

  late final String raw;
  try {
    raw = await file.readAsString();
  } on Object catch (error) {
    issues.add(
      ParallaxValidationIssue(
        path: defsPath,
        code: 'read_failed',
        message: 'Unable to read file: $error',
      ),
    );
    return ParallaxLoadResult(
      themes: const <ParallaxThemeSource>[],
      issues: issues,
    );
  }

  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on Object catch (error) {
    issues.add(
      ParallaxValidationIssue(
        path: defsPath,
        code: 'invalid_json',
        message: 'JSON parse error: $error',
      ),
    );
    return ParallaxLoadResult(
      themes: const <ParallaxThemeSource>[],
      issues: issues,
    );
  }

  if (decoded is! Map<String, Object?>) {
    issues.add(
      ParallaxValidationIssue(
        path: defsPath,
        code: 'invalid_root_type',
        message: 'Top-level JSON value must be an object.',
      ),
    );
    return ParallaxLoadResult(
      themes: const <ParallaxThemeSource>[],
      issues: issues,
    );
  }

  final schemaVersion = decoded['schemaVersion'];
  if (schemaVersion is! int || schemaVersion != parallaxSchemaVersion) {
    issues.add(
      ParallaxValidationIssue(
        path: defsPath,
        code: 'invalid_schema_version',
        message: 'schemaVersion must be the integer $parallaxSchemaVersion.',
      ),
    );
  }

  final rawThemes = decoded['themes'];
  if (rawThemes is! List<Object?>) {
    issues.add(
      ParallaxValidationIssue(
        path: defsPath,
        code: 'invalid_themes_array',
        message: 'themes must be an array of objects.',
      ),
    );
    return ParallaxLoadResult(
      themes: const <ParallaxThemeSource>[],
      issues: issues,
    );
  }

  final themes = <ParallaxThemeSource>[];
  final seenThemeIds = <String>{};
  for (var i = 0; i < rawThemes.length; i += 1) {
    final entry = rawThemes[i];
    if (entry is! Map<String, Object?>) {
      issues.add(
        ParallaxValidationIssue(
          path: defsPath,
          code: 'invalid_theme_entry',
          message: 'themes[$i] must be an object.',
        ),
      );
      continue;
    }
    final theme = _parseThemeEntry(
      entry,
      issues: issues,
      defsPath: defsPath,
      themeIndex: i,
    );
    if (theme == null) {
      continue;
    }
    if (!seenThemeIds.add(theme.themeId)) {
      issues.add(
        ParallaxValidationIssue(
          path: defsPath,
          code: 'duplicate_theme_id',
          message: 'themeId "${theme.themeId}" is duplicated.',
        ),
      );
      continue;
    }
    themes.add(theme);
  }

  themes.sort(_compareThemes);
  _validateReferencedThemeIds(
    themes: themes,
    levelRegistryPath: levelRegistryPath,
    issues: issues,
    defsPath: defsPath,
  );

  if (issues.isEmpty) {
    final canonical = renderCanonicalParallaxDefsJson(themes);
    if (_normalizeNewlines(raw) != canonical) {
      issues.add(
        ParallaxValidationIssue(
          path: defsPath,
          code: 'non_canonical_parallax_defs',
          message:
              'parallax_defs.json must use canonical field order, list order, '
              'path normalization, and numeric formatting.',
        ),
      );
    }
  }

  return ParallaxLoadResult(themes: themes, issues: issues);
}

ParallaxThemeSource? _parseThemeEntry(
  Map<String, Object?> entry, {
  required List<ParallaxValidationIssue> issues,
  required String defsPath,
  required int themeIndex,
}) {
  final fieldPrefix = 'themes[$themeIndex]';
  final themeId = _readRequiredString(
    entry,
    field: 'themeId',
    issues: issues,
    path: defsPath,
    fieldPrefix: fieldPrefix,
  );
  final revision = _readRequiredPositiveInt(
    entry,
    field: 'revision',
    issues: issues,
    path: defsPath,
    fieldPrefix: fieldPrefix,
  );
  final groundMaterialAssetPath = _readRequiredAssetPath(
    entry,
    field: 'groundMaterialAssetPath',
    issues: issues,
    path: defsPath,
    fieldPrefix: fieldPrefix,
  );

  final rawLayers = entry['layers'];
  if (rawLayers is! List<Object?>) {
    issues.add(
      ParallaxValidationIssue(
        path: defsPath,
        code: 'invalid_layers_array',
        message: '$fieldPrefix.layers must be an array of objects.',
      ),
    );
    return null;
  }

  final layers = <ParallaxLayerSource>[];
  final seenLayerKeys = <String>{};
  for (var i = 0; i < rawLayers.length; i += 1) {
    final rawLayer = rawLayers[i];
    if (rawLayer is! Map<String, Object?>) {
      issues.add(
        ParallaxValidationIssue(
          path: defsPath,
          code: 'invalid_layer_entry',
          message: '$fieldPrefix.layers[$i] must be an object.',
        ),
      );
      continue;
    }
    final layer = _parseLayerEntry(
      rawLayer,
      issues: issues,
      path: defsPath,
      fieldPrefix: '$fieldPrefix.layers[$i]',
    );
    if (layer == null) {
      continue;
    }
    if (!seenLayerKeys.add(layer.layerKey)) {
      issues.add(
        ParallaxValidationIssue(
          path: defsPath,
          code: 'duplicate_layer_key',
          message: '$fieldPrefix has duplicate layerKey "${layer.layerKey}".',
        ),
      );
      continue;
    }
    layers.add(layer);
  }

  if (themeId.isEmpty || revision == null || groundMaterialAssetPath.isEmpty) {
    return null;
  }

  layers.sort(_compareLayers);
  return ParallaxThemeSource(
    themeId: themeId,
    revision: revision,
    groundMaterialAssetPath: groundMaterialAssetPath,
    layers: List<ParallaxLayerSource>.unmodifiable(layers),
  );
}

ParallaxLayerSource? _parseLayerEntry(
  Map<String, Object?> entry, {
  required List<ParallaxValidationIssue> issues,
  required String path,
  required String fieldPrefix,
}) {
  final layerKey = _readRequiredString(
    entry,
    field: 'layerKey',
    issues: issues,
    path: path,
    fieldPrefix: fieldPrefix,
  );
  final assetPath = _readRequiredAssetPath(
    entry,
    field: 'assetPath',
    issues: issues,
    path: path,
    fieldPrefix: fieldPrefix,
  );
  final group = _readRequiredString(
    entry,
    field: 'group',
    issues: issues,
    path: path,
    fieldPrefix: fieldPrefix,
  );
  if (group.isNotEmpty &&
      group != _backgroundGroup &&
      group != _foregroundGroup) {
    issues.add(
      ParallaxValidationIssue(
        path: path,
        code: 'invalid_layer_group',
        message:
            '$fieldPrefix.group must be "$_backgroundGroup" or '
            '"$_foregroundGroup".',
      ),
    );
  }

  final parallaxFactor = _readRequiredDoubleInRange(
    entry,
    field: 'parallaxFactor',
    min: _minParallaxFactor,
    max: _maxParallaxFactor,
    issues: issues,
    path: path,
    fieldPrefix: fieldPrefix,
  );
  final zOrder = _readRequiredInt(
    entry,
    field: 'zOrder',
    issues: issues,
    path: path,
    fieldPrefix: fieldPrefix,
  );
  final opacity = _readRequiredDoubleInRange(
    entry,
    field: 'opacity',
    min: _minOpacity,
    max: _maxOpacity,
    issues: issues,
    path: path,
    fieldPrefix: fieldPrefix,
  );
  final yOffset = _readRequiredFiniteDouble(
    entry,
    field: 'yOffset',
    issues: issues,
    path: path,
    fieldPrefix: fieldPrefix,
  );
  if (yOffset != null && yOffset.abs() > _maxAbsYOffset) {
    issues.add(
      ParallaxValidationIssue(
        path: path,
        code: 'y_offset_out_of_range',
        message:
            '$fieldPrefix.yOffset must be between '
            '-$_maxAbsYOffset and $_maxAbsYOffset.',
      ),
    );
  }

  if (layerKey.isEmpty ||
      assetPath.isEmpty ||
      group.isEmpty ||
      parallaxFactor == null ||
      zOrder == null ||
      opacity == null ||
      yOffset == null) {
    return null;
  }

  return ParallaxLayerSource(
    layerKey: layerKey,
    assetPath: assetPath,
    group: group,
    parallaxFactor: _normalizeZero(parallaxFactor),
    zOrder: zOrder,
    opacity: _normalizeZero(opacity),
    yOffset: _normalizeZero(yOffset),
  );
}

void _validateReferencedThemeIds({
  required List<ParallaxThemeSource> themes,
  required String levelRegistryPath,
  required List<ParallaxValidationIssue> issues,
  required String defsPath,
}) {
  final file = File(levelRegistryPath);
  if (!file.existsSync()) {
    return;
  }
  final source = file.readAsStringSync();
  final referencedThemeIds = RegExp(
    r"themeId:\s*'([^']+)'",
  ).allMatches(source).map((match) => match.group(1)!).toSet();
  if (referencedThemeIds.isEmpty) {
    return;
  }
  final authoredThemeIds = themes.map((theme) => theme.themeId).toSet();
  final missingThemeIds =
      referencedThemeIds.difference(authoredThemeIds).toList()..sort();
  for (final missingThemeId in missingThemeIds) {
    issues.add(
      ParallaxValidationIssue(
        path: defsPath,
        code: 'missing_referenced_theme_id',
        message:
            'Level registry references themeId "$missingThemeId" but '
            'parallax_defs.json does not define it.',
      ),
    );
  }
}

String renderCanonicalParallaxDefsJson(List<ParallaxThemeSource> themes) {
  final buffer = StringBuffer()..writeln('{');
  buffer.writeln('  "schemaVersion": $parallaxSchemaVersion,');
  buffer.writeln('  "themes": [');
  for (var i = 0; i < themes.length; i += 1) {
    final theme = themes[i];
    buffer.writeln('    {');
    buffer.writeln('      "themeId": ${jsonEncode(theme.themeId)},');
    buffer.writeln('      "revision": ${theme.revision},');
    buffer.writeln(
      '      "groundMaterialAssetPath": '
      '${jsonEncode(theme.groundMaterialAssetPath)},',
    );
    buffer.writeln('      "layers": [');
    for (var j = 0; j < theme.layers.length; j += 1) {
      final layer = theme.layers[j];
      buffer.writeln('        {');
      buffer.writeln('          "layerKey": ${jsonEncode(layer.layerKey)},');
      buffer.writeln('          "assetPath": ${jsonEncode(layer.assetPath)},');
      buffer.writeln('          "group": ${jsonEncode(layer.group)},');
      buffer.writeln(
        '          "parallaxFactor": ${_formatCanonicalNumber(layer.parallaxFactor)},',
      );
      buffer.writeln('          "zOrder": ${layer.zOrder},');
      buffer.writeln(
        '          "opacity": ${_formatCanonicalNumber(layer.opacity)},',
      );
      buffer.writeln(
        '          "yOffset": ${_formatCanonicalNumber(layer.yOffset)}',
      );
      buffer.write('        }');
      if (j < theme.layers.length - 1) {
        buffer.write(',');
      }
      buffer.writeln();
    }
    buffer.writeln('      ]');
    buffer.write('    }');
    if (i < themes.length - 1) {
      buffer.write(',');
    }
    buffer.writeln();
  }
  buffer.writeln('  ]');
  buffer.writeln('}');
  return buffer.toString();
}

String renderParallaxThemeDartOutput(List<ParallaxThemeSource> themes) {
  final buffer = StringBuffer()
    ..writeln('/// GENERATED FILE. DO NOT EDIT BY HAND.')
    ..writeln('///')
    ..writeln('/// Generated by tool/generate_chunk_runtime_data.dart from:')
    ..writeln('/// - assets/authoring/level/parallax_defs.json')
    ..writeln('library;')
    ..writeln()
    ..writeln("import '../components/pixel_parallax_backdrop.dart';")
    ..writeln("import 'parallax_theme.dart';")
    ..writeln();

  for (final theme in themes) {
    final variableName = _themeVariableName(theme.themeId);
    buffer.writeln('const ParallaxTheme $variableName = ParallaxTheme(');
    buffer.writeln('  backgroundLayers: <PixelParallaxLayerSpec>[');
    for (final layer in theme.layers.where(
      (entry) => entry.group == _backgroundGroup,
    )) {
      _writeLayerSpec(buffer, layer, indent: '    ');
    }
    buffer.writeln('  ],');
    buffer.writeln(
      "  groundMaterialAssetPath: "
      "'${_escape(_runtimeAssetPath(theme.groundMaterialAssetPath))}',",
    );
    buffer.writeln('  foregroundLayers: <PixelParallaxLayerSpec>[');
    for (final layer in theme.layers.where(
      (entry) => entry.group == _foregroundGroup,
    )) {
      _writeLayerSpec(buffer, layer, indent: '    ');
    }
    buffer.writeln('  ],');
    buffer.writeln(');');
    buffer.writeln();
  }

  buffer.writeln(
    'const Map<String, ParallaxTheme> authoredParallaxThemesById = '
    '<String, ParallaxTheme>{',
  );
  for (final theme in themes) {
    buffer.writeln(
      "  '${_escape(theme.themeId)}': ${_themeVariableName(theme.themeId)},",
    );
  }
  buffer.writeln('};');
  return buffer.toString();
}

void _writeLayerSpec(
  StringBuffer buffer,
  ParallaxLayerSource layer, {
  required String indent,
}) {
  buffer
    ..writeln('${indent}PixelParallaxLayerSpec(')
    ..writeln(
      "$indent  assetPath: '${_escape(_runtimeAssetPath(layer.assetPath))}',",
    )
    ..writeln(
      '$indent  parallaxFactor: ${_formatCanonicalNumber(layer.parallaxFactor)},',
    )
    ..writeln('$indent  opacity: ${_formatCanonicalNumber(layer.opacity)},')
    ..writeln('$indent  yOffset: ${_formatCanonicalNumber(layer.yOffset)},')
    ..writeln('$indent),');
}

String _runtimeAssetPath(String authoredPath) {
  if (authoredPath.startsWith(_assetsImagesPrefix)) {
    return authoredPath.substring(_assetsImagesPrefix.length);
  }
  return authoredPath;
}

String _themeVariableName(String themeId) {
  return 'authoredParallaxTheme${_toUpperCamelIdentifier(themeId)}';
}

String _toUpperCamelIdentifier(String raw) {
  final parts = raw
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return 'Theme';
  }
  final buffer = StringBuffer();
  for (final part in parts) {
    buffer.write('${part[0].toUpperCase()}${part.substring(1)}');
  }
  return buffer.toString();
}

String _escape(String raw) {
  return raw.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
}

String _readRequiredString(
  Map<String, Object?> map, {
  required String field,
  required List<ParallaxValidationIssue> issues,
  required String path,
  required String fieldPrefix,
}) {
  final raw = map[field];
  if (raw is String) {
    final normalized = raw.trim().replaceAll('\\', '/');
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  issues.add(
    ParallaxValidationIssue(
      path: path,
      code: 'missing_$field',
      message: '$fieldPrefix.$field must be a non-empty string.',
    ),
  );
  return '';
}

String _readRequiredAssetPath(
  Map<String, Object?> map, {
  required String field,
  required List<ParallaxValidationIssue> issues,
  required String path,
  required String fieldPrefix,
}) {
  final normalized = _readRequiredString(
    map,
    field: field,
    issues: issues,
    path: path,
    fieldPrefix: fieldPrefix,
  );
  if (normalized.isEmpty) {
    return '';
  }
  if (!File(normalized).existsSync()) {
    issues.add(
      ParallaxValidationIssue(
        path: path,
        code: 'missing_asset_path',
        message: '$fieldPrefix.$field references missing asset "$normalized".',
      ),
    );
  }
  return normalized;
}

int? _readRequiredPositiveInt(
  Map<String, Object?> map, {
  required String field,
  required List<ParallaxValidationIssue> issues,
  required String path,
  required String fieldPrefix,
}) {
  final value = _readRequiredInt(
    map,
    field: field,
    issues: issues,
    path: path,
    fieldPrefix: fieldPrefix,
  );
  if (value == null) {
    return null;
  }
  if (value <= 0) {
    issues.add(
      ParallaxValidationIssue(
        path: path,
        code: 'invalid_$field',
        message: '$fieldPrefix.$field must be a positive integer.',
      ),
    );
    return null;
  }
  return value;
}

int? _readRequiredInt(
  Map<String, Object?> map, {
  required String field,
  required List<ParallaxValidationIssue> issues,
  required String path,
  required String fieldPrefix,
}) {
  final raw = map[field];
  if (raw is int) {
    return raw;
  }
  if (raw is num && raw.isFinite && raw == raw.roundToDouble()) {
    return raw.toInt();
  }
  issues.add(
    ParallaxValidationIssue(
      path: path,
      code: 'invalid_$field',
      message: '$fieldPrefix.$field must be an integer.',
    ),
  );
  return null;
}

double? _readRequiredDoubleInRange(
  Map<String, Object?> map, {
  required String field,
  required double min,
  required double max,
  required List<ParallaxValidationIssue> issues,
  required String path,
  required String fieldPrefix,
}) {
  final value = _readRequiredFiniteDouble(
    map,
    field: field,
    issues: issues,
    path: path,
    fieldPrefix: fieldPrefix,
  );
  if (value == null) {
    return null;
  }
  if (value < min || value > max) {
    issues.add(
      ParallaxValidationIssue(
        path: path,
        code: '${_snakeCase(field)}_out_of_range',
        message: '$fieldPrefix.$field must be between $min and $max.',
      ),
    );
    return null;
  }
  return value;
}

double? _readRequiredFiniteDouble(
  Map<String, Object?> map, {
  required String field,
  required List<ParallaxValidationIssue> issues,
  required String path,
  required String fieldPrefix,
}) {
  final raw = map[field];
  if (raw is num && raw.isFinite) {
    return raw.toDouble();
  }
  issues.add(
    ParallaxValidationIssue(
      path: path,
      code: 'invalid_$field',
      message: '$fieldPrefix.$field must be a finite number.',
    ),
  );
  return null;
}

int _compareThemes(ParallaxThemeSource a, ParallaxThemeSource b) {
  return a.themeId.compareTo(b.themeId);
}

int _compareLayers(ParallaxLayerSource a, ParallaxLayerSource b) {
  final groupCompare = _groupOrder(a.group).compareTo(_groupOrder(b.group));
  if (groupCompare != 0) {
    return groupCompare;
  }
  final zOrderCompare = a.zOrder.compareTo(b.zOrder);
  if (zOrderCompare != 0) {
    return zOrderCompare;
  }
  return a.layerKey.compareTo(b.layerKey);
}

int _groupOrder(String group) {
  switch (group) {
    case _backgroundGroup:
      return 0;
    case _foregroundGroup:
      return 1;
    default:
      return 2;
  }
}

double _normalizeZero(double value) {
  if (value == 0) {
    return 0;
  }
  return value;
}

String _normalizeNewlines(String raw) {
  return raw.replaceAll('\r\n', '\n');
}

String _formatCanonicalNumber(double value) {
  final normalized = _normalizeZero(value);
  if ((normalized - normalized.roundToDouble()).abs() < 1e-9) {
    return normalized.round().toString();
  }
  final fixed = normalized.toStringAsFixed(6);
  return fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _snakeCase(String value) {
  return value.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match.group(1)}_${match.group(2)!.toLowerCase()}',
  );
}

class ParallaxLoadResult {
  const ParallaxLoadResult({required this.themes, required this.issues});

  final List<ParallaxThemeSource> themes;
  final List<ParallaxValidationIssue> issues;
}

class ParallaxThemeSource {
  const ParallaxThemeSource({
    required this.themeId,
    required this.revision,
    required this.groundMaterialAssetPath,
    required this.layers,
  });

  final String themeId;
  final int revision;
  final String groundMaterialAssetPath;
  final List<ParallaxLayerSource> layers;
}

class ParallaxLayerSource {
  const ParallaxLayerSource({
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
}

class ParallaxValidationIssue implements Comparable<ParallaxValidationIssue> {
  const ParallaxValidationIssue({
    required this.path,
    required this.code,
    required this.message,
  });

  final String path;
  final String code;
  final String message;

  @override
  int compareTo(ParallaxValidationIssue other) {
    final pathCompare = path.compareTo(other.path);
    if (pathCompare != 0) {
      return pathCompare;
    }
    final codeCompare = code.compareTo(other.code);
    if (codeCompare != 0) {
      return codeCompare;
    }
    return message.compareTo(other.message);
  }
}
