import 'dart:convert';

import 'terrain_material_render_math.dart';

const int terrainMaterialCatalogSchemaVersion = 3;

final RegExp _materialKeyPattern = RegExp(r'^[a-z][a-z0-9_]*$');
final RegExp _assetPathPattern = RegExp(
  r'^assets/images/terrain/[A-Za-z0-9_-]+(?:/[A-Za-z0-9_-]+)*\.png$',
);

/// Whether a path satisfies the canonical terrain-owned PNG policy.
bool isValidTerrainMaterialAssetPath(String value) =>
    value == value.trim() && _assetPathPattern.hasMatch(value);

/// Exact integer source rectangle inside one terrain-owned PNG.
final class TerrainMaterialImageRegion {
  const TerrainMaterialImageRegion({
    required this.assetPath,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final String assetPath;
  final int x;
  final int y;
  final int width;
  final int height;

  int get right => x + width;
  int get bottom => y + height;

  Map<String, Object?> toJson() => <String, Object?>{
    'assetPath': assetPath,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  @override
  bool operator ==(Object other) =>
      other is TerrainMaterialImageRegion &&
      assetPath == other.assetPath &&
      x == other.x &&
      y == other.y &&
      width == other.width &&
      height == other.height;

  @override
  int get hashCode => Object.hash(assetPath, x, y, width, height);
}

/// One world-facing atlas region repeated along a compiler-owned terrain edge.
final class TerrainMaterialEdgeLayer {
  const TerrainMaterialEdgeLayer({required this.region, required this.anchorY});

  final TerrainMaterialImageRegion region;

  /// Tangent-normalized Y coordinate aligned to the exact terrain edge.
  ///
  /// Wall regions swap source axes during normalization, so their valid range
  /// is the source width rather than its height.
  final double anchorY;

  Map<String, Object?> toJson() => <String, Object?>{
    'region': region.toJson(),
    'anchorY': _canonicalNumber(anchorY),
  };

  @override
  bool operator ==(Object other) =>
      other is TerrainMaterialEdgeLayer &&
      region == other.region &&
      anchorY == other.anchorY;

  @override
  int get hashCode => Object.hash(region, anchorY);
}

/// Ordered base/detail layers for one exposed-edge orientation.
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

/// One non-repeating atlas region anchored to an edge endpoint.
final class TerrainMaterialCap {
  const TerrainMaterialCap({
    required this.region,
    required this.anchorX,
    required this.anchorY,
  });

  final TerrainMaterialImageRegion region;
  final double anchorX;
  final double anchorY;

  Map<String, Object?> toJson() => <String, Object?>{
    'region': region.toJson(),
    'anchorX': _canonicalNumber(anchorX),
    'anchorY': _canonicalNumber(anchorY),
  };

  @override
  bool operator ==(Object other) =>
      other is TerrainMaterialCap &&
      region == other.region &&
      anchorX == other.anchorX &&
      anchorY == other.anchorY;

  @override
  int get hashCode => Object.hash(region, anchorX, anchorY);
}

/// Complete visual definition referenced by polygon `materialKey` metadata.
final class TerrainMaterialDefinition {
  const TerrainMaterialDefinition({
    required this.key,
    required this.displayName,
    required this.revision,
    required this.fill,
    required this.top,
    this.leftWall,
    this.rightWall,
    this.underside,
    this.topStartCap,
    this.topEndCap,
    this.undersideStartCap,
    this.undersideEndCap,
  });

  final String key;
  final String displayName;
  final int revision;
  final TerrainMaterialImageRegion fill;
  final TerrainMaterialEdgeProfile top;
  final TerrainMaterialEdgeProfile? leftWall;
  final TerrainMaterialEdgeProfile? rightWall;
  final TerrainMaterialEdgeProfile? underside;
  final TerrainMaterialCap? topStartCap;
  final TerrainMaterialCap? topEndCap;
  final TerrainMaterialCap? undersideStartCap;
  final TerrainMaterialCap? undersideEndCap;

  TerrainMaterialDefinition copyWith({
    String? key,
    String? displayName,
    int? revision,
    TerrainMaterialImageRegion? fill,
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
    TerrainMaterialCap? undersideStartCap,
    bool clearUndersideStartCap = false,
    TerrainMaterialCap? undersideEndCap,
    bool clearUndersideEndCap = false,
  }) => TerrainMaterialDefinition(
    key: key ?? this.key,
    displayName: displayName ?? this.displayName,
    revision: revision ?? this.revision,
    fill: fill ?? this.fill,
    top: top ?? this.top,
    leftWall: clearLeftWall ? null : leftWall ?? this.leftWall,
    rightWall: clearRightWall ? null : rightWall ?? this.rightWall,
    underside: clearUnderside ? null : underside ?? this.underside,
    topStartCap: clearTopStartCap ? null : topStartCap ?? this.topStartCap,
    topEndCap: clearTopEndCap ? null : topEndCap ?? this.topEndCap,
    undersideStartCap: clearUndersideStartCap
        ? null
        : undersideStartCap ?? this.undersideStartCap,
    undersideEndCap: clearUndersideEndCap
        ? null
        : undersideEndCap ?? this.undersideEndCap,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'displayName': displayName,
    'revision': revision,
    'fill': fill.toJson(),
    'top': top.toJson(),
    if (leftWall case final leftWall?) 'leftWall': leftWall.toJson(),
    if (rightWall case final rightWall?) 'rightWall': rightWall.toJson(),
    if (underside case final underside?) 'underside': underside.toJson(),
    if (topStartCap case final topStartCap?)
      'topStartCap': topStartCap.toJson(),
    if (topEndCap case final topEndCap?) 'topEndCap': topEndCap.toJson(),
    if (undersideStartCap case final undersideStartCap?)
      'undersideStartCap': undersideStartCap.toJson(),
    if (undersideEndCap case final undersideEndCap?)
      'undersideEndCap': undersideEndCap.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is TerrainMaterialDefinition &&
      key == other.key &&
      displayName == other.displayName &&
      revision == other.revision &&
      fill == other.fill &&
      top == other.top &&
      leftWall == other.leftWall &&
      rightWall == other.rightWall &&
      underside == other.underside &&
      topStartCap == other.topStartCap &&
      topEndCap == other.topEndCap &&
      undersideStartCap == other.undersideStartCap &&
      undersideEndCap == other.undersideEndCap;

  @override
  int get hashCode => Object.hash(
    key,
    displayName,
    revision,
    fill,
    top,
    leftWall,
    rightWall,
    underside,
    topStartCap,
    topEndCap,
    undersideStartCap,
    undersideEndCap,
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
    return pathOrder != 0 ? pathOrder : code.compareTo(other.code);
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

/// Pixel dimensions supplied by an I/O-owning catalog consumer.
final class TerrainMaterialImageDimensions {
  const TerrainMaterialImageDimensions({
    required this.width,
    required this.height,
  });

  final int width;
  final int height;
}

/// Returns complete region identities once in canonical role order.
List<TerrainMaterialImageRegion> terrainMaterialRegions(
  TerrainMaterialDefinition material,
) {
  final regions = <TerrainMaterialImageRegion>[];
  final seen = <TerrainMaterialImageRegion>{};
  void add(TerrainMaterialImageRegion region) {
    if (seen.add(region)) regions.add(region);
  }

  void addProfile(TerrainMaterialEdgeProfile? profile) {
    if (profile == null) return;
    add(profile.base.region);
    if (profile.detail case final detail?) add(detail.region);
  }

  add(material.fill);
  addProfile(material.top);
  addProfile(material.leftWall);
  addProfile(material.rightWall);
  addProfile(material.underside);
  if (material.topStartCap case final cap?) add(cap.region);
  if (material.topEndCap case final cap?) add(cap.region);
  if (material.undersideStartCap case final cap?) add(cap.region);
  if (material.undersideEndCap case final cap?) add(cap.region);
  return List<TerrainMaterialImageRegion>.unmodifiable(regions);
}

/// Returns unique source paths in deterministic lexical order.
List<String> terrainMaterialAssetPaths(TerrainMaterialDefinition material) =>
    (<String>{
      for (final region in terrainMaterialRegions(material)) region.assetPath,
    }.toList()..sort());

/// Validates source rectangles against consumer-supplied PNG dimensions.
List<TerrainMaterialCatalogIssue> validateTerrainMaterialImageDimensions(
  TerrainMaterialCatalog catalog, {
  required TerrainMaterialImageDimensions? Function(String assetPath)
  dimensionsFor,
}) {
  final issues = <TerrainMaterialCatalogIssue>[];
  for (final material in catalog.materials) {
    void validateRegion(String field, TerrainMaterialImageRegion region) {
      final dimensions = dimensionsFor(region.assetPath);
      if (dimensions == null) return;
      if (region.right <= dimensions.width &&
          region.bottom <= dimensions.height) {
        return;
      }
      issues.add(
        TerrainMaterialCatalogIssue(
          code: 'terrain_material_region_out_of_bounds',
          path: '${material.key}.$field.region',
          materialKey: material.key,
          message:
              'Region (${region.x}, ${region.y}, ${region.width}, '
              '${region.height}) exceeds image dimensions '
              '${dimensions.width}x${dimensions.height} for '
              '${region.assetPath}.',
        ),
      );
    }

    void validateLayer(String field, TerrainMaterialEdgeLayer layer) =>
        validateRegion(field, layer.region);

    void validateProfile(String field, TerrainMaterialEdgeProfile? profile) {
      if (profile == null) return;
      validateLayer('$field.base', profile.base);
      if (profile.detail case final detail?) {
        validateLayer('$field.detail', detail);
      }
    }

    validateRegion('fill', material.fill);
    validateProfile('top', material.top);
    validateProfile('leftWall', material.leftWall);
    validateProfile('rightWall', material.rightWall);
    validateProfile('underside', material.underside);
    if (material.topStartCap case final cap?) {
      validateRegion('topStartCap', cap.region);
    }
    if (material.topEndCap case final cap?) {
      validateRegion('topEndCap', cap.region);
    }
    if (material.undersideStartCap case final cap?) {
      validateRegion('undersideStartCap', cap.region);
    }
    if (material.undersideEndCap case final cap?) {
      validateRegion('undersideEndCap', cap.region);
    }
  }
  issues.sort();
  return List<TerrainMaterialCatalogIssue>.unmodifiable(issues);
}

/// Strictly decodes the v3 terrain-material manifest.
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
      'fill',
      'top',
      'leftWall',
      'rightWall',
      'underside',
      'topStartCap',
      'topEndCap',
      'undersideStartCap',
      'undersideEndCap',
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
  final fill = _region(json['fill'], '$path.fill', key, issues);
  final top = _edgeProfile(
    json['top'],
    '$path.top',
    key,
    TerrainMaterialEdgeOrientation.top,
    issues,
  );
  final leftWall = _optionalEdgeProfile(
    json['leftWall'],
    '$path.leftWall',
    key,
    TerrainMaterialEdgeOrientation.leftWall,
    issues,
  );
  final rightWall = _optionalEdgeProfile(
    json['rightWall'],
    '$path.rightWall',
    key,
    TerrainMaterialEdgeOrientation.rightWall,
    issues,
  );
  final underside = _optionalEdgeProfile(
    json['underside'],
    '$path.underside',
    key,
    TerrainMaterialEdgeOrientation.underside,
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
  final undersideStartCap = _optionalCap(
    json['undersideStartCap'],
    '$path.undersideStartCap',
    key,
    issues,
  );
  final undersideEndCap = _optionalCap(
    json['undersideEndCap'],
    '$path.undersideEndCap',
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
  if ((undersideStartCap == null) != (undersideEndCap == null)) {
    issues.add(
      TerrainMaterialCatalogIssue(
        code: 'unpaired_underside_caps',
        path: path,
        materialKey: key,
        message:
            'undersideStartCap and undersideEndCap must be configured together.',
      ),
    );
  }
  if (underside == null &&
      (undersideStartCap != null || undersideEndCap != null)) {
    issues.add(
      TerrainMaterialCatalogIssue(
        code: 'underside_caps_without_profile',
        path: path,
        materialKey: key,
        message: 'Underside caps require an underside edge profile.',
      ),
    );
  }
  if (issues.length != issueCount ||
      key == null ||
      displayName == null ||
      revision is! int ||
      fill == null ||
      top == null) {
    return null;
  }
  return TerrainMaterialDefinition(
    key: key,
    displayName: displayName,
    revision: revision,
    fill: fill,
    top: top,
    leftWall: leftWall,
    rightWall: rightWall,
    underside: underside,
    topStartCap: topStartCap,
    topEndCap: topEndCap,
    undersideStartCap: undersideStartCap,
    undersideEndCap: undersideEndCap,
  );
}

TerrainMaterialEdgeProfile? _optionalEdgeProfile(
  Object? value,
  String path,
  String? materialKey,
  TerrainMaterialEdgeOrientation orientation,
  List<TerrainMaterialCatalogIssue> issues,
) => value == null
    ? null
    : _edgeProfile(value, path, materialKey, orientation, issues);

TerrainMaterialEdgeProfile? _edgeProfile(
  Object? value,
  String path,
  String? materialKey,
  TerrainMaterialEdgeOrientation orientation,
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
  final base = _edgeLayer(
    value['base'],
    '$path.base',
    materialKey,
    orientation,
    issues,
  );
  final detail = value['detail'] == null
      ? null
      : _edgeLayer(
          value['detail'],
          '$path.detail',
          materialKey,
          orientation,
          issues,
        );
  return base == null
      ? null
      : TerrainMaterialEdgeProfile(base: base, detail: detail);
}

TerrainMaterialEdgeLayer? _edgeLayer(
  Object? value,
  String path,
  String? materialKey,
  TerrainMaterialEdgeOrientation orientation,
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
    const <String>{'region', 'anchorY'},
    path: path,
    materialKey: materialKey,
    issues: issues,
  );
  final region = _region(value['region'], '$path.region', materialKey, issues);
  final anchorY = _nonNegativeFiniteNumber(
    value['anchorY'],
    '$path.anchorY',
    materialKey,
    issues,
  );
  final anchorLimit = region == null
      ? null
      : terrainMaterialEdgeTileHeight(
          orientation: orientation,
          sourceWidth: region.width,
          sourceHeight: region.height,
        );
  if (anchorLimit != null && anchorY != null && anchorY > anchorLimit) {
    issues.add(
      TerrainMaterialCatalogIssue(
        code: 'terrain_material_anchor_out_of_bounds',
        path: '$path.anchorY',
        materialKey: materialKey,
        message: 'anchorY must be within [0, $anchorLimit].',
      ),
    );
  }
  return region == null || anchorY == null
      ? null
      : TerrainMaterialEdgeLayer(region: region, anchorY: anchorY);
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
    const <String>{'region', 'anchorX', 'anchorY'},
    path: path,
    materialKey: materialKey,
    issues: issues,
  );
  final region = _region(value['region'], '$path.region', materialKey, issues);
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
  if (region != null &&
      anchorX != null &&
      anchorY != null &&
      (anchorX > region.width || anchorY > region.height)) {
    issues.add(
      TerrainMaterialCatalogIssue(
        code: 'terrain_material_anchor_out_of_bounds',
        path: path,
        materialKey: materialKey,
        message:
            'Cap anchors must be within [0, ${region.width}] and '
            '[0, ${region.height}].',
      ),
    );
  }
  return region == null || anchorX == null || anchorY == null
      ? null
      : TerrainMaterialCap(region: region, anchorX: anchorX, anchorY: anchorY);
}

TerrainMaterialImageRegion? _region(
  Object? value,
  String path,
  String? materialKey,
  List<TerrainMaterialCatalogIssue> issues,
) {
  if (value is! Map<String, Object?>) {
    issues.add(
      TerrainMaterialCatalogIssue(
        code: 'invalid_region',
        path: path,
        materialKey: materialKey,
        message: 'Image region must be an object.',
      ),
    );
    return null;
  }
  _rejectUnknownKeys(
    value,
    const <String>{'assetPath', 'x', 'y', 'width', 'height'},
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
  final x = _integer(value['x'], '$path.x', materialKey, issues, minimum: 0);
  final y = _integer(value['y'], '$path.y', materialKey, issues, minimum: 0);
  final width = _integer(
    value['width'],
    '$path.width',
    materialKey,
    issues,
    minimum: 1,
  );
  final height = _integer(
    value['height'],
    '$path.height',
    materialKey,
    issues,
    minimum: 1,
  );
  return assetPath == null ||
          x == null ||
          y == null ||
          width == null ||
          height == null
      ? null
      : TerrainMaterialImageRegion(
          assetPath: assetPath,
          x: x,
          y: y,
          width: width,
          height: height,
        );
}

String? _requiredString(
  Object? value,
  String path,
  List<TerrainMaterialCatalogIssue> issues,
) {
  if (value is String && value.trim() == value && value.isNotEmpty) {
    return value;
  }
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
  if (value is String && isValidTerrainMaterialAssetPath(value)) return value;
  issues.add(
    TerrainMaterialCatalogIssue(
      code: 'invalid_asset_path',
      path: path,
      materialKey: materialKey,
      message:
          'Asset paths must be normalized lowercase-extension PNG paths '
          'beneath assets/images/terrain/.',
    ),
  );
  return null;
}

int? _integer(
  Object? value,
  String path,
  String? materialKey,
  List<TerrainMaterialCatalogIssue> issues, {
  required int minimum,
}) {
  if (value is int && value >= minimum) return value;
  issues.add(
    TerrainMaterialCatalogIssue(
      code: 'invalid_region_coordinate',
      path: path,
      materialKey: materialKey,
      message: 'Value must be an integer greater than or equal to $minimum.',
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
