import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shipglows_icons/shipglows_icons.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'review_form.dart';
import 'shipglows_reviews.dart';
import 'strings.dart';

/// What the person picked in the invitation.
enum ReviewInvitationChoice { form, ratingPage, later, never }

/// The app's own invitation to review, for installs where the store has no
/// rating prompt (Windows, the web, sideloaded APKs): « Donner mon avis »,
/// « Noter sur {page} » where there is one, « Plus tard », « Ne plus me
/// demander ». The same choices for everyone, nothing asked first.
///
/// `ShipglowsReviews.maybeAskForReview` shows it at the right moment; call it
/// directly to show it on demand. Acts on the choice (opens the form or the
/// page, or remembers the opt-out) and returns it; `null` when dismissed.
Future<ReviewInvitationChoice?> showShipglowsReviewInvitation(
  BuildContext context, {
  required ShipglowsReviews reviews,
  required String appName,
  ShipglowsReviewStrings? strings,
}) async {
  final choice = await showDialog<ReviewInvitationChoice>(
    context: context,
    builder: (_) => ShipglowsReviewInvitation(
      reviews: reviews,
      appName: appName,
      strings: strings,
    ),
  );
  switch (choice) {
    case ReviewInvitationChoice.form:
      if (context.mounted) {
        await showShipglowsReviewForm(
          context,
          reviews: reviews,
          appName: appName,
          strings: strings,
        );
      }
    case ReviewInvitationChoice.ratingPage:
      await reviews.openRatingPage();
    case ReviewInvitationChoice.never:
      await reviews.optOut();
    case ReviewInvitationChoice.later:
    case null:
      break;
  }
  return choice;
}

/// The invitation dialog; pops with a [ReviewInvitationChoice].
class ShipglowsReviewInvitation extends StatelessWidget {
  const ShipglowsReviewInvitation({
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
    final theme = ShipglowsTheme.of(context);
    final texts = strings ?? ShipglowsReviewStrings.of(context);
    final page = reviews.ratingPage;
    void pick(ReviewInvitationChoice choice) =>
        unawaited(Navigator.of(context).maybePop(choice));
    String fill(String text, {String store = ''}) =>
        ShipglowsReviewStrings.fill(text, app: appName, store: store);

    return AlertDialog(
      icon: Icon(ShipglowsIcons.feedback, color: theme.accent),
      title: Text(fill(texts.invitationTitle)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Text(fill(texts.invitationMessage)),
      ),
      actionsOverflowButtonSpacing: theme.spaceSm,
      actions: [
        TextButton(
          onPressed: () => pick(ReviewInvitationChoice.never),
          child: Text(texts.dontAskAgain),
        ),
        TextButton(
          onPressed: () => pick(ReviewInvitationChoice.later),
          child: Text(texts.later),
        ),
        if (page != null)
          OutlinedButton(
            onPressed: () => pick(ReviewInvitationChoice.ratingPage),
            child: Text(fill(texts.rateOn, store: texts.pageName(page))),
          ),
        FilledButton(
          autofocus: true,
          onPressed: () => pick(ReviewInvitationChoice.form),
          child: Text(texts.giveFeedback),
        ),
      ],
    );
  }
}
