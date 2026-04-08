import 'package:flutter/foundation.dart';

import '../shared/model_json_utils.dart';

/// One tile placement inside a platform module definition.
///
/// [gridX]/[gridY] are module-local grid coordinates in `tileSize` units.
@immutable
class TileModuleCellDef {
  const TileModuleCellDef({
    required this.sliceId,
    required this.gridX,
    required this.gridY,
  });

  final String sliceId;
  final int gridX;
  final int gridY;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'sliceId': sliceId,
      'gridX': gridX,
      'gridY': gridY,
    };
  }

  static TileModuleCellDef fromJson(Map<String, Object?> json) {
    return TileModuleCellDef(
      sliceId: PrefabModelJson.normalizedString(json['sliceId']),
      gridX: (json['gridX'] as num?)?.toInt() ?? 0,
      gridY: (json['gridY'] as num?)?.toInt() ?? 0,
    );
  }
}
