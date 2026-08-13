import 'dart:convert';

const int terrainMaterialCatalogSchemaVersion = 1;

final RegExp _materialKeyPattern = RegExp(r'^[a-z][a-z0-9_]*$');
final RegExp _assetPathPattern = RegExp(
  r'^assets/images/terrain/[a-zA-Z0-9_./-]+\.png$',
);

/// One image repeated along a compiler-owned terrain edge.
///
/// [anchorY] is the source-image Y coordinate, in logical pixels, aligned to
/// the exact edge. Local positive Y points toward the edge's outward normal.
final class TerrainMaterialEdgeLayer {
  const TerrainMaterialEdgeLayer({
    required this.assetPath,
    required this.anchorY,
  });

  final String assetPath;
  final double anchorY;

  Map<String, Object?> toJson() => <String, Object?>{
    'assetPath': assetPath,
    'anchorY': _canonicalNumber(anchorY),
  };

  @override
  bool operator ==(Object other) =>
      other is TerrainMaterialEdgeLayer &&
      assetPath == other.assetPath &&
      anchorY == other.anchorY;

  @override
  int get hashCode => Object.hash(assetPath, anchorY);
}

/// Ordered base/detail layers for one exposed-edge orientation.
///
/// The base is required whenever a profile exists. The optional detail is
/// rendered afterward and is typically sparse grass, roots, or overhang art.
final class TerrainMaterialEdgeProfile {
  const TerrainMaterialEdgeProfile({required this.base, this.detail});

  final TerrainMaterialEdgeLayer base;
  final TerrainMaterialEdgeLayer? detail;

  Map<String, Object?> toJson() => <String, Object?>{
    'base': base.toJson(),
    if (detail case final detail?) 'detail': detail.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is TerrainMaterialEdgeProfile &&
      base == other.base &&
      detail == other.detail;

  @override
  int get hashCode => Object.hash(base, detail);
}

/// One non-repeating image anchored to an endpoint of a top-facing edge.
final class TerrainMaterialCap {
  const TerrainMaterialCap({
    required this.assetPath,
    required this.anchorX,
    required this.anchorY,
  });

  final String assetPath;
  final double anchorX;
  final double anchorY;

  Map<String, Object?> toJson() => <String, Object?>{
    'assetPath': assetPath,
    'anchorX': _canonicalNumber(anchorX),
    'anchorY': _canonicalNumber(anchorY),
  };

  @override
  bool operator ==(Object other) =>
      other is TerrainMaterialCap &&
      assetPath == other.assetPath &&
      anchorX == other.anchorX &&
      anchorY == other.anchorY;

  @override
  int get hashCode => Object.hash(assetPath, anchorX, anchorY);
}

/// Complete visual definition referenced by polygon `materialKey` metadata.
///
/// Top profiles cover horizontal and sloped upward-facing edges. Wall and
/// underside profiles are optional, making unsupported orientations explicit
/// in the editor instead of silently inventing fallback art.
final class TerrainMaterialDefinition {
  const TerrainMaterialDefinition({
    required this.key,
    required this.displayName,
    required this.revision,
    required this.fillAssetPath,
    required this.top,
    this.leftWall,
    this.rightWall,
    this.underside,
    this.topStartCap,
    this.topEndCap,
  });

  final String key;
  final String displayName;
  final int revision;
  final String fillAssetPath;
  final TerrainMaterialEdgeProfile top;
  final TerrainMaterialEdgeProfile? leftWall;
  final TerrainMaterialEdgeProfile? rightWall;
  final TerrainMaterialEdgeProfile? underside;
  final TerrainMaterialCap? topStartCap;
  final TerrainMaterialCap? topEndCap;

