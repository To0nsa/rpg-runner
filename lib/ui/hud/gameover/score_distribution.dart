import 'package:flutter/material.dart';

import '../../theme/ui_tokens.dart';

class ScoreDistribution extends StatelessWidget {
  const ScoreDistribution({super.key, required this.rowLabels});

  final List<String> rowLabels;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Scrollbar(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rowLabels.length; i += 1) ...[
              Text(
                rowLabels[i],
                style: ui.text.body.copyWith(
                  color: ui.colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              if (i < rowLabels.length - 1) SizedBox(height: ui.space.xxs),
            ],
          ],
        ),
      ),
    );
  }
}
