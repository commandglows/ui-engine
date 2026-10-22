import 'dart:async';

import 'package:flutter/material.dart';

import 'pending_undo.dart';

/// How long « Undo » stays offered by default.
const Duration kUndoWindow = Duration(seconds: 5);

/// Ties [pending] to a snack bar the app has shown with an « Undo » action
/// calling [PendingUndo.undo]:
///
/// - the snack bar closing any other way (timeout, swipe, replaced) commits;
/// - the action settled elsewhere (Ctrl/⌘+Z, [UndoWindow.flush]) hides it;
/// - no snack bar ([controller] null: no messenger) commits at once.
///
/// For an app with its own toast look; [showUndoSnackBar] does both steps
/// with a plain floating snack bar.
void attachUndoSnackBar(
  PendingUndo pending,
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? controller, {
  ScaffoldMessengerState? messenger,
}) {
  if (controller == null) {
    unawaited(pending.commit());
    return;
  }
  var closed = false;
  unawaited(
    controller.closed.then((_) {
      closed = true;
      return pending.commit();
    }),
  );
  unawaited(
    pending.settled.then((_) {
      if (!closed && messenger != null && messenger.mounted) {
        messenger.hideCurrentSnackBar();
      }
    }),
  );
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
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: duration,
      persist: MediaQuery.accessibleNavigationOf(context),
      action: SnackBarAction(label: actionLabel, onPressed: pending.undo),
    ),
  );
  attachUndoSnackBar(pending, controller, messenger: messenger);
}
