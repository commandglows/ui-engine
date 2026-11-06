import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shipglows_icons/shipglows_icons.dart';

import 'review_form.dart';
import 'shipglows_reviews.dart';
import 'strings.dart';

/// The settings rows: « Donner mon avis » (opens the form; says how many
/// reviews wait while offline) and « Noter {app} » where the app has a store
/// page or a review site.
class ShipglowsReviewSettings extends StatelessWidget {
  const ShipglowsReviewSettings({
    super.key,
    required this.reviews,
    required this.appName,
    this.strings,
  });

  final ShipglowsReviews reviews;
  final String appName;
  final ShipglowsReviewStrings? strings;

  @override
  Widget build(BuildContext context) {
    final texts = strings ?? ShipglowsReviewStrings.of(context);
    return ValueListenableBuilder<ShipglowsReviewsStatus>(
      valueListenable: reviews.status,
      builder: (context, status, _) {
        final page = status.ratingPage;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(ShipglowsIcons.feedback),
              title: Text(texts.giveFeedback),
              subtitle: Semantics(
                liveRegion: status.pending > 0,
                child: Text(
                  status.pending > 0
                      ? ShipglowsReviewStrings.fill(
                          texts.pending,
                          count: status.pending,
                        )
                      : texts.giveFeedbackSubtitle,
                ),
              ),
              trailing: const Icon(ShipglowsIcons.chevronRight),
              onTap: () => unawaited(
                showShipglowsReviewForm(
                  context,
                  reviews: reviews,
                  appName: appName,
                  strings: strings,
                ),
              ),
            ),
            if (page != null)
              ListTile(
                leading: const Icon(ShipglowsIcons.star),
                title: Text(
                  ShipglowsReviewStrings.fill(texts.rateApp, app: appName),
                ),
                subtitle: Text(
                  ShipglowsReviewStrings.fill(
                    texts.rateAppSubtitle,
                    app: appName,
                    store: texts.pageName(page),
                  ),
                ),
                trailing: const Icon(ShipglowsIcons.open),
                onTap: () => unawaited(reviews.openRatingPage()),
              ),
          ],
        );
      },
    );
  }
}
