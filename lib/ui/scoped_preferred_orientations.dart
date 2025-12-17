import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Applies `SystemChrome.setPreferredOrientations` while this widget is mounted.
///
/// This is intentionally scoped to a subtree (typically a route) so the runner
/// can be embedded in a host app without enforcing a global orientation policy.
///
/// Notes:
/// - Flutter does not expose the *previous* preferred orientations, so the
///   caller must decide what to restore on dispose.
/// - Platform-level orientation support (Android manifest / iOS Info.plist)
///   still needs to include the requested orientations.
class ScopedPreferredOrientations extends StatefulWidget {
  const ScopedPreferredOrientations({
    super.key,
    required this.preferredOrientations,
    required this.child,
    this.restoreOrientations,
  });

  final List<DeviceOrientation> preferredOrientations;
  final List<DeviceOrientation>? restoreOrientations;
  final Widget child;

  @override
  State<ScopedPreferredOrientations> createState() =>
      _ScopedPreferredOrientationsState();
}

class _ScopedPreferredOrientationsState
    extends State<ScopedPreferredOrientations> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(widget.preferredOrientations);
  }

  @override
  void dispose() {
    final restore = widget.restoreOrientations;
    if (restore != null) {
      SystemChrome.setPreferredOrientations(restore);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

