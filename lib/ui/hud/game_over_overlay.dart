import 'package:flutter/material.dart';

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({
    super.key,
    required this.visible,
    required this.onRestart,
    required this.onExit,
    required this.showExitButton,
  });

  final bool visible;
  final VoidCallback onRestart;
  final VoidCallback? onExit;
  final bool showExitButton;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return SizedBox.expand(
      child: ColoredBox(
        color: const Color(0x88000000),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Game Over',
                style: TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _OverlayButton(label: 'Restart', onPressed: onRestart),
                  if (showExitButton) ...[
                    const SizedBox(width: 12),
                    _OverlayButton(label: 'Exit', onPressed: onExit),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFFFFFFF),
        backgroundColor: const Color(0xAA000000),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFFFFFFF)),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}