  TerrainMaterialDefinition copyWith({
    String? key,
    String? displayName,
    int? revision,
    String? fillAssetPath,
    TerrainMaterialEdgeProfile? top,
    TerrainMaterialEdgeProfile? leftWall,
    bool clearLeftWall = false,
    TerrainMaterialEdgeProfile? rightWall,
    bool clearRightWall = false,
    TerrainMaterialEdgeProfile? underside,
    bool clearUnderside = false,
    TerrainMaterialCap? topStartCap,
    bool clearTopStartCap = false,
    TerrainMaterialCap? topEndCap,
    bool clearTopEndCap = false,
  }) => TerrainMaterialDefinition(
    key: key ?? this.key,
    displayName: displayName ?? this.displayName,
    revision: revision ?? this.revision,
    fillAssetPath: fillAssetPath ?? this.fillAssetPath,
    top: top ?? this.top,
    leftWall: clearLeftWall ? null : leftWall ?? this.leftWall,
    rightWall: clearRightWall ? null : rightWall ?? this.rightWall,
    underside: clearUnderside ? null : underside ?? this.underside,
    topStartCap: clearTopStartCap ? null : topStartCap ?? this.topStartCap,
    topEndCap: clearTopEndCap ? null : topEndCap ?? this.topEndCap,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'displayName': displayName,
    'revision': revision,
    'fillAssetPath': fillAssetPath,
    'top': top.toJson(),
    if (leftWall case final leftWall?) 'leftWall': leftWall.toJson(),
    if (rightWall case final rightWall?) 'rightWall': rightWall.toJson(),
    if (underside case final underside?) 'underside': underside.toJson(),
    if (topStartCap case final topStartCap?)
      'topStartCap': topStartCap.toJson(),
    if (topEndCap case final topEndCap?) 'topEndCap': topEndCap.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is TerrainMaterialDefinition &&
      key == other.key &&
      displayName == other.displayName &&
      revision == other.revision &&
      fillAssetPath == other.fillAssetPath &&
      top == other.top &&
      leftWall == other.leftWall &&
      rightWall == other.rightWall &&
      underside == other.underside &&
      topStartCap == other.topStartCap &&
      topEndCap == other.topEndCap;

  @override
  int get hashCode => Object.hash(
    key,
    displayName,
    revision,
    fillAssetPath,
    top,
    leftWall,
    rightWall,
    underside,
    topStartCap,
    topEndCap,
  );
}

/// Canonically key-ordered terrain material source catalog.
final class TerrainMaterialCatalog {
  TerrainMaterialCatalog({
    required Iterable<TerrainMaterialDefinition> materials,
  }) : materials = List<TerrainMaterialDefinition>.unmodifiable(
         List<TerrainMaterialDefinition>.of(materials)
           ..sort((left, right) => left.key.compareTo(right.key)),
       );

  final List<TerrainMaterialDefinition> materials;

  Map<String, TerrainMaterialDefinition> get byKey =>
      Map<String, TerrainMaterialDefinition>.unmodifiable(
        <String, TerrainMaterialDefinition>{
          for (final material in materials) material.key: material,
        },
      );

  String toCanonicalJson() =>
      '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{'schemaVersion': terrainMaterialCatalogSchemaVersion, 'materials': materials.map((material) => material.toJson()).toList()})}\n';
}

/// Stable structural validation finding produced while decoding a catalog.
final class TerrainMaterialCatalogIssue
    implements Comparable<TerrainMaterialCatalogIssue> {
  const TerrainMaterialCatalogIssue({
    required this.code,
    required this.path,
    required this.message,
    this.materialKey,
  });

  final String code;
  final String path;
  final String message;
  final String? materialKey;

  @override
  int compareTo(TerrainMaterialCatalogIssue other) {
    final pathOrder = path.compareTo(other.path);
    if (pathOrder != 0) return pathOrder;
    return code.compareTo(other.code);
  }
}

/// Decode result that withholds a catalog whenever structural errors exist.
final class TerrainMaterialCatalogDecodeResult {
  const TerrainMaterialCatalogDecodeResult({
    required this.catalog,
    required this.issues,
  });

