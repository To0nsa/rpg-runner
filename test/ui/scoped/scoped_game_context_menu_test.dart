import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/scoped/scoped_game_context_menu.dart';

void main() {
  test(
    'overlapping hosts restore the menu only after the final release',
    () async {
      final browser = _Browser();
      final first = browser.leases.acquire();
      final second = browser.leases.acquire();
      await browser.leases.settled;
      expect(browser.enabled, isFalse);
      expect(browser.calls, ['disable']);
      first();
      first();
      await browser.leases.settled;
      expect(browser.calls, ['disable']);
      second();
      await browser.leases.settled;
      expect(browser.enabled, isTrue);
      expect(browser.calls, ['disable', 'enable']);
    },
  );

  test('a menu disabled before gameplay remains disabled', () async {
    final browser = _Browser()..enabled = false;
    final release = browser.leases.acquire();
    release();
    await browser.leases.settled;
    expect(browser.enabled, isFalse);
    expect(browser.calls, ['disable']);
  });

  test(
    'disposing during suppression restores after suppression completes',
    () async {
      final browser = _Browser()..pendingDisable = Completer<void>();
      final release = browser.leases.acquire();
      release();
      await Future<void>.delayed(Duration.zero);
      expect(browser.calls, ['disable']);
      browser.pendingDisable!.complete();
      await browser.leases.settled;
      expect(browser.enabled, isTrue);
      expect(browser.calls, ['disable', 'enable']);
    },
  );

  test(
    'rapid replacement captures the setting after pending restoration',
    () async {
      final browser = _Browser();
      final first = browser.leases.acquire();
      first();
      final second = browser.leases.acquire();
      await browser.leases.settled;
      expect(browser.enabled, isFalse);
      second();
      await browser.leases.settled;
      expect(browser.enabled, isTrue);
      expect(browser.calls, ['disable', 'enable', 'disable', 'enable']);
    },
  );
}

class _Browser {
  bool enabled = true;
  final calls = <String>[];
  Completer<void>? pendingDisable;
  late final leases = BrowserContextMenuLeases(
    isEnabled: () => enabled,
    disable: () async {
      calls.add('disable');
      if (pendingDisable != null) await pendingDisable!.future;
      enabled = false;
    },
    enable: () async {
      calls.add('enable');
      enabled = true;
    },
    onError: (error) => fail('$error'),
  );
}
