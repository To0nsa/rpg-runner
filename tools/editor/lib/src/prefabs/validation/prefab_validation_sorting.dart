part of 'prefab_validation.dart';

/// Deterministic issue ordering for stable UI/test outputs.
int _compareIssues(PrefabValidationIssue a, PrefabValidationIssue b) {
  final codeCompare = a.code.compareTo(b.code);
  if (codeCompare != 0) {
    return codeCompare;
  }
  return a.message.compareTo(b.message);
}

/// Canonical slice sort key for validation passes.
int _compareSlices(AtlasSliceDef a, AtlasSliceDef b) {
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
  final xCompare = a.x.compareTo(b.x);
  if (xCompare != 0) {
    return xCompare;
  }
  final widthCompare = a.width.compareTo(b.width);
  if (widthCompare != 0) {
    return widthCompare;
  }
  final heightCompare = a.height.compareTo(b.height);
  if (heightCompare != 0) {
    return heightCompare;
  }
  final lengthCompare = a.tags.length.compareTo(b.tags.length);
  if (lengthCompare != 0) {
    return lengthCompare;
  }
  for (var i = 0; i < a.tags.length; i += 1) {
    final tagCompare = a.tags[i].compareTo(b.tags[i]);
    if (tagCompare != 0) {
      return tagCompare;
    }
  }
  return 0;
}

/// Canonical prefab sort key for validation passes.
int _comparePrefabs(PrefabDef a, PrefabDef b) {
  final idCompare = a.id.compareTo(b.id);
  if (idCompare != 0) {
    return idCompare;
  }
  return a.prefabKey.compareTo(b.prefabKey);
}

/// Canonical module-cell sort key for duplicate-position detection.
int _compareModuleCells(TileModuleCellDef a, TileModuleCellDef b) {
  final yCompare = a.gridY.compareTo(b.gridY);
  if (yCompare != 0) {
    return yCompare;
  }
  final xCompare = a.gridX.compareTo(b.gridX);
  if (xCompare != 0) {
    return xCompare;
  }
  return a.sliceId.compareTo(b.sliceId);
}
