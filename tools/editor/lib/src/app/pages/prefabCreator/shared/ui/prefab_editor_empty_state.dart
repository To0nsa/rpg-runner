import 'package:flutter/material.dart';

/// Shared centered message for empty or unavailable editor states.
class PrefabEditorEmptyState extends StatelessWidget {
  const PrefabEditorEmptyState({
    super.key,
    required this.message,
    this.padding = const EdgeInsets.all(16),
    this.textAlign = TextAlign.center,
  });

  final String message;
  final EdgeInsetsGeometry padding;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Text(message, textAlign: textAlign),
      ),
    );
  }
}
