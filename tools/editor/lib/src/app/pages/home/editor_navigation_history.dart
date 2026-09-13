import '../levelCreator/level_creator_navigation.dart';
import '../shared/editor_page_navigation_state.dart';

/// One visit to a tool, including any originating Level handoff context.
/// View locations contain stable IDs and UI values, never source snapshots.
class EditorNavigationLocation {
  const EditorNavigationLocation({
    required this.routeId,
    this.page,
    this.levelReturnContext,
  });

  final String routeId;
  final EditorPageLocation? page;
  final LevelCreatorReturnContext? levelReturnContext;
}

/// Session-only browser-style history and last location per editor tool.
///
/// Call [commit] only after a guarded destination load succeeds. Merely looking
/// up a destination never changes the cursor, so Cancel and load failures leave
/// both Back and Forward intact. Ordinary visits after Back truncate Forward.
class EditorNavigationHistory {
  EditorNavigationHistory(EditorNavigationLocation initial) {
    reset(initial);
  }

  // Bound retained view data during long authoring sessions.
  static const int maxVisits = 100;
  final List<EditorNavigationLocation> _visits = [];
  final Map<String, EditorNavigationLocation> _lastByRoute = {};
  int _index = 0;

  int get index => _index;
  bool get canGoBack => _index > 0;
  bool get canGoForward => _index + 1 < _visits.length;
  EditorNavigationLocation get current => _visits[_index];
  EditorNavigationLocation? get back => canGoBack ? _visits[_index - 1] : null;
  EditorNavigationLocation? get forward =>
      canGoForward ? _visits[_index + 1] : null;

  /// Finds an earlier origin for an explicit return action, keeping Forward.
  int? previousIndexWhere(bool Function(EditorNavigationLocation) matches) {
    for (var i = _index - 1; i >= 0; i--) {
      if (matches(_visits[i])) return i;
    }
    return null;
  }

  /// Normal tool selection resumes its last view without carrying a Level
  /// handoff banner from an unrelated journey.
  EditorNavigationLocation forRoute(String routeId) => EditorNavigationLocation(
    routeId: routeId,
    page: _lastByRoute[routeId]?.page,
  );

  /// Records the departing live view and an admitted destination atomically.
  /// [historyIndex] moves the cursor without adding another visit.
  void commit({
    required EditorNavigationLocation origin,
    required EditorNavigationLocation destination,
    int? historyIndex,
  }) {
    if (historyIndex != null &&
        (historyIndex < 0 || historyIndex >= _visits.length)) {
      throw RangeError.index(historyIndex, _visits);
    }
    _visits[_index] = origin;
    _lastByRoute[origin.routeId] = origin;
    if (historyIndex != null) {
      _index = historyIndex;
      _visits[_index] = destination;
    } else {
      _visits.removeRange(_index + 1, _visits.length);
      _visits.add(destination);
      if (_visits.length > maxVisits) _visits.removeAt(0);
      _index = _visits.length - 1;
    }
    _lastByRoute[destination.routeId] = destination;
  }

  /// A workspace change invalidates every remembered source identity.
  void reset(EditorNavigationLocation initial) {
    _visits
      ..clear()
      ..add(initial);
    _lastByRoute
      ..clear()
      ..[initial.routeId] = initial;
    _index = 0;
  }
}
