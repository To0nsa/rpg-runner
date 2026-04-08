import 'package:flutter/foundation.dart';

import '../shared/model_json_utils.dart';
import '../shared/prefab_enums.dart';
import 'tile_module_cell_def.dart';

/// Authoring definition for reusable platform tile modules.
///
/// [tileSize] is expressed in pixels and defines the grid step for [cells].
@immutable
class TileModuleDef {
  const TileModuleDef({
    required this.id,
    this.revision = 1,
    this.status = TileModuleStatus.active,
    required this.tileSize,
    required this.cells,
  });

  final String id;
  final int revision;
  final TileModuleStatus status;
  final int tileSize;
  final List<TileModuleCellDef> cells;

  TileModuleDef copyWith({
    String? id,
    int? revision,
    TileModuleStatus? status,
    int? tileSize,
    List<TileModuleCellDef>? cells,
  }) {
    return TileModuleDef(
      id: id ?? this.id,
      revision: revision ?? this.revision,
      status: status ?? this.status,
      tileSize: tileSize ?? this.tileSize,
      cells: cells ?? this.cells,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'revision': revision,
      'status': status.jsonValue,
      'tileSize': tileSize,
      'cells': cells.map((c) => c.toJson()).toList(growable: false),
    };
  }

  static TileModuleDef fromJson(Map<String, Object?> json) {
    final rawCells = json['cells'];
    final cells = <TileModuleCellDef>[];
    if (rawCells is List<Object?>) {
      for (final value in rawCells) {
        final cellJson = PrefabModelJson.asObjectMap(value);
        if (cellJson == null) {
          continue;
        }
        cells.add(TileModuleCellDef.fromJson(cellJson));
      }
    }
    return TileModuleDef(
      id: PrefabModelJson.normalizedString(json['id']),
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      status: parseTileModuleStatus(
        PrefabModelJson.normalizedString(json['status']),
      ),
      tileSize: (json['tileSize'] as num?)?.toInt() ?? 16,
      cells: cells,
    );
  }
}
