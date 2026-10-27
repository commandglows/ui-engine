import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shipglows_feedback/shipglows_feedback.dart';
import 'package:shipglows_icons/shipglows_icons.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'customer_review.dart';
import 'review_sink.dart';
import 'shipglows_reviews.dart';
import 'star_rating.dart';
import 'strings.dart';

/// Opens the review form from any entry point (menu, settings, help): a
/// bottom sheet on compact windows, a dialog on larger ones. Returns how
/// the review left, or `null` when the person closed the form without
/// sending.
Future<ReviewSendResult?> showShipglowsReviewForm(
  BuildContext context, {
  required ShipglowsReviews reviews,
  required String appName,
  ReviewTopic topic = ReviewTopic.other,
  ShipglowsReviewStrings? strings,
}) {
  Widget form(BuildContext context) => ShipglowsReviewForm(
    reviews: reviews,
    appName: appName,
    initialTopic: topic,
    strings: strings,
  );

  if (MediaQuery.sizeOf(context).width < ShipglowsScale.breakpointCompact) {
    return showModalBottomSheet<ReviewSendResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: form(context),
      ),
    );
  }
  return showDialog<ReviewSendResult>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: form(context),
      ),
    ),
  );
}

/// The review form: stars, topic, message, an optional address to answer,
/// consent to publish as a testimonial, then a thank-you that offers the
/// public rating page (store or review site) to everyone. Pops the route with the [ReviewSendResult] when
/// closed.
class ShipglowsReviewForm extends StatefulWidget {
  const ShipglowsReviewForm({
    super.key,
    required this.reviews,
    required this.appName,
    this.initialTopic = ReviewTopic.other,
    this.strings,
  });

  final ShipglowsReviews reviews;
  final String appName;
  final ReviewTopic initialTopic;
  final ShipglowsReviewStrings? strings;

  @override
  State<ShipglowsReviewForm> createState() => _ShipglowsReviewFormState();
}

class _ShipglowsReviewFormState extends State<ShipglowsReviewForm> {
  final _comment = TextEditingController();
  final _email = TextEditingController();
  final _publicName = TextEditingController();
  late ReviewTopic _topic = widget.initialTopic;
  int? _rating;
  bool _consent = false;
  bool _showValidation = false;
  bool _sending = false;
  String? _error;
  ReviewSendResult? _result;

  ShipglowsReviewStrings get _strings =>
      widget.strings ?? ShipglowsReviewStrings.of(context);

  String _fill(String text, {String store = ''}) =>
      ShipglowsReviewStrings.fill(text, app: widget.appName, store: store);

  ReviewDraft get _draft => ReviewDraft(
    rating: _rating,
    topic: _topic,
    comment: _comment.text,
    email: _email.text,
    publishConsent: _consent,
    publicName: _publicName.text,
  );

