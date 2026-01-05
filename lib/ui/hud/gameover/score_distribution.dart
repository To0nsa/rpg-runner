import 'package:flutter/material.dart';

class ScoreDistribution extends StatelessWidget {
  const ScoreDistribution({
    super.key,
    required this.rowLabels,
  });

  final List<String> rowLabels;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rowLabels.length; i += 1) ...[
              Text(
                rowLabels[i],
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              if (i < rowLabels.length - 1) const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}
