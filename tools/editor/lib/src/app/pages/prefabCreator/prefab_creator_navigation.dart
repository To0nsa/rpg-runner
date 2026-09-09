import 'package:flutter/foundation.dart';

/// Prefab Creator surface requested by another authoring workspace.
enum PrefabCreatorDestination { prefab, atlas, collision }

/// Stable cross-route target for opening one prefab in a specific workflow.
@immutable
class PrefabCreatorTarget {
  const PrefabCreatorTarget({
    required this.prefabKey,
    required this.destination,
  });

  final String prefabKey;
  final PrefabCreatorDestination destination;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrefabCreatorTarget &&
          prefabKey == other.prefabKey &&
          destination == other.destination;

  @override
  int get hashCode => Object.hash(prefabKey, destination);
}
