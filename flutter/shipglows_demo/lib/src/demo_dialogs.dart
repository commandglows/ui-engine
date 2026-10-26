import 'package:flutter/material.dart';

import 'strings.dart';

/// Asks to leave the demo. True once confirmed; the app then removes its
/// sample data.
Future<bool> showDemoExitDialog(
  BuildContext context, {
  DemoStrings? strings,
}) async {
  final values = strings ?? DemoStrings.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(values.exitTitle),
      content: Text(values.exitMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(values.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(values.exit),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Says that [action] needs an account in the demo. True when the person
/// chooses to create one; false keeps them exploring.
Future<bool> showDemoAccountDialog(
  BuildContext context, {
  String? action,
  DemoStrings? strings,
}) async {
  final values = strings ?? DemoStrings.of(context);
  final create = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(values.accountTitle),
      content: Text(values.accountMessageFor(action)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(values.keepExploring),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(values.createAccount),
        ),
      ],
    ),
  );
  return create == true;
}
