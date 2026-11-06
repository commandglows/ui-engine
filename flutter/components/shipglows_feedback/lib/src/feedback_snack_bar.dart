import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'feedback_appearance.dart';
import 'feedback_content.dart';
import 'feedback_kind.dart';
import 'feedback_log.dart';
import 'strings.dart';

/// Widest a message gets on a large window; a narrow one takes its width.
const double kFeedbackMaxWidth = 480;

/// The message snack bar, for code that shows it itself: floating, on
/// `surfaceRaised` with a `border` outline, its action in `accent`,
/// [kFeedbackMaxWidth] wide on large windows. A [FeedbackAppearanceScope]
/// above [context] can change those colors and where it floats.
///
/// - [duration] defaults to the kind's ([FeedbackKind.duration]).
/// - [showCloseIcon] defaults to errors only.
/// - With an action, it stays until dismissed for assistive-technology
///   users, who need time to reach it.
/// - [secondaryActionLabel] adds a second action beside the message (a
///   snack bar takes only one [SnackBarAction]); it closes the message too.
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
  String? secondaryActionLabel,
  VoidCallback? onSecondaryAction,
  Widget Function(Widget content)? wrapContent,
}) => FeedbackMessenger._read(context, null).snackBar(
  message: message,
  kind: kind,
  actionLabel: actionLabel,
  onAction: onAction,
  secondaryActionLabel: secondaryActionLabel,
  onSecondaryAction: onSecondaryAction,
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
    this._appearance,
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
    FeedbackAppearanceScope.maybeOf(context),
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
  final FeedbackAppearance? _appearance;

  /// [feedbackSnackBar], from the values read with this messenger.
  SnackBar snackBar({
    required String message,
    FeedbackKind kind = FeedbackKind.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    bool? showCloseIcon,
    FeedbackStrings? strings,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryAction,
    Widget Function(Widget content)? wrapContent,
  }) {
    final theme = _theme;
    final appearance = _appearance;
    final actionColor = appearance?.action ?? theme.accent;
    final margin = appearance?.margin?.call();
    final secondaryLabel = secondaryActionLabel;
    final onSecondary = onSecondaryAction;
    final hasSecondary = secondaryLabel != null && onSecondary != null;
    Widget content = FeedbackContent(
      message: message,
      kind: kind,
      strings: strings ?? _strings,
      textColor: appearance?.foreground,
      iconColor: appearance?.iconColorOf?.call(kind),
    );
    if (secondaryLabel != null && onSecondary != null) {
      content = Row(
        children: [
          Expanded(child: content),
          SizedBox(width: theme.spaceSm),
          Builder(
            builder: (context) => TextButton(
              style: TextButton.styleFrom(foregroundColor: actionColor),
              onPressed: () {
                ScaffoldMessenger.maybeOf(
                  context,
                )?.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
                onSecondary();
              },
              child: Text(secondaryLabel),
            ),
          ),
        ],
      );
    }
    final wide = _width >= kFeedbackMaxWidth + 2 * theme.spaceXl;
    return SnackBar(
      content: wrapContent?.call(content) ?? content,
      behavior: SnackBarBehavior.floating,
      width: margin == null && wide ? kFeedbackMaxWidth : null,
      margin: margin,
      backgroundColor: appearance?.background ?? theme.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.radiusMd),
        side: BorderSide(
          color: appearance?.border ?? theme.border,
          width: theme.lineWidth,
        ),
      ),
      duration: duration ?? kind.duration,
      persist:
          ((actionLabel != null && onAction != null) || hasSecondary) &&
          _accessibleNavigation,
      showCloseIcon: showCloseIcon ?? kind == FeedbackKind.error,
      closeIconColor: appearance?.foreground ?? theme.icon,
      action: actionLabel != null && onAction != null
          ? SnackBarAction(
              label: actionLabel,
              onPressed: onAction,
              textColor: actionColor,
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
    String? secondaryActionLabel,
    VoidCallback? onSecondaryAction,
    Duration? duration,
    bool? showCloseIcon,
    bool replaceCurrent = false,
    FeedbackStrings? strings,
    String Function()? details,
  }) {
    final messenger = this.messenger;
    if (messenger == null || !messenger.mounted) return null;
    if (details != null) {
      final texts = strings ?? _strings;
      void copy() => unawaited(_copy(details, texts));
      if (actionLabel == null) {
        actionLabel = texts.copyDetails;
        onAction = copy;
      } else if (secondaryActionLabel == null) {
        secondaryActionLabel = texts.copyDetails;
        onSecondaryAction = copy;
      }
    }
    final last = _last[messenger];
    if (!replaceCurrent &&
        last != null &&
        last.message == message &&
        last.kind == kind) {
      return last.controller;
    }
    if (replaceCurrent) messenger.hideCurrentSnackBar();
    if (FeedbackLog.hasListeners) {
      FeedbackLog.record(
        FeedbackRecord(
          message: message,
          kind: kind,
          shownAt: DateTime.now(),
          details: details?.call(),
        ),
      );
    }
    final shown = _Shown(message, kind);
    _last[messenger] = shown;
    final controller = messenger.showSnackBar(
      snackBar(
        message: message,
        kind: kind,
        actionLabel: actionLabel,
        onAction: onAction,
        secondaryActionLabel: secondaryActionLabel,
        onSecondaryAction: onSecondaryAction,
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

  /// With [details], offers « Copy details »: the technical text for a bug
  /// report, read when copied; beside [actionLabel] when there is one.
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
/// controller is returned. [secondaryActionLabel] adds a second action;
/// [details] adds « Copy details », as the second action when there is
/// already one. After an await, use [FeedbackMessenger].
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showFeedback(
  BuildContext context,
  String message, {
  FeedbackKind kind = FeedbackKind.info,
  String? actionLabel,
  VoidCallback? onAction,
  String? secondaryActionLabel,
  VoidCallback? onSecondaryAction,
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
  secondaryActionLabel: secondaryActionLabel,
  onSecondaryAction: onSecondaryAction,
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
