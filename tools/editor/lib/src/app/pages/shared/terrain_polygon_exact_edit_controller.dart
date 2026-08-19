import 'package:flutter/foundation.dart';

/// Coordinates save/discard requests with the currently mounted exact terrain
/// geometry editor.
///
/// Chunk authoring renders at most one exact editor at a time. Keeping the
/// pending field state in that editor avoids leaking text parsing into the
/// workspace while still letting selection changes protect unsaved values.
final class TerrainPolygonExactEditController extends ChangeNotifier {
  Object? _owner;
  bool Function()? _hasChanges;
  bool Function()? _save;
  void Function()? _discard;

  bool get hasEditor => _owner != null;

  bool get hasChanges => _hasChanges?.call() ?? false;

  bool save() => _save?.call() ?? true;

  void discard() => _discard?.call();

  /// Reports that the mounted editor's route-local text may have changed.
  void markChanged() => notifyListeners();

  void attach(
    Object owner, {
    required bool Function() hasChanges,
    required bool Function() save,
    required void Function() discard,
  }) {
    _owner = owner;
    _hasChanges = hasChanges;
    _save = save;
    _discard = discard;
  }

  void detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _hasChanges = null;
    _save = null;
    _discard = null;
  }
}
