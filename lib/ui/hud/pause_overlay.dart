import 'package:flutter/widgets.dart';

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return const IgnorePointer(child: ColoredBox(color: Color(0x66000000)));
  }
}
