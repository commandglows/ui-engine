import 'dart:async';

import 'package:flutter/material.dart';

import 'pending_undo.dart';

/// How long « Undo » stays offered by default.
const Duration kUndoWindow = Duration(seconds: 5);

/// Ties [pending] to a snack bar the app has shown with an « Undo » action
/// calling [PendingUndo.undo]:
///
/// - the snack bar closing any other way (timeout, swipe, replaced) commits;
/// - no snack bar ([controller] null: no messenger) commits at once.
///
/// Wrap the snack bar content in [UndoSnackBarContent] so it also closes when
/// the action is settled elsewhere (Ctrl/⌘+Z, [UndoWindow.flush]). For an app
/// with its own toast look; [showUndoSnackBar] does all of it with a plain
/// floating snack bar.
void attachUndoSnackBar(
  PendingUndo pending,
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? controller,
) {
  if (controller == null) {
    unawaited(pending.commit());
    return;
  }
  unawaited(controller.closed.then((_) => pending.commit()));
}

/// Snack bar content that closes its snack bar once [pending] is settled
/// elsewhere, even when it was still queued behind another one then: a
/// snack bar content is only built while its snack bar is the current one,
/// so it never closes another app message.
class UndoSnackBarContent extends StatefulWidget {
  const UndoSnackBarContent({
    super.key,
    required this.pending,
    required this.child,
  });

  final PendingUndo pending;
  final Widget child;

  @override
  State<UndoSnackBarContent> createState() => _UndoSnackBarContentState();
}

class _UndoSnackBarContentState extends State<UndoSnackBarContent> {
  @override
  void initState() {
    super.initState();
    if (widget.pending.isOpen) {
      unawaited(widget.pending.settled.then((_) => _hide()));
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _hide());
    }
  }

  void _hide() {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shows [message] with an « Undo » action for [duration] and settles
/// [pending] with it (see [attachUndoSnackBar]).
///
/// The snack bar stays until dismissed for assistive-technology users, who
/// need time to reach the action.
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required PendingUndo pending,
  String actionLabel = 'Undo',
  Duration duration = kUndoWindow,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    unawaited(pending.commit());
    return;
  }
  messenger.hideCurrentSnackBar();
  final controller = messenger.showSnackBar(
    SnackBar(
      content: UndoSnackBarContent(pending: pending, child: Text(message)),
      behavior: SnackBarBehavior.floating,
      duration: duration,
      persist: MediaQuery.accessibleNavigationOf(context),
      action: SnackBarAction(label: actionLabel, onPressed: pending.undo),
    ),
  );
  attachUndoSnackBar(pending, controller);
}
