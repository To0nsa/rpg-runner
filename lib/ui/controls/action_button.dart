import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.size = 72,
    this.backgroundColor = const Color(0x33000000),
    this.foregroundColor = Colors.white,
    this.labelFontSize = 12,
    this.labelGap = 2,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final Color backgroundColor;
  final Color foregroundColor;
  final double labelFontSize;
  final double labelGap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foregroundColor),
              SizedBox(height: labelGap),
              Text(
                label,
                style: TextStyle(
                  fontSize: labelFontSize,
                  color: foregroundColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