  @override
  void dispose() {
    _comment.dispose();
    _email.dispose();
    _publicName.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final draft = _draft;
    if (!draft.isValid) {
      setState(() => _showValidation = true);
      return;
    }
    final strings = _strings;
    final locale = Localizations.maybeLocaleOf(context);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await widget.reviews.submit(draft, locale: locale);
      if (!mounted) return;
      setState(() => _result = result);
    } on ReviewRejectedException {
      if (!mounted) return;
      setState(() => _error = strings.rejected);
    } on Object catch (error) {
      debugPrint('shipglows_reviews: review not saved: $error');
      if (!mounted) return;
      setState(() => _error = strings.sendFailed);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _close() => Navigator.of(context).maybePop(_result);

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            const _SendIntent(),
        const SingleActivator(LogicalKeyboardKey.enter, meta: true):
            const _SendIntent(),
      },
      child: Actions(
        actions: {
          _SendIntent: CallbackAction<_SendIntent>(
            onInvoke: (_) {
              if (_result == null && !_sending) unawaited(_send());
              return null;
            },
          ),
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            theme.spaceXl,
            theme.spaceLg,
            theme.spaceXl,
            theme.spaceXl,
          ),
          child: AnimatedSwitcher(
            duration: theme.motionNormal,
            child: _result == null
                ? _editing(context, theme)
                : _thanks(context, theme, _result!),
          ),
        ),
      ),
    );
  }

  Widget _editing(BuildContext context, ShipglowsTheme theme) {
    final strings = _strings;
    final textTheme = Theme.of(context).textTheme;
    final draft = _draft;
    final gap = SizedBox(height: theme.spaceLg);
    final label = textTheme.titleSmall?.copyWith(color: theme.text);
    return Column(
      key: const ValueKey('editing'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            _fill(strings.formTitle),
            style: textTheme.titleLarge?.copyWith(color: theme.text),
          ),
        ),
        SizedBox(height: theme.spaceXs),
        Text(
          strings.formLead,
          style: textTheme.bodyMedium?.copyWith(color: theme.textMuted),
        ),
        gap,
        Text(strings.ratingLabel, style: label),
        ShipglowsStarRating(
          value: _rating,
          strings: strings,
          onChanged: _sending
              ? null
              : (rating) => setState(() => _rating = rating),
        ),
        gap,
        Text(strings.topicLabel, style: label),
        SizedBox(height: theme.spaceSm),
        Wrap(
          spacing: theme.spaceSm,
          runSpacing: theme.spaceSm,
          children: [
            for (final topic in ReviewTopic.values)
              ChoiceChip(
                avatar: Icon(_iconOf(topic), size: ShipglowsScale.iconSm),
                label: Text(strings.topicName(topic)),
                selected: _topic == topic,
                showCheckmark: false,
                onSelected: _sending
                    ? null
                    : (_) => setState(() => _topic = topic),
              ),
          ],
        ),
        gap,
        TextField(
          controller: _comment,
          enabled: !_sending,
          minLines: 3,
          maxLines: 8,
          maxLength: ReviewDraft.maxCommentLength,
          textCapitalization: TextCapitalization.sentences,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            labelText: strings.commentLabel,
            hintText: strings.commentHint,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: theme.spaceSm),
        TextField(
          controller: _email,
          enabled: !_sending,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          decoration: InputDecoration(
            labelText: strings.emailLabel,
            helperText: strings.emailHelper,
            errorText: _showValidation && !draft.emailIsValid
                ? strings.emailInvalid
                : null,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: theme.spaceSm),
        CheckboxListTile(
          value: _consent,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(strings.publishConsent),
          subtitle: Text(_fill(strings.publishConsentHelper)),
          onChanged: _sending
              ? null
              : (value) => setState(() => _consent = value ?? false),
        ),
        if (_consent) ...[
          SizedBox(height: theme.spaceSm),
          TextField(
            controller: _publicName,
            enabled: !_sending,
            maxLength: ReviewDraft.maxPublicNameLength,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            decoration: InputDecoration(
              labelText: strings.publicNameLabel,
              helperText: strings.publicNameHelper,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
        SizedBox(height: theme.spaceSm),
        Text(
          _fill(strings.privacyNote),
          style: textTheme.bodySmall?.copyWith(color: theme.textMuted),
        ),
        if (_showValidation && !draft.hasRating && !draft.hasComment) ...[
          gap,
          FeedbackInline(
            message: strings.needsRatingOrComment,
            kind: FeedbackKind.warning,
            dense: true,
          ),
        ],
        if (_error case final error?) ...[
          gap,
          FeedbackInline(message: error, kind: FeedbackKind.error, dense: true),
        ],
        SizedBox(height: theme.spaceXl),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: theme.spaceSm,
          runSpacing: theme.spaceSm,
          children: [
            TextButton(
              onPressed: _sending ? null : _close,
              child: Text(strings.cancel),
            ),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox.square(
                      dimension: ShipglowsScale.iconSm,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      ShipglowsIcons.syncUpload,
                      size: ShipglowsScale.iconSm,
                    ),
              label: Text(
                _sending
                    ? strings.sending
                    : _error == null
                    ? strings.send
                    : strings.retry,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _thanks(
    BuildContext context,
    ShipglowsTheme theme,
    ReviewSendResult result,
  ) {
    final strings = _strings;
    final textTheme = Theme.of(context).textTheme;
    final page = widget.reviews.ratingPage;
    final message = [
      _fill(
        result == ReviewSendResult.sent
            ? strings.thanksSent
            : strings.thanksQueued,
      ),
      if (_email.text.trim().isNotEmpty) strings.thanksReply,
    ].join(' ');
    return Column(
      key: const ValueKey('thanks'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          result == ReviewSendResult.sent
              ? ShipglowsIcons.success
              : ShipglowsIcons.pending,
          size: 48,
          color: result == ReviewSendResult.sent ? theme.success : theme.icon,
        ),
        SizedBox(height: theme.spaceMd),
        Semantics(
          header: true,
          child: Text(
            strings.thanksTitle,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(color: theme.text),
          ),
        ),
        SizedBox(height: theme.spaceSm),
        Semantics(
          liveRegion: true,
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: theme.textMuted),
          ),
        ),
        if (page != null) ...[
          SizedBox(height: theme.spaceXl),
          Text(
            _fill(strings.rateAlso, store: strings.pageName(page)),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: theme.text),
          ),
          SizedBox(height: theme.spaceSm),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => unawaited(widget.reviews.openRatingPage()),
              icon: const Icon(ShipglowsIcons.star, size: ShipglowsScale.iconSm),
              label: Text(
                _fill(strings.rateOn, store: strings.pageName(page)),
              ),
            ),
          ),
        ],
        SizedBox(height: theme.spaceXl),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton(onPressed: _close, child: Text(strings.close)),
        ),
      ],
    );
  }

  static IconData _iconOf(ReviewTopic topic) => switch (topic) {
    ReviewTopic.praise => ShipglowsIcons.star,
    ReviewTopic.idea => ShipglowsIcons.idea,
    ReviewTopic.problem => ShipglowsIcons.bug,
    ReviewTopic.other => ShipglowsIcons.feedback,
  };
}

class _SendIntent extends Intent {
  const _SendIntent();
}
