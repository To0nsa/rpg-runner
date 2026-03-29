import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'prefab_models.dart';

class PrefabStore {
  static const String prefabDefsPath = 'assets/authoring/level/prefab_defs.json';
  static const String tileDefsPath = 'assets/authoring/level/tile_defs.json';

  const PrefabStore();

  Future<PrefabData> load(String workspaceRootPath) async {
    final prefabFile = File(p.normalize(p.join(workspaceRootPath, prefabDefsPath)));
    final tileFile = File(p.normalize(p.join(workspaceRootPath, tileDefsPath)));

    final prefabSlices = <AtlasSliceDef>[];
    final prefabs = <PrefabDef>[];
    final tileSlices = <AtlasSliceDef>[];
    final platformModules = <TileModuleDef>[];
    var schemaVersion = 1;

    if (prefabFile.existsSync()) {
      final parsed = _parseJsonMap(prefabFile.readAsStringSync());
      schemaVersion = _intOrDefault(parsed['schemaVersion'], fallback: schemaVersion);
      final rawPrefabSlices = parsed['slices'];
      if (rawPrefabSlices is List<Object?>) {
        prefabSlices.addAll(_parseSlices(rawPrefabSlices));
      }
      final rawPrefabs = parsed['prefabs'];
      if (rawPrefabs is List<Object?>) {
        for (final value in rawPrefabs) {
          if (value is Map<String, Object?>) {
            final prefab = PrefabDef.fromJson(value);
            if (prefab.id.isNotEmpty) {
              prefabs.add(prefab);
            }
          }
        }
      }
    }

    if (tileFile.existsSync()) {
      final parsed = _parseJsonMap(tileFile.readAsStringSync());
      schemaVersion = _intOrDefault(parsed['schemaVersion'], fallback: schemaVersion);
      final rawTileSlices = parsed['tileSlices'];
      if (rawTileSlices is List<Object?>) {
        tileSlices.addAll(_parseSlices(rawTileSlices));
      }
      final rawModules = parsed['platformModules'];
      if (rawModules is List<Object?>) {
        for (final value in rawModules) {
          if (value is Map<String, Object?>) {
            final module = TileModuleDef.fromJson(value);
            if (module.id.isNotEmpty) {
              platformModules.add(module);
            }
          }
        }
      }
    }

    return PrefabData(
      schemaVersion: schemaVersion,
      prefabSlices: _sortedSlices(prefabSlices),
      tileSlices: _sortedSlices(tileSlices),
      prefabs: _sortedPrefabs(prefabs),
      platformModules: _sortedModules(platformModules),
    );
  }

  Future<void> save(
    String workspaceRootPath, {
    required PrefabData data,
  }) async {
    final prefabFile = File(p.normalize(p.join(workspaceRootPath, prefabDefsPath)));
    final tileFile = File(p.normalize(p.join(workspaceRootPath, tileDefsPath)));

    if (!prefabFile.parent.existsSync()) {
      prefabFile.parent.createSync(recursive: true);
    }
    if (!tileFile.parent.existsSync()) {
      tileFile.parent.createSync(recursive: true);
    }

    final sortedPrefabSlices = _sortedSlices(data.prefabSlices);
    final sortedTileSlices = _sortedSlices(data.tileSlices);
    final sortedPrefabs = _sortedPrefabs(data.prefabs);
    final sortedModules = _sortedModules(data.platformModules);

    final prefabJson = <String, Object?>{
      'schemaVersion': data.schemaVersion,
      'slices': sortedPrefabSlices.map((s) => s.toJson()).toList(growable: false),
      'prefabs': sortedPrefabs.map((p) => p.toJson()).toList(growable: false),
    };

    final tileJson = <String, Object?>{
      'schemaVersion': data.schemaVersion,
      'tileSlices': sortedTileSlices.map((s) => s.toJson()).toList(growable: false),
      'platformModules': sortedModules.map((m) => m.toJson()).toList(growable: false),
    };

    const encoder = JsonEncoder.withIndent('  ');
    prefabFile.writeAsStringSync('${encoder.convert(prefabJson)}\n');
    tileFile.writeAsStringSync('${encoder.convert(tileJson)}\n');
  }

  List<AtlasSliceDef> _parseSlices(List<Object?> raw) {
    final slices = <AtlasSliceDef>[];
    for (final value in raw) {
      if (value is! Map<String, Object?>) {
        continue;
      }
      final slice = AtlasSliceDef.fromJson(value);
      if (slice.id.isEmpty) {
        continue;
      }
      slices.add(slice);
    }
    return slices;
  }

  Map<String, Object?> _parseJsonMap(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    return const <String, Object?>{};
  }

  int _intOrDefault(Object? raw, {required int fallback}) {
    if (raw is num) {
      return raw.toInt();
    }
    return fallback;
  }

  List<AtlasSliceDef> _sortedSlices(List<AtlasSliceDef> slices) {
    final sorted = List<AtlasSliceDef>.from(slices)
      ..sort((a, b) {
        final idCompare = a.id.compareTo(b.id);
        if (idCompare != 0) {
          return idCompare;
        }
        final sourceCompare = a.sourceImagePath.compareTo(b.sourceImagePath);
        if (sourceCompare != 0) {
          return sourceCompare;
        }
        final yCompare = a.y.compareTo(b.y);
        if (yCompare != 0) {
          return yCompare;
        }
        return a.x.compareTo(b.x);
      });
    return sorted;
  }

  List<PrefabDef> _sortedPrefabs(List<PrefabDef> prefabs) {
    final normalized = prefabs
        .map((prefab) => prefab.copyWith(tags: _sortedTags(prefab.tags)))
        .toList(growable: false);
    final sorted = List<PrefabDef>.from(normalized)
      ..sort((a, b) => a.id.compareTo(b.id));
    return sorted;
  }

  List<String> _sortedTags(List<String> tags) {
    final normalized = tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    return normalized;
  }

  List<TileModuleDef> _sortedModules(List<TileModuleDef> modules) {
    final normalized = modules.map((module) {
      final sortedCells = List<TileModuleCellDef>.from(module.cells)
        ..sort((a, b) {
          final yCompare = a.gridY.compareTo(b.gridY);
          if (yCompare != 0) {
            return yCompare;
          }
          final xCompare = a.gridX.compareTo(b.gridX);
          if (xCompare != 0) {
            return xCompare;
          }
          return a.sliceId.compareTo(b.sliceId);
        });
      return module.copyWith(cells: sortedCells);
    }).toList(growable: false);

    final sorted = List<TileModuleDef>.from(normalized)
      ..sort((a, b) => a.id.compareTo(b.id));
    return sorted;
  }
}
