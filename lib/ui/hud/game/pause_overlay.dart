import 'package:flutter/material.dart';

import '../../components/overlay_button.dart';

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    super.key,
    required this.visible,
    required this.exitConfirmOpen,
    required this.onResume,
    required this.onExit,
  });

  final bool visible;
  final bool exitConfirmOpen;
  final VoidCallback onResume;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return SizedBox.expand(
      child: ColoredBox(
        color: const Color(0x66000000),
        child: SafeArea(
          minimum: const EdgeInsets.all(18),
          child: Center(
            child: exitConfirmOpen
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Want to exit?',
                        style: TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OverlayButton(label: 'Resume', onPressed: onResume),
                          const SizedBox(width: 12),
                          OverlayButton(label: 'Exit', onPressed: onExit),
                        ],
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
