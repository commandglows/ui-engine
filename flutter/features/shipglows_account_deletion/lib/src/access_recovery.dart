import 'package:flutter/material.dart';
import 'package:shipglows_feedback/shipglows_feedback.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

/// Texts of [ShipglowsAccessRecovery]. The app picks the language.
@immutable
class ShipglowsAccessRecoveryStrings {
  const ShipglowsAccessRecoveryStrings({
    required this.title,
    required this.body,
    required this.action,
    required this.recovered,
    required this.failed,
    required this.paidAccessNotice,
  });

  static const fr = ShipglowsAccessRecoveryStrings(
    title: 'Récupérer ton achat',
    body:
        'Un compte supprimé avec cette adresse e-mail avait un accès payé. Tu '
        'peux le rattacher à ce compte.',
    action: 'Récupérer mon accès',
    recovered: 'Ton accès a été récupéré.',
    failed:
        'La récupération n’a pas abouti. Vérifie ta connexion et réessaie. Si '
        'cela continue, écris-nous.',
    paidAccessNotice:
        'Un accès payé prend fin avec le compte. Nous gardons la preuve de cet '
        'achat : si tu reviens avec la même adresse e-mail vérifiée, tu pourras '
        'le récupérer. Tes comptes sur nos autres produits ne changent pas.',
  );

  static const en = ShipglowsAccessRecoveryStrings(
    title: 'Take your purchase back',
    body:
        'A deleted account with this email address had paid access. You can '
        'attach it to this account.',
    action: 'Recover my access',
    recovered: 'Your access has been recovered.',
    failed:
        'The recovery did not finish. Check your connection and try again. If '
        'it keeps failing, write to us.',
    paidAccessNotice:
        'Paid access ends with the account. We keep the proof of that purchase: '
        'if you come back with the same verified email address, you can take it '
        'back. Your accounts on our other products do not change.',
  );

  final String title;
  final String body;
  final String action;
  final String recovered;
  final String failed;

  /// For [ShipglowsDeleteAccountButton.paidAccessNotice] on the same product.
  final String paidAccessNotice;
}

/// Offers a returning client the paid access of their deleted account. Takes no
/// space unless there is something to recover, and moves nothing until pressed.
class ShipglowsAccessRecovery extends StatefulWidget {
  const ShipglowsAccessRecovery({
    super.key,
    required this.findRecoverable,
    required this.recover,
    this.strings = ShipglowsAccessRecoveryStrings.fr,
    this.onRecovered,
    this.onFailure,
  });

  /// Whether the server holds a paid access for this verified email.
  final Future<bool> Function() findRecoverable;

  /// Moves it to the signed-in account; throwing reports a failure.
  final Future<void> Function() recover;

  final ShipglowsAccessRecoveryStrings strings;

  /// After the recovery, to refresh the app's access state.
  final VoidCallback? onRecovered;

  /// For the app's logs. Never shown to the user.
  final void Function(Object error)? onFailure;

  @override
  State<ShipglowsAccessRecovery> createState() =>
      _ShipglowsAccessRecoveryState();
}

class _ShipglowsAccessRecoveryState extends State<ShipglowsAccessRecovery> {
  bool _recoverable = false;
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final recoverable = await widget.findRecoverable();
      if (mounted) setState(() => _recoverable = recoverable);
    } on Object catch (error) {
      // Nothing is lost: the check runs again the next time the screen opens.
      widget.onFailure?.call(error);
    }
  }

  Future<void> _onPressed() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    final feedback = FeedbackMessenger.of(context);
    try {
      await widget.recover();
      feedback.showSuccess(widget.strings.recovered);
      if (mounted) setState(() => _recoverable = false);
      widget.onRecovered?.call();
    } on Object catch (error) {
      widget.onFailure?.call(error);
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_recoverable) return const SizedBox.shrink();
    final theme = ShipglowsTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      key: const Key('shipglows-access-recovery'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.strings.title, style: textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(widget.strings.body),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('shipglows-access-recovery-action'),
          onPressed: _busy ? null : _onPressed,
          child: Text(widget.strings.action),
        ),
        if (_failed)
          Semantics(
            liveRegion: true,
            child: Text(
              widget.strings.failed,
              key: const Key('shipglows-access-recovery-error'),
              style: TextStyle(color: theme.danger),
            ),
          ),
      ],
    );
  }
}
