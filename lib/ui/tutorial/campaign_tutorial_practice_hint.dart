import 'package:flutter/material.dart';

/// Non-blocking authored instruction shared by full HUD and HUD-free previews.
class CampaignTutorialPracticeHint extends StatelessWidget {
  const CampaignTutorialPracticeHint({super.key, required this.text});
  final Map<String, String>? text;

  @override
  Widget build(BuildContext context) {
    final hint = text;
    if (hint == null) return const SizedBox.shrink();
    return Positioned(
      top: 70,
      left: 24,
      right: 24,
      child: IgnorePointer(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  hint[Localizations.localeOf(context).languageCode] ??
                      hint['en']!,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
