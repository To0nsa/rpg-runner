part of 'prefab_validation.dart';

/// Deterministic issue ordering for stable UI/test outputs.
int _compareIssues(PrefabValidationIssue a, PrefabValidationIssue b) {
  final sourcePathCompare = a.sourcePath.compareTo(b.sourcePath);
  if (sourcePathCompare != 0) return sourcePathCompare;
  final ownerKeyCompare = (a.ownerKey ?? '').compareTo(b.ownerKey ?? '');
  if (ownerKeyCompare != 0) return ownerKeyCompare;
  final shapeIdCompare = a.shapeId.compareTo(b.shapeId);
  if (shapeIdCompare != 0) return shapeIdCompare;
  final elementIndexCompare = a.elementIndex.compareTo(b.elementIndex);
  if (elementIndexCompare != 0) return elementIndexCompare;
  final codeCompare = a.code.compareTo(b.code);
  return codeCompare != 0 ? codeCompare : a.message.compareTo(b.message);
}
