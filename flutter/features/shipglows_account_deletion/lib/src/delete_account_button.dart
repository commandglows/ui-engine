import 'package:flutter/material.dart';
import 'package:shipglows_feedback/shipglows_feedback.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'account_deletion_flow.dart';
import 'strings.dart';

/// The « Delete my account » action of an app's settings or profile screen.
class ShipglowsDeleteAccountButton extends StatefulWidget {
  const ShipglowsDeleteAccountButton({
    super.key,
    required this.auth,
    required this.deleteOnServer,
    required this.erasedData,
    this.strings = ShipglowsAccountDeletionStrings.fr,
    this.onDeleted,
    this.onFailure,
  });

  final AccountDeletionAuth auth;

  /// Erases the account on the product's server; throwing reports a failure.
  final Future<void> Function() deleteOnServer;

  /// What is erased, in the user's words, shown in the confirmation.
  final List<String> erasedData;

  final ShipglowsAccountDeletionStrings strings;

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDialog(
        strings: widget.strings,
        erasedData: widget.erasedData,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
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
  const _ConfirmDialog({required this.strings, required this.erasedData});

  final ShipglowsAccountDeletionStrings strings;
  final List<String> erasedData;

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
            Text(strings.paidAccess),
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
