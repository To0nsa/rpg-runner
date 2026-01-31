import 'package:flutter/material.dart';

/// A simple, reusable button for menu screens.
///
/// Styled for a minimal black/white aesthetic. Use this for main menu,
/// pause menu, and other navigation screens.
class MenuButton extends StatelessWidget {
  const MenuButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.width = 160,
    this.height = 48,
    this.backgroundColor = Colors.white,
    this.foregroundColor = Colors.black,
    this.borderColor,
    this.borderWidth = 2,
    this.fontSize = 16,
  });

  /// The text label displayed on the button.
  final String label;

  /// Callback when the button is pressed. Null disables the button.
  final VoidCallback? onPressed;

  /// Button width. Defaults to 160.
  final double width;

  /// Button height. Defaults to 56.
  final double height;

  /// Background color. Defaults to white.
  final Color backgroundColor;

  /// Text color. Defaults to black.
  final Color foregroundColor;

  /// Border color. Defaults to foregroundColor if not specified.
  final Color? borderColor;

  /// Border width. Defaults to 2.
  final double borderWidth;

  /// Font size. Defaults to 18.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          side: BorderSide(
            color: borderColor ?? foregroundColor,
            width: borderWidth,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
