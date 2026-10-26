import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'strings.dart';

/// Panel that says the data on screen is a sample: a title, a message and
/// an optional [action] (an exit or create-account button) below them.
class DemoBanner extends StatelessWidget {
  const DemoBanner({
    super.key,
    this.title,
    this.message,
    this.action,
    this.strings,
  });

  /// [DemoStrings.bannerTitle] when null.
  final String? title;

  /// [DemoStrings.bannerMessage] when null.
  final String? message;
  final Widget? action;

  /// [DemoStrings.of] the context when null.
  final DemoStrings? strings;

  @override
  Widget build(BuildContext context) {
    final roles = ShipglowsTheme.of(context);
    final texts = Theme.of(context).textTheme;
    final values = strings ?? DemoStrings.of(context);
    return Container(
      padding: EdgeInsets.all(roles.spaceMd),
      decoration: BoxDecoration(
        color: roles.highlight,
        borderRadius: BorderRadius.circular(roles.radiusLg),
        border: Border.all(color: roles.border, width: roles.lineWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined, size: 20, color: roles.onHighlight),
              SizedBox(width: roles.spaceSm),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title ?? values.bannerTitle,
                    style: texts.titleSmall?.copyWith(
                      color: roles.onHighlight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: roles.spaceXs),
          Text(
            message ?? values.bannerMessage,
            style: texts.bodyMedium?.copyWith(color: roles.onHighlight),
          ),
          if (action != null) ...[
            SizedBox(height: roles.spaceSm),
            Align(alignment: AlignmentDirectional.centerStart, child: action),
          ],
        ],
      ),
    );
  }
}
