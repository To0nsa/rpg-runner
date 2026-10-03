import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/app/ui_route_observer.dart';

void main() {
  test('removing and replacing covered routes preserves the current page', () {
    final changes = <String?>[];
    final removals = <String?>[];
    final observer = UiRouteObserver(
      onPageChanged: changes.add,
      onPageRemoved: removals.add,
    );
    MaterialPageRoute<void> route(String name) => MaterialPageRoute(
      settings: RouteSettings(name: name),
      builder: (_) => const SizedBox.shrink(),
    );
    final first = route('/first');
    final second = route('/second');
    final third = route('/third');
    final replacement = route('/replacement');
    observer.didPush(first, null);
    observer.didPush(second, first);
    observer.didPush(third, second);
    observer.didRemove(first, null);
    observer.didReplace(oldRoute: second, newRoute: replacement);
    expect(changes, ['/first', '/second', '/third']);
    observer.didPop(third, replacement);
    expect(changes.last, '/replacement');
    expect(removals, ['/first', '/second', '/third']);
  });
}
