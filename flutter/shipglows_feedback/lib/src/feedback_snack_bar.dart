import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
///
/// [context] must be under the app theme: not the [ScaffoldMessenger]'s
/// own context, which `MaterialApp` puts above its theme. After an await,
/// use [FeedbackMessenger.snackBar], read before it.
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
}) => FeedbackMessenger._read(context, null).snackBar(
  message: message,
  kind: kind,
  actionLabel: actionLabel,
  onAction: onAction,
  duration: duration,
  showCloseIcon: showCloseIcon,
  strings: strings,
  wrapContent: wrapContent,
);

class _Shown {
  _Shown(this.message, this.kind);

  final String message;
  final FeedbackKind kind;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? controller;
}

/// The last message shown on each messenger, until it closes.
final Expando<_Shown> _last = Expando();

/// Shows messages without a [BuildContext]: read it before an await, show
/// after, when the widget may be gone.
///
/// ```dart
/// final feedback = FeedbackMessenger.of(context);
/// await save();
/// feedback.showSuccess('Saved');
/// ```
///
/// It keeps what the messages need from the context (messenger, theme,
/// texts, window width, assistive navigation) as they were when read.
class FeedbackMessenger {
  FeedbackMessenger._(
    this.messenger,
    this._theme,
    this._strings,
    this._width,
    this._accessibleNavigation,
  );

  static FeedbackMessenger _read(
    BuildContext context,
    ScaffoldMessengerState? messenger,
  ) => FeedbackMessenger._(
    messenger,
    ShipglowsTheme.of(context),
    FeedbackStrings.of(context),
    MediaQuery.sizeOf(context).width,
    MediaQuery.accessibleNavigationOf(context),
  );

  /// The messenger of [context]. Without a [ScaffoldMessenger], its messages
  /// are dropped (each `show` returns null).
  static FeedbackMessenger of(BuildContext context) =>
      _read(context, ScaffoldMessenger.maybeOf(context));

  /// The [ScaffoldMessenger] the messages go to, null when there is none.
  final ScaffoldMessengerState? messenger;

  final ShipglowsTheme _theme;
  final FeedbackStrings _strings;
  final double _width;
  final bool _accessibleNavigation;

  /// [feedbackSnackBar], from the values read with this messenger.
  SnackBar snackBar({
    required String message,
    FeedbackKind kind = FeedbackKind.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    bool? showCloseIcon,
    FeedbackStrings? strings,
    Widget Function(Widget content)? wrapContent,
  }) {
    final theme = _theme;
    final content = FeedbackContent(
      message: message,
      kind: kind,
      strings: strings ?? _strings,
    );
    final wide = _width >= kFeedbackMaxWidth + 2 * theme.spaceXl;
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
      persist: actionLabel != null && onAction != null && _accessibleNavigation,
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

  /// Shows [message] as a [snackBar] and returns its controller, or null
  /// without a messenger. See [showFeedback].
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? show(
    String message, {
    FeedbackKind kind = FeedbackKind.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    bool? showCloseIcon,
    bool replaceCurrent = false,
    FeedbackStrings? strings,
    String Function()? details,
  }) {
    final messenger = this.messenger;
    if (messenger == null || !messenger.mounted) return null;
    if (details != null && actionLabel == null) {
      final texts = strings ?? _strings;
      actionLabel = texts.copyDetails;
      onAction = () => _copy(details, texts);
    }
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
      snackBar(
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

  void showInfo(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    bool replaceCurrent = false,
  }) => show(
    message,
    actionLabel: actionLabel,
    onAction: onAction,
    replaceCurrent: replaceCurrent,
  );

  void showSuccess(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    bool replaceCurrent = false,
  }) => show(
    message,
    kind: FeedbackKind.success,
    actionLabel: actionLabel,
    onAction: onAction,
    replaceCurrent: replaceCurrent,
  );

  void showWarning(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    bool replaceCurrent = false,
  }) => show(
    message,
    kind: FeedbackKind.warning,
    actionLabel: actionLabel,
    onAction: onAction,
    replaceCurrent: replaceCurrent,
  );

  /// With [details] and no other action, offers « Copy details »: the
  /// technical text for a bug report, read when copied.
  void showError(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    bool replaceCurrent = false,
    String Function()? details,
  }) => show(
    message,
    kind: FeedbackKind.error,
    actionLabel: actionLabel,
    onAction: onAction,
    replaceCurrent: replaceCurrent,
    details: details,
  );

  Future<void> _copy(String Function() details, FeedbackStrings texts) async {
    await Clipboard.setData(ClipboardData(text: details()));
    show(texts.detailsCopied, replaceCurrent: true);
  }

  /// Closes the message on screen.
  void hideCurrent() => messenger?.hideCurrentSnackBar();
}

/// Shows [message] as a [feedbackSnackBar] and returns its controller, or
/// null without a [ScaffoldMessenger] (nothing shown).
///
/// Messages queue one after the other; [replaceCurrent] closes the one on
/// screen first. The same message of the same kind, still queued or on
/// screen, is not queued again (a failing sync reporting each retry): its
/// controller is returned. [details] adds « Copy details » when there is
/// no other action. After an await, use [FeedbackMessenger].
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
  String Function()? details,
}) => FeedbackMessenger.of(context).show(
  message,
  kind: kind,
  actionLabel: actionLabel,
  onAction: onAction,
  duration: duration,
  showCloseIcon: showCloseIcon,
  replaceCurrent: replaceCurrent,
  strings: strings,
  details: details,
);

/// [showFeedback] by kind: `context.showError('Could not save')`.
extension FeedbackContext on BuildContext {
  void showInfo(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    bool replaceCurrent = false,
  }) => FeedbackMessenger.of(this).showInfo(
    message,
    actionLabel: actionLabel,
    onAction: onAction,
    replaceCurrent: replaceCurrent,
  );

  void showSuccess(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    bool replaceCurrent = false,
  }) => FeedbackMessenger.of(this).showSuccess(
    message,
    actionLabel: actionLabel,
    onAction: onAction,
    replaceCurrent: replaceCurrent,
  );

  void showWarning(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    bool replaceCurrent = false,
  }) => FeedbackMessenger.of(this).showWarning(
    message,
    actionLabel: actionLabel,
    onAction: onAction,
    replaceCurrent: replaceCurrent,
  );

  void showError(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    bool replaceCurrent = false,
    String Function()? details,
  }) => FeedbackMessenger.of(this).showError(
    message,
    actionLabel: actionLabel,
    onAction: onAction,
    replaceCurrent: replaceCurrent,
    details: details,
  );
}
