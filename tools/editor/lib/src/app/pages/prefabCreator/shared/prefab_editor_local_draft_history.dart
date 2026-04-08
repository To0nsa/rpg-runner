import 'package:flutter/material.dart';

import 'prefab_editor_page_contracts.dart';

/// Owns page-local draft history for the prefab authoring page.
///
/// This controller keeps text-field listeners, suppression state, undo/redo
/// stacks, and the baseline snapshot together so workflow logic does not need
/// to coordinate that state manually.
class PrefabEditorLocalDraftHistory<T> {
  PrefabEditorLocalDraftHistory({
    required Iterable<TextEditingController> trackedControllers,
    required T Function() captureSnapshot,
    required void Function(T snapshot) restoreSnapshot,
    required PrefabEditorStateSetter updateState,
    required bool Function() isMounted,
  }) : _trackedControllers = trackedControllers.toList(growable: false),
       _captureSnapshot = captureSnapshot,
       _restoreSnapshot = restoreSnapshot,
       _updateState = updateState,
       _isMounted = isMounted;

  final List<TextEditingController> _trackedControllers;
  final T Function() _captureSnapshot;
  final void Function(T snapshot) _restoreSnapshot;
  final PrefabEditorStateSetter _updateState;
  final bool Function() _isMounted;

  final List<T> _undoStack = <T>[];
  final List<T> _redoStack = <T>[];

  late T _baselineSnapshot;
  late T _lastObservedSnapshot;
  bool _hasBaseline = false;
  bool _suppressTracking = false;
  bool _refreshScheduled = false;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  bool get hasChanges {
    if (!_hasBaseline) {
      return false;
    }
    return _captureSnapshot() != _baselineSnapshot;
  }

  void installListeners() {
    for (final controller in _trackedControllers) {
      controller.addListener(_handleTrackedControllerChanged);
    }
  }

  void dispose() {
    for (final controller in _trackedControllers) {
      controller.removeListener(_handleTrackedControllerChanged);
    }
  }

  void syncBaseline() {
    final snapshot = _captureSnapshot();
    _baselineSnapshot = snapshot;
    _lastObservedSnapshot = snapshot;
    _hasBaseline = true;
    _undoStack.clear();
    _redoStack.clear();
  }

  void runWithoutTracking(VoidCallback callback) {
    final previous = _suppressTracking;
    _suppressTracking = true;
    try {
      callback();
    } finally {
      _suppressTracking = previous;
    }
  }

  void applyMutation(VoidCallback callback) {
    final previousSnapshot = _captureSnapshot();
    runWithoutTracking(callback);
    final nextSnapshot = _captureSnapshot();
    if (nextSnapshot == previousSnapshot) {
      _lastObservedSnapshot = nextSnapshot;
      return;
    }
    _undoStack.add(previousSnapshot);
    _redoStack.clear();
    _lastObservedSnapshot = nextSnapshot;
  }

  bool undo({
    required BuildContext context,
    required VoidCallback afterRestore,
  }) {
    if (_undoStack.isEmpty) {
      return false;
    }
    FocusScope.of(context).unfocus();
    final currentSnapshot = _captureSnapshot();
    final previousSnapshot = _undoStack.removeLast();
    _redoStack.add(currentSnapshot);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isMounted()) {
        return;
      }
      _updateState(() {
        _restoreSnapshot(previousSnapshot);
        _lastObservedSnapshot = previousSnapshot;
        afterRestore();
      });
    });
    WidgetsBinding.instance.scheduleFrame();
    return true;
  }

  bool redo({
    required BuildContext context,
    required VoidCallback afterRestore,
  }) {
    if (_redoStack.isEmpty) {
      return false;
    }
    FocusScope.of(context).unfocus();
    final currentSnapshot = _captureSnapshot();
    final nextSnapshot = _redoStack.removeLast();
    _undoStack.add(currentSnapshot);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isMounted()) {
        return;
      }
      _updateState(() {
        _restoreSnapshot(nextSnapshot);
        _lastObservedSnapshot = nextSnapshot;
        afterRestore();
      });
    });
    WidgetsBinding.instance.scheduleFrame();
    return true;
  }

  void _handleTrackedControllerChanged() {
    if (_suppressTracking || !_hasBaseline) {
      return;
    }
    final nextSnapshot = _captureSnapshot();
    if (nextSnapshot == _lastObservedSnapshot) {
      return;
    }
    _undoStack.add(_lastObservedSnapshot);
    _redoStack.clear();
    _lastObservedSnapshot = nextSnapshot;
    _scheduleRefresh();
  }

  void _scheduleRefresh() {
    if (_refreshScheduled || !_isMounted()) {
      return;
    }
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (!_isMounted()) {
        return;
      }
      _updateState(() {});
    });
  }
}
