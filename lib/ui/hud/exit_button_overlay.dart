import 'package:flutter/material.dart';

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
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: IconButton(
          onPressed: onPressed,
          icon: const Icon(Icons.close),
          color: highlight ? Colors.white : null,
        ),
      ),
    );
  }
}
