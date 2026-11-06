import 'package:flutter/widgets.dart';

import 'customer_review.dart';
import 'rating_page.dart';

/// Texts of the review form, invitation and settings rows. `{app}` is the
/// app's name, `{store}` the rating page's ([pageName]), `{count}` a number. The app picks the
/// language: [en], [fr], or its own values, once for the app with
/// [ShipglowsReviewStringsScope].
@immutable
class ShipglowsReviewStrings {
  const ShipglowsReviewStrings({
    required this.giveFeedback,
    required this.giveFeedbackSubtitle,
    required this.pending,
    required this.rateApp,
    required this.rateAppSubtitle,
    required this.invitationTitle,
    required this.invitationMessage,
    required this.later,
    required this.dontAskAgain,
    required this.formTitle,
    required this.formLead,
    required this.ratingLabel,
    required this.ratingLevels,
    required this.ratingValue,
    required this.clearRating,
    required this.topicLabel,
    required this.topicPraise,
    required this.topicIdea,
    required this.topicProblem,
    required this.topicOther,
    required this.commentLabel,
    required this.commentHint,
    required this.emailLabel,
    required this.emailHelper,
    required this.emailInvalid,
    required this.publishConsent,
    required this.publishConsentHelper,
    required this.publicNameLabel,
    required this.publicNameHelper,
    required this.privacyNote,
    required this.needsRatingOrComment,
    required this.send,
    required this.sending,
    required this.cancel,
    required this.close,
    required this.thanksTitle,
    required this.thanksSent,
    required this.thanksQueued,
    required this.thanksReply,
    required this.rateAlso,
    required this.rateOn,
    required this.sendFailed,
    required this.rejected,
    required this.retry,
    required this.googlePlay,
    required this.appStore,
    required this.microsoftStore,
  });

  /// Settings row and menu entry that opens the form.
  final String giveFeedback;
  final String giveFeedbackSubtitle;

  /// Subtitle while reviews wait to be sent (`{count}`).
  final String pending;

  /// Settings row that opens the store page (`{app}`, `{store}`).
  final String rateApp;
  final String rateAppSubtitle;

  /// The app's own invitation, where the store has no rating prompt
  /// (Windows, the web): title and message (`{app}`), « Plus tard » and
  /// « Ne plus me demander ».
  final String invitationTitle;
  final String invitationMessage;
  final String later;
  final String dontAskAgain;

  final String formTitle;
  final String formLead;
  final String ratingLabel;

  /// What 1 to 5 stars mean, shown under the stars and read with them.
  final List<String> ratingLevels;

  /// A star's spoken value (`{count}` out of 5).
  final String ratingValue;
  final String clearRating;

  final String topicLabel;
  final String topicPraise;
  final String topicIdea;
  final String topicProblem;
  final String topicOther;

  final String commentLabel;
  final String commentHint;
  final String emailLabel;
  final String emailHelper;
  final String emailInvalid;
  final String publishConsent;
  final String publishConsentHelper;
  final String publicNameLabel;
  final String publicNameHelper;

  /// What is sent with the review besides what the person wrote.
  final String privacyNote;
  final String needsRatingOrComment;

  final String send;
  final String sending;
  final String cancel;
  final String close;

  final String thanksTitle;
  final String thanksSent;
  final String thanksQueued;

  /// Added when the person gave an address.
  final String thanksReply;

  /// After sending, offered to everyone whatever their rating (`{app}`,
  /// `{store}`).
  final String rateAlso;

  /// Button that opens the store page (`{store}`).
  final String rateOn;

  final String sendFailed;
  final String rejected;
  final String retry;

  final String googlePlay;
  final String appStore;
  final String microsoftStore;

  static const en = ShipglowsReviewStrings(
    giveFeedback: 'Give feedback',
    giveFeedbackSubtitle:
        'An idea, a problem, a compliment: we read every message.',
    pending: '{count} waiting to be sent',
    rateApp: 'Rate {app}',
    rateAppSubtitle: 'On {store}. Your rating helps others find {app}.',
    invitationTitle: 'Your opinion on {app}',
    invitationMessage:
        'You have been using {app} for a while. Two minutes to tell us what '
        'you think? Every message is read.',
    later: 'Later',
    dontAskAgain: 'Don’t ask again',
    formTitle: 'Your feedback on {app}',
    formLead: 'Tell us what works for you and what does not.',
    ratingLabel: 'Your rating',
    ratingLevels: ['Very poor', 'Poor', 'Okay', 'Good', 'Excellent'],
    ratingValue: '{count} out of 5',
    clearRating: 'Clear rating',
    topicLabel: 'It is mostly',
    topicPraise: 'Praise',
    topicIdea: 'An idea',
    topicProblem: 'A problem',
    topicOther: 'Something else',
    commentLabel: 'Your message',
    commentHint: 'What do you like, miss, or find in your way?',
    emailLabel: 'Email (optional)',
    emailHelper: 'Only to reply to you.',
    emailInvalid: 'This address does not look right.',
    publishConsent: 'You may publish this review as a testimonial',
    publishConsentHelper: 'On the {app} website or store page.',
    publicNameLabel: 'Name to show (optional)',
    publicNameHelper: 'Leave it empty to stay anonymous.',
    privacyNote:
        'Along with your message we receive the {app} version, your system '
        'and your language, to understand it better. Nothing else.',
    needsRatingOrComment: 'Pick a rating or write a message.',
    send: 'Send',
    sending: 'Sending…',
    cancel: 'Cancel',
    close: 'Close',
    thanksTitle: 'Thank you!',
    thanksSent: 'Your feedback reached us. It helps us improve {app}.',
    thanksQueued:
        'Your feedback is saved and will be sent as soon as you are back '
        'online.',
    thanksReply: 'We will reply to the address you gave.',
    rateAlso: 'You can also rate {app} on {store}.',
    rateOn: 'Rate on {store}',
    sendFailed: 'Your feedback could not be saved. Your message is still here.',
    rejected: 'Your feedback was not accepted. Please try again later.',
    retry: 'Try again',
    googlePlay: 'Google Play',
    appStore: 'the App Store',
    microsoftStore: 'the Microsoft Store',
  );

