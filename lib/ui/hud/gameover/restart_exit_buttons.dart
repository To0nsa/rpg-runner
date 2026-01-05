import 'package:flutter/material.dart';

class RestartExitButtons extends StatelessWidget {
  const RestartExitButtons({
    super.key,
    required this.restartButton,
    this.exitButton,
    this.trailingButton,
  });

  final Widget restartButton;
  final Widget? exitButton;
  final Widget? trailingButton;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              restartButton,
              if (exitButton != null) ...[
                const SizedBox(width: 12),
                exitButton!,
              ],
            ],
          ),
          if (trailingButton != null)
            Align(alignment: Alignment.centerRight, child: trailingButton),
        ],
      ),
    );
  }
}
