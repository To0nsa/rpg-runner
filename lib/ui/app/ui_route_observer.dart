import 'package:flutter/widgets.dart';

/// Tracks the visible page independently of dialogs and removals below it.
class UiRouteObserver extends NavigatorObserver {
  UiRouteObserver({required this.onPageChanged, required this.onPageRemoved});

  final ValueChanged<String?> onPageChanged;
  final ValueChanged<String?> onPageRemoved;
  final List<Route<dynamic>> _routes = [];
  Route<dynamic>? _currentPage;

  void _update() {
    final page = _routes.whereType<PageRoute<dynamic>>().lastOrNull;
    if (identical(page, _currentPage)) return;
    _currentPage = page;
    onPageChanged(page?.settings.name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _update();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _remove(route);
  }

  void _remove(Route<dynamic> route) {
    _routes.remove(route);
    _update();
    if (route is PageRoute) onPageRemoved(route.settings.name);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    }
    _update();
    if (oldRoute is PageRoute) onPageRemoved(oldRoute.settings.name);
  }
}