  static const fr = ShipglowsReviewStrings(
    giveFeedback: 'Donner mon avis',
    giveFeedbackSubtitle:
        'Une idée, un souci, un compliment : nous lisons chaque message.',
    pending: '{count} en attente d’envoi',
    rateApp: 'Noter {app}',
    rateAppSubtitle: 'Sur {store}. Votre note aide d’autres personnes à '
        'découvrir {app}.',
    invitationTitle: 'Votre avis sur {app}',
    invitationMessage:
        'Vous utilisez {app} depuis un moment. Deux minutes pour nous dire ce '
        'que vous en pensez ? Chaque message est lu.',
    later: 'Plus tard',
    dontAskAgain: 'Ne plus me demander',
    formTitle: 'Votre avis sur {app}',
    formLead: 'Dites-nous ce qui vous plaît et ce qui vous gêne.',
    ratingLabel: 'Votre note',
    ratingLevels: ['Très décevant', 'Décevant', 'Correct', 'Bien', 'Excellent'],
    ratingValue: '{count} sur 5',
    clearRating: 'Effacer la note',
    topicLabel: 'C’est plutôt',
    topicPraise: 'Un compliment',
    topicIdea: 'Une idée',
    topicProblem: 'Un problème',
    topicOther: 'Autre chose',
    commentLabel: 'Votre message',
    commentHint: 'Qu’est-ce qui vous plaît, vous manque ou vous gêne ?',
    emailLabel: 'E-mail (facultatif)',
    emailHelper: 'Uniquement pour vous répondre.',
    emailInvalid: 'Cette adresse ne semble pas correcte.',
    publishConsent: 'J’accepte que cet avis soit publié comme témoignage',
    publishConsentHelper: 'Sur le site de {app} ou sa page dans le store.',
    publicNameLabel: 'Nom affiché (facultatif)',
    publicNameHelper: 'Laissez vide pour rester anonyme.',
    privacyNote:
        'Avec votre message, nous recevons la version de {app}, votre système '
        'et votre langue, pour mieux le comprendre. Rien d’autre.',
    needsRatingOrComment: 'Choisissez une note ou écrivez un message.',
    send: 'Envoyer',
    sending: 'Envoi…',
    cancel: 'Annuler',
    close: 'Fermer',
    thanksTitle: 'Merci !',
    thanksSent: 'Votre avis nous est bien parvenu. Il nous aide à améliorer '
        '{app}.',
    thanksQueued:
        'Votre avis est enregistré et partira dès que la connexion '
        'reviendra.',
    thanksReply: 'Nous vous répondrons à l’adresse indiquée.',
    rateAlso: 'Vous pouvez aussi noter {app} sur {store}.',
    rateOn: 'Noter sur {store}',
    sendFailed:
        'Votre avis n’a pas pu être enregistré. Votre message est toujours '
        'là.',
    rejected: 'Votre avis n’a pas été accepté. Réessayez plus tard.',
    retry: 'Réessayer',
    googlePlay: 'Google Play',
    appStore: 'l’App Store',
    microsoftStore: 'le Microsoft Store',
  );

  /// The [ShipglowsReviewStringsScope] above [context]; without one, [fr]
  /// when the app locale is French, [en] otherwise.
  static ShipglowsReviewStrings of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ShipglowsReviewStringsScope>()
          ?.strings ??
      (Localizations.maybeLocaleOf(context)?.languageCode == 'fr' ? fr : en);

  String storeName(ReviewStore store) => switch (store) {
    ReviewStore.googlePlay => googlePlay,
    ReviewStore.appStore => appStore,
    ReviewStore.microsoftStore => microsoftStore,
  };

  /// The store's name, or the review site's (`Trustpilot`).
  String pageName(RatingPage page) => switch (page) {
    StoreRatingPage(:final store) => storeName(store),
    SiteRatingPage(:final site) => site.name,
  };

  String topicName(ReviewTopic topic) => switch (topic) {
    ReviewTopic.praise => topicPraise,
    ReviewTopic.idea => topicIdea,
    ReviewTopic.problem => topicProblem,
    ReviewTopic.other => topicOther,
  };

  /// What [rating] stars mean (1 to 5).
  String levelOf(int rating) => ratingLevels[(rating - 1).clamp(0, 4)];

  /// [text] with `{app}`, `{store}` and `{count}` filled in.
  static String fill(
    String text, {
    String app = '',
    String store = '',
    int? count,
  }) => text
      .replaceAll('{app}', app)
      .replaceAll('{store}', store)
      .replaceAll('{count}', count?.toString() ?? '');
}

/// The app's own [ShipglowsReviewStrings] for every review widget below it,
/// set once (in `MaterialApp.builder`, say) instead of per call.
class ShipglowsReviewStringsScope extends InheritedWidget {
  const ShipglowsReviewStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final ShipglowsReviewStrings strings;

  @override
  bool updateShouldNotify(ShipglowsReviewStringsScope oldWidget) =>
      !identical(strings, oldWidget.strings);
}
