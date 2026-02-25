import 'package:flutter/material.dart';

import '../../theme/ui_tokens.dart';

class ExitButtonOverlay extends StatelessWidget {
  const ExitButtonOverlay({
    super.key,
    required this.onPressed,
    required this.highlight,
  });

  final VoidCallback? onPressed;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: EdgeInsets.all(ui.space.xs),
        child: IconButton(
          onPressed: onPressed,
          icon: const Icon(Icons.close),
          color: highlight ? ui.colors.textPrimary : null,
        ),
      ),
    );
  }
}