  final TerrainMaterialCatalog? catalog;
  final List<TerrainMaterialCatalogIssue> issues;
}

/// Strictly decodes and validates one terrain-material manifest.
///
/// Unknown fields, noncanonical identifiers/paths, duplicate keys, unpaired
/// caps, and invalid numeric anchors fail closed. File existence and image
/// dimensions remain repository-consumer checks because this package is pure
/// Dart and performs no I/O.
TerrainMaterialCatalogDecodeResult decodeTerrainMaterialCatalog(
  String source, {
  String sourcePath = 'terrain_material_defs.json',
}) {
  final issues = <TerrainMaterialCatalogIssue>[];
  Object? root;
  try {
    root = jsonDecode(source);
  } on Object catch (error) {
    return TerrainMaterialCatalogDecodeResult(
      catalog: null,
      issues: <TerrainMaterialCatalogIssue>[
        TerrainMaterialCatalogIssue(
          code: 'invalid_json',
          path: sourcePath,
          message: 'JSON parse error: $error',
        ),
      ],
    );
  }
  if (root is! Map<String, Object?>) {
    return TerrainMaterialCatalogDecodeResult(
      catalog: null,
      issues: <TerrainMaterialCatalogIssue>[
        TerrainMaterialCatalogIssue(
          code: 'invalid_root_type',
          path: sourcePath,
          message: 'Top-level JSON value must be an object.',
        ),
      ],
    );
  }
  _rejectUnknownKeys(
    root,
    const <String>{'schemaVersion', 'materials'},
    path: sourcePath,
    issues: issues,
  );
  if (root['schemaVersion'] != terrainMaterialCatalogSchemaVersion) {
    issues.add(
      TerrainMaterialCatalogIssue(
        code: 'invalid_schema_version',
        path: '$sourcePath.schemaVersion',
        message: 'schemaVersion must be $terrainMaterialCatalogSchemaVersion.',
      ),
    );
  }
  final entries = root['materials'];
  if (entries is! List<Object?>) {
    issues.add(
      TerrainMaterialCatalogIssue(
        code: 'invalid_materials_array',
        path: '$sourcePath.materials',
        message: 'materials must be an array.',
      ),
    );
    issues.sort();
    return TerrainMaterialCatalogDecodeResult(catalog: null, issues: issues);
  }

  final materials = <TerrainMaterialDefinition>[];
  final keys = <String>{};
  for (var index = 0; index < entries.length; index += 1) {
    final path = '$sourcePath.materials[$index]';
    final entry = entries[index];
    if (entry is! Map<String, Object?>) {
      issues.add(
        TerrainMaterialCatalogIssue(
          code: 'invalid_material_entry',
          path: path,
          message: 'Material entry must be an object.',
        ),
      );
      continue;
    }
    final material = _decodeMaterial(entry, path: path, issues: issues);
    if (material == null) continue;
    if (!keys.add(material.key)) {
      issues.add(
        TerrainMaterialCatalogIssue(
          code: 'duplicate_material_key',
          path: '$path.key',
          materialKey: material.key,
          message: 'Material key "${material.key}" is duplicated.',
        ),
      );
      continue;
    }
    materials.add(material);
  }
  issues.sort();
  return TerrainMaterialCatalogDecodeResult(
    catalog: issues.isEmpty
        ? TerrainMaterialCatalog(materials: materials)
        : null,
    issues: List<TerrainMaterialCatalogIssue>.unmodifiable(issues),
  );
}

TerrainMaterialDefinition? _decodeMaterial(
  Map<String, Object?> json, {
  required String path,
  required List<TerrainMaterialCatalogIssue> issues,
}) {
  _rejectUnknownKeys(
    json,
    const <String>{
      'key',
      'displayName',
      'revision',
      'fillAssetPath',
      'top',
      'leftWall',
      'rightWall',
      'underside',
      'topStartCap',
      'topEndCap',
    },
    path: path,
    issues: issues,
  );
  final issueCount = issues.length;
  final key = _requiredString(json['key'], '$path.key', issues);
  if (key != null && !_materialKeyPattern.hasMatch(key)) {
    issues.add(
      TerrainMaterialCatalogIssue(
        code: 'invalid_material_key',
        path: '$path.key',
        materialKey: key,
        message: 'Material keys must use lower_snake_case.',
      ),
    );
  }
  final displayName = _requiredString(
    json['displayName'],
    '$path.displayName',
    issues,
  );
  final revision = json['revision'];
  if (revision is! int || revision <= 0) {
    issues.add(
      TerrainMaterialCatalogIssue(
        code: 'invalid_revision',
        path: '$path.revision',
        materialKey: key,
        message: 'revision must be a positive integer.',
      ),
    );
  }
  final fillAssetPath = _assetPath(
    json['fillAssetPath'],
    '$path.fillAssetPath',
    key,
    issues,
  );
  final top = _edgeProfile(json['top'], '$path.top', key, issues);
  final leftWall = _optionalEdgeProfile(
    json['leftWall'],
    '$path.leftWall',
    key,
    issues,
  );
  final rightWall = _optionalEdgeProfile(
    json['rightWall'],
    '$path.rightWall',
    key,
    issues,
  );
  final underside = _optionalEdgeProfile(
    json['underside'],
    '$path.underside',
    key,
    issues,
  );
  final topStartCap = _optionalCap(
    json['topStartCap'],
    '$path.topStartCap',
    key,
    issues,
  );
  final topEndCap = _optionalCap(
    json['topEndCap'],
    '$path.topEndCap',
    key,
    issues,
  );
  if ((topStartCap == null) != (topEndCap == null)) {
    issues.add(
      TerrainMaterialCatalogIssue(
        code: 'unpaired_top_caps',
        path: path,
        materialKey: key,
        message: 'topStartCap and topEndCap must be configured together.',
      ),
    );
  }
  if (issues.length != issueCount ||
      key == null ||
      displayName == null ||
      revision is! int ||
      fillAssetPath == null ||
      top == null) {
    return null;
  }
  return TerrainMaterialDefinition(
    key: key,
    displayName: displayName,
    revision: revision,
    fillAssetPath: fillAssetPath,
    top: top,
    leftWall: leftWall,
    rightWall: rightWall,
    underside: underside,
    topStartCap: topStartCap,
    topEndCap: topEndCap,
  );
}

TerrainMaterialEdgeProfile? _optionalEdgeProfile(
  Object? value,
  String path,
  String? materialKey,
  List<TerrainMaterialCatalogIssue> issues,
) {
  if (value == null) return null;
  return _edgeProfile(value, path, materialKey, issues);
}

TerrainMaterialEdgeProfile? _edgeProfile(
  Object? value,
  String path,
  String? materialKey,
  List<TerrainMaterialCatalogIssue> issues,
) {
  if (value is! Map<String, Object?>) {
    issues.add(
      TerrainMaterialCatalogIssue(
        code: 'invalid_edge_profile',
        path: path,
        materialKey: materialKey,
        message: 'Edge profile must be an object.',
      ),
    );
    return null;
  }
  _rejectUnknownKeys(
    value,
    const <String>{'base', 'detail'},
    path: path,
    materialKey: materialKey,
    issues: issues,
  );
  final base = _edgeLayer(value['base'], '$path.base', materialKey, issues);
  final detail = value['detail'] == null
      ? null
      : _edgeLayer(value['detail'], '$path.detail', materialKey, issues);
  return base == null
      ? null
      : TerrainMaterialEdgeProfile(base: base, detail: detail);
}

TerrainMaterialEdgeLayer? _edgeLayer(
  Object? value,
  String path,
  String? materialKey,
  List<TerrainMaterialCatalogIssue> issues,
) {
  if (value is! Map<String, Object?>) {
    issues.add(
      TerrainMaterialCatalogIssue(
        code: 'invalid_edge_layer',
        path: path,
        materialKey: materialKey,
        message: 'Edge layer must be an object.',
      ),
    );
    return null;
  }
  _rejectUnknownKeys(
    value,
    const <String>{'assetPath', 'anchorY'},
    path: path,
    materialKey: materialKey,
    issues: issues,
  );
  final assetPath = _assetPath(
    value['assetPath'],
    '$path.assetPath',
    materialKey,
    issues,
  );
  final anchorY = _nonNegativeFiniteNumber(
    value['anchorY'],
    '$path.anchorY',
    materialKey,
    issues,
  );
  return assetPath == null || anchorY == null
      ? null
      : TerrainMaterialEdgeLayer(assetPath: assetPath, anchorY: anchorY);
}

TerrainMaterialCap? _optionalCap(
  Object? value,
  String path,
  String? materialKey,
  List<TerrainMaterialCatalogIssue> issues,
) {
  if (value == null) return null;
  if (value is! Map<String, Object?>) {
    issues.add(
      TerrainMaterialCatalogIssue(
        code: 'invalid_cap',
        path: path,
        materialKey: materialKey,
        message: 'Cap must be an object.',
      ),
    );
    return null;
  }
  _rejectUnknownKeys(
    value,
    const <String>{'assetPath', 'anchorX', 'anchorY'},
    path: path,
    materialKey: materialKey,
    issues: issues,
  );
  final assetPath = _assetPath(
    value['assetPath'],
    '$path.assetPath',
    materialKey,
    issues,
  );
  final anchorX = _nonNegativeFiniteNumber(
    value['anchorX'],
    '$path.anchorX',
    materialKey,
    issues,
  );
  final anchorY = _nonNegativeFiniteNumber(
    value['anchorY'],
    '$path.anchorY',
    materialKey,
    issues,
  );
  return assetPath == null || anchorX == null || anchorY == null
      ? null
      : TerrainMaterialCap(
          assetPath: assetPath,
          anchorX: anchorX,
          anchorY: anchorY,
        );
}

String? _requiredString(
  Object? value,
  String path,
  List<TerrainMaterialCatalogIssue> issues,
) {
  if (value is String && value.trim() == value && value.isNotEmpty)
    return value;
  issues.add(
    TerrainMaterialCatalogIssue(
      code: 'invalid_required_string',
      path: path,
      message: 'Value must be a non-empty string without outer whitespace.',
    ),
  );
  return null;
}

String? _assetPath(
  Object? value,
  String path,
  String? materialKey,
  List<TerrainMaterialCatalogIssue> issues,
) {
  if (value is String &&
      value == value.trim() &&
      !value.contains('..') &&
      !value.contains('\\') &&
      _assetPathPattern.hasMatch(value)) {
    return value;
  }
  issues.add(
    TerrainMaterialCatalogIssue(
      code: 'invalid_asset_path',
      path: path,
      materialKey: materialKey,
      message:
          'Asset paths must be normalized PNG paths under '
          'assets/images/terrain/.',
    ),
  );
  return null;
}

double? _nonNegativeFiniteNumber(
  Object? value,
  String path,
  String? materialKey,
  List<TerrainMaterialCatalogIssue> issues,
) {
  if (value is num && value.isFinite && value >= 0) return value.toDouble();
  issues.add(
    TerrainMaterialCatalogIssue(
      code: 'invalid_anchor',
      path: path,
      materialKey: materialKey,
      message: 'Anchor must be a finite non-negative number.',
    ),
  );
  return null;
}

void _rejectUnknownKeys(
  Map<String, Object?> json,
  Set<String> known, {
  required String path,
  required List<TerrainMaterialCatalogIssue> issues,
  String? materialKey,
}) {
  for (final key
      in json.keys.where((key) => !known.contains(key)).toList()..sort()) {
    issues.add(
      TerrainMaterialCatalogIssue(
        code: 'unknown_field',
        path: '$path.$key',
        materialKey: materialKey,
        message: 'Unknown field "$key".',
      ),
    );
  }
}

Object _canonicalNumber(double value) => value == value.roundToDouble()
    ? value.toInt()
    : double.parse(value.toStringAsFixed(6));
