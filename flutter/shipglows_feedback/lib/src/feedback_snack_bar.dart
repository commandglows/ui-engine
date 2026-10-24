import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'feedback_content.dart';
import 'feedback_kind.dart';
import 'strings.dart';

/// Widest a message gets on a large window; a narrow one takes its width.
const double kFeedbackMaxWidth = 480;

/// The message snack bar, for code that shows it itself: floating, on
/// `surfaceRaised` with a `border` outline, its action in `accent`,
/// [kFeedbackMaxWidth] wide on large windows.
///
/// - [duration] defaults to the kind's ([FeedbackKind.duration]).
/// - [showCloseIcon] defaults to errors only.
/// - With an action, it stays until dismissed for assistive-technology
///   users, who need time to reach it.
/// - [wrapContent] wraps the [FeedbackContent], to tie the snack bar to
///   something else (the « Undo » snack bar closes once undone elsewhere).
SnackBar feedbackSnackBar(
  BuildContext context, {
  required String message,
  FeedbackKind kind = FeedbackKind.info,
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
  bool? showCloseIcon,
  FeedbackStrings? strings,
  Widget Function(Widget content)? wrapContent,
}) {
  final theme = ShipglowsTheme.of(context);
  final texts = strings ?? FeedbackStrings.of(context);
  final content = FeedbackContent(message: message, kind: kind, strings: texts);
  final wide =
      MediaQuery.sizeOf(context).width >= kFeedbackMaxWidth + 2 * theme.spaceXl;
  return SnackBar(
    content: wrapContent?.call(content) ?? content,
    behavior: SnackBarBehavior.floating,
    width: wide ? kFeedbackMaxWidth : null,
    backgroundColor: theme.surfaceRaised,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(theme.radiusMd),
      side: BorderSide(color: theme.border, width: theme.lineWidth),
    ),
    duration: duration ?? kind.duration,
    persist:
        actionLabel != null &&
        onAction != null &&
        MediaQuery.accessibleNavigationOf(context),
    showCloseIcon: showCloseIcon ?? kind == FeedbackKind.error,
    closeIconColor: theme.icon,
    action: actionLabel != null && onAction != null
        ? SnackBarAction(
            label: actionLabel,
            onPressed: onAction,
            textColor: theme.accent,
          )
        : null,
  );
}

class _Shown {
  _Shown(this.message, this.kind);

  final String message;
  final FeedbackKind kind;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? controller;
}

/// The last message [showFeedback] queued on each messenger, until it closes.
final Expando<_Shown> _last = Expando();

/// Shows [message] as a [feedbackSnackBar] and returns its controller, or
/// null without a [ScaffoldMessenger] (nothing shown).
///
/// Messages queue one after the other; [replaceCurrent] closes the one on
/// screen first. The same message of the same kind, still queued or on
/// screen, is not queued again (a failing sync reporting each retry): its
/// controller is returned.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showFeedback(
  BuildContext context,
  String message, {
  FeedbackKind kind = FeedbackKind.info,
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
  bool? showCloseIcon,
  bool replaceCurrent = false,
  FeedbackStrings? strings,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return null;
  final last = _last[messenger];
  if (!replaceCurrent &&
      last != null &&
      last.message == message &&
      last.kind == kind) {
    return last.controller;
  }
  if (replaceCurrent) messenger.hideCurrentSnackBar();
  final shown = _Shown(message, kind);
  _last[messenger] = shown;
  final controller = messenger.showSnackBar(
    feedbackSnackBar(
      context,
      message: message,
      kind: kind,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      showCloseIcon: showCloseIcon,
      strings: strings,
    ),
  );
  shown.controller = controller;
  unawaited(
    controller.closed.then((_) {
      if (identical(_last[messenger], shown)) _last[messenger] = null;
    }),
  );
  return controller;
}

/// [showFeedback] by kind: `context.showError('Could not save')`.
extension FeedbackContext on BuildContext {
  void showInfo(String message, {String? actionLabel, VoidCallback? onAction}) =>
      _show(FeedbackKind.info, message, actionLabel, onAction);

  void showSuccess(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => _show(FeedbackKind.success, message, actionLabel, onAction);

  void showWarning(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => _show(FeedbackKind.warning, message, actionLabel, onAction);

  void showError(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => _show(FeedbackKind.error, message, actionLabel, onAction);

  void _show(
    FeedbackKind kind,
    String message,
    String? actionLabel,
    VoidCallback? onAction,
  ) => showFeedback(
    this,
    message,
    kind: kind,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}
