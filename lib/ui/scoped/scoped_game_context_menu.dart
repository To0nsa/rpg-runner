import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Serializes browser menu overrides and restores the pre-game setting when the
/// last host leaves. Injected browser operations keep lifecycle races testable
/// without a web renderer or a global platform override.
final class BrowserContextMenuLeases {
  BrowserContextMenuLeases({
    required this.isEnabled,
    required this.disable,
    required this.enable,
    required this.onError,
  });

  final bool Function() isEnabled;
  final Future<void> Function() disable;
  final Future<void> Function() enable;
  final void Function(Object) onError;
  int _leases = 0;
  bool _restoreEnabled = true;
  Future<void> _pending = Future<void>.value();

  /// Completes after the overrides already queued at the time of access.
  Future<void> get settled => _pending;

  /// Acquires suppression immediately and returns an idempotent release callback.
  /// Async browser operations execute in lease-transition order.
  VoidCallback acquire() {
    if (_leases++ == 0) {
      _enqueue(() async {
        _restoreEnabled = isEnabled();
        await disable();
      });
    }
    var released = false;
    return () {
      if (released) return;
      released = true;
      if (--_leases == 0) {
        _enqueue(() async {
          if (_restoreEnabled) await enable();
        });
      }
    };
  }

  void _enqueue(Future<void> Function() change) {
    _pending = _pending.then((_) => change()).catchError(onError);
  }
}

/// Suppresses browser right-click menus while a desktop game is mounted.
/// Overlapping hosts share leases; native platforms perform no browser calls.
class ScopedGameContextMenu extends StatefulWidget {
  const ScopedGameContextMenu({
    super.key,
    required this.child,
    required this.enabled,
  });

  final Widget child;
  final bool enabled;

  @override
  State<ScopedGameContextMenu> createState() => _ScopedGameContextMenuState();
}

class _ScopedGameContextMenuState extends State<ScopedGameContextMenu> {
  static final _leases = BrowserContextMenuLeases(
    isEnabled: () => BrowserContextMenu.enabled,
    disable: BrowserContextMenu.disableContextMenu,
    enable: BrowserContextMenu.enableContextMenu,
    onError: (error) =>
        debugPrint('Browser game context menu update failed: $error'),
  );
  VoidCallback? _release;

  @override
  void initState() {
    super.initState();
    if (kIsWeb && widget.enabled) _release = _leases.acquire();
  }

  @override
  void didUpdateWidget(covariant ScopedGameContextMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled == widget.enabled) return;
    _release?.call();
    _release = kIsWeb && widget.enabled ? _leases.acquire() : null;
  }

  @override
  void dispose() {
    _release?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
