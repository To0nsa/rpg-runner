import 'package:flutter/foundation.dart';

import '../shared/model_json_utils.dart';
import '../shared/prefab_enums.dart';

/// Discriminated visual source reference for prefabs.
///
/// Exactly one reference id is populated based on [type]:
/// - [PrefabVisualSourceType.atlasSlice] -> [sliceId]
/// - [PrefabVisualSourceType.platformModule] -> [moduleId]
@immutable
class PrefabVisualSource {
  const PrefabVisualSource._({
    required this.type,
    this.sliceId = '',
    this.moduleId = '',
  });

  const PrefabVisualSource.atlasSlice(String sliceId)
    : this._(type: PrefabVisualSourceType.atlasSlice, sliceId: sliceId);

  const PrefabVisualSource.platformModule(String moduleId)
    : this._(type: PrefabVisualSourceType.platformModule, moduleId: moduleId);

  const PrefabVisualSource.unknown({String sliceId = '', String moduleId = ''})
    : this._(
        type: PrefabVisualSourceType.unknown,
        sliceId: sliceId,
        moduleId: moduleId,
      );

  final PrefabVisualSourceType type;
  final String sliceId;
  final String moduleId;

  bool get isAtlasSlice => type == PrefabVisualSourceType.atlasSlice;
  bool get isPlatformModule => type == PrefabVisualSourceType.platformModule;
  bool get isUnknown => type == PrefabVisualSourceType.unknown;

  String get atlasSliceId => isAtlasSlice ? sliceId : '';
  String get platformModuleId => isPlatformModule ? moduleId : '';
  String get referenceId => isAtlasSlice ? sliceId : moduleId;

  PrefabVisualSource copyWith({
    PrefabVisualSourceType? type,
    String? sliceId,
    String? moduleId,
  }) {
    final nextType = type ?? this.type;
    return PrefabVisualSource._(
      type: nextType,
      sliceId: nextType == PrefabVisualSourceType.atlasSlice
          ? (sliceId ?? this.sliceId)
          : '',
      moduleId: nextType == PrefabVisualSourceType.platformModule
          ? (moduleId ?? this.moduleId)
          : '',
    );
  }

  /// Serializes only the active reference field for the current [type].
  Map<String, Object?> toJson() {
    switch (type) {
      case PrefabVisualSourceType.atlasSlice:
        return <String, Object?>{'type': type.jsonValue, 'sliceId': sliceId};
      case PrefabVisualSourceType.platformModule:
        return <String, Object?>{'type': type.jsonValue, 'moduleId': moduleId};
      case PrefabVisualSourceType.unknown:
        return <String, Object?>{'type': type.jsonValue};
    }
  }

  /// Parses visual source payloads with backward compatibility for legacy
  /// `sliceId`-only prefab records.
  static PrefabVisualSource fromJson(Object? raw, {String legacySliceId = ''}) {
    final json = PrefabModelJson.asObjectMap(raw);
    if (json == null) {
      if (legacySliceId.isNotEmpty) {
        return PrefabVisualSource.atlasSlice(legacySliceId);
      }
      return const PrefabVisualSource.unknown();
    }

    final type = parsePrefabVisualSourceType(
      PrefabModelJson.normalizedString(json['type']),
    );
    switch (type) {
      case PrefabVisualSourceType.atlasSlice:
        final sliceId = PrefabModelJson.normalizedString(
          json['sliceId'],
          fallback: legacySliceId,
        );
        return PrefabVisualSource.atlasSlice(sliceId);
      case PrefabVisualSourceType.platformModule:
        return PrefabVisualSource.platformModule(
          PrefabModelJson.normalizedString(json['moduleId']),
        );
      case PrefabVisualSourceType.unknown:
        if (legacySliceId.isNotEmpty) {
          return PrefabVisualSource.atlasSlice(legacySliceId);
        }
        return const PrefabVisualSource.unknown();
    }
  }
}
