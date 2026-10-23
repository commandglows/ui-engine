import 'package:flutter/material.dart';

import 'onboarding_theme.dart';

/// One labelled statement of a mission page: mission, vision, goal…
@immutable
class OnboardingStatement {
  const OnboardingStatement({
    required this.label,
    required this.text,
    this.icon,
  });

  /// Short label drawn above the text (`Mission`).
  final String label;
  final String text;
  final IconData? icon;
}

/// Labelled statements stacked in an [OnboardingPage.body], for a page that
/// says why the app exists. Pair it with `scrollable: true`: long statements
/// scroll inside the card.
class OnboardingStatements extends StatelessWidget {
  const OnboardingStatements({super.key, required this.statements});

  final List<OnboardingStatement> statements;

  @override
  Widget build(BuildContext context) {
    final look = OnboardingThemeData.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, statement) in statements.indexed) ...[
            if (i > 0) const SizedBox(height: 20),
            Semantics(
              container: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (statement.icon != null) ...[
                        Icon(statement.icon, size: 16, color: accent),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          statement.label.toUpperCase(),
                          style: look.eyebrowStyle!.copyWith(color: accent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(statement.text, style: look.descriptionStyle),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
