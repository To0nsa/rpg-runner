import 'package:flutter/widgets.dart';

class ReadyOverlay extends StatelessWidget {
  const ReadyOverlay({super.key, required this.visible, required this.onTap});

  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: const ColoredBox(
        color: Color(0x88000000),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tap to start',
                style: TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Survive as long as possible',
                style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
