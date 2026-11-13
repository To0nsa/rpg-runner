import 'package:flutter/widgets.dart';

import '../../theme/ui_tokens.dart';

/// Shared counter/pause/exit geometry for gameplay and tutorial authoring.
class RunHudActionsRow extends StatelessWidget {
  const RunHudActionsRow({super.key, this.stats, this.pause, this.exit});
  final Widget? stats, pause, exit;
  @override
  Widget build(BuildContext context) {
    final children = <Widget>[?stats, ?pause, ?exit];
    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: context.ui.space.xs),
            children[i],
          ],
        ],
      ),
    );
  }
}
