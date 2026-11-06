import 'package:flutter/material.dart';
import 'package:shipglows_feedback/shipglows_feedback.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'account_deletion_flow.dart';
import 'strings.dart';

/// What [ShipglowsDeleteAccountButton.actionBuilder] needs to draw the action.
@immutable
class ShipglowsDeleteAccountAction {
  const ShipglowsDeleteAccountAction({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;
}

/// The « Delete my account » action of an app's settings or profile screen.
class ShipglowsDeleteAccountButton extends StatefulWidget {
  const ShipglowsDeleteAccountButton({
    super.key,
    required this.auth,
    required this.deleteOnServer,
    required this.erasedData,
    this.strings = ShipglowsAccountDeletionStrings.fr,
    this.paidAccessNotice,
    this.actionBuilder,
    this.confirm,
    this.onDeleted,
    this.onFailure,
  });

  final AccountDeletionAuth auth;

  /// Erases the account on the product's server; throwing reports a failure.
  final Future<void> Function() deleteOnServer;

  /// What is erased, in the user's words, shown in the confirmation.
  final List<String> erasedData;

  final ShipglowsAccountDeletionStrings strings;

  /// Replaces [ShipglowsAccountDeletionStrings.paidAccess] in the confirmation,
  /// for a product that lets a client take a paid access back.
  final String? paidAccessNotice;

  /// Draws the action in the app's own style. Defaults to a text button.
  final Widget Function(
    BuildContext context,
    ShipglowsDeleteAccountAction action,
  )?
  actionBuilder;

  /// Asks for the confirmation in the app's own dialog. Defaults to a dialog
  /// listing [erasedData].
  final Future<bool> Function(BuildContext context)? confirm;

  /// After the deletion, to leave the screen. This button may already be gone.
  final VoidCallback? onDeleted;

  /// For the app's logs. Never shown to the user.
  final void Function(AccountDeletionFailure failure)? onFailure;

  @override
  State<ShipglowsDeleteAccountButton> createState() =>
      _ShipglowsDeleteAccountButtonState();
}

class _ShipglowsDeleteAccountButtonState
    extends State<ShipglowsDeleteAccountButton> {
  bool _busy = false;
  String? _error;

  Future<void> _onPressed() async {
    final custom = widget.confirm;
    final confirmed = custom != null
        ? await custom(context)
        : await showDialog<bool>(
            context: context,
            builder: (context) => _ConfirmDialog(
              strings: widget.strings,
              erasedData: widget.erasedData,
              paidAccess: widget.paidAccessNotice ?? widget.strings.paidAccess,
            ),
          );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    // The sign-out rebuilds the app's auth gate, usually without this button.
    final feedback = FeedbackMessenger.of(context);
    try {
      final outcome = await runAccountDeletion(
        auth: widget.auth,
        deleteOnServer: widget.deleteOnServer,
      );
      if (outcome == AccountDeletionOutcome.deleted) {
        feedback.showSuccess(widget.strings.deleted);
        widget.onDeleted?.call();
      }
    } on AccountDeletionFailure catch (failure) {
      widget.onFailure?.call(failure);
      if (mounted) {
        setState(() => _error = widget.strings.failure(failure.kind));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final error = _error;
    final builder = widget.actionBuilder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (builder != null)
          builder(
            context,
            ShipglowsDeleteAccountAction(
              label: widget.strings.button,
              busy: _busy,
              onPressed: _onPressed,
            ),
          )
        else
          TextButton.icon(
            key: const Key('shipglows-delete-account'),
            style: TextButton.styleFrom(foregroundColor: theme.danger),
            onPressed: _busy ? null : _onPressed,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever_outlined),
            label: Text(widget.strings.button),
          ),
        if (error != null)
          Semantics(
            liveRegion: true,
            child: Text(
              error,
              key: const Key('shipglows-delete-account-error'),
              style: TextStyle(color: theme.danger),
            ),
          ),
      ],
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.strings,
    required this.erasedData,
    required this.paidAccess,
  });

  final ShipglowsAccountDeletionStrings strings;
  final List<String> erasedData;
  final String paidAccess;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    return AlertDialog(
      title: Text(strings.title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(strings.intro),
            const SizedBox(height: 8),
            for (final item in erasedData) Text('• $item'),
            const SizedBox(height: 12),
            Text(paidAccess),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(strings.cancel),
        ),
        TextButton(
          key: const Key('shipglows-delete-account-confirm'),
          style: TextButton.styleFrom(foregroundColor: theme.danger),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(strings.confirm),
        ),
      ],
    );
  }
}
