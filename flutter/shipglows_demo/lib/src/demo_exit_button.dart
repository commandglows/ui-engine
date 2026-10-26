import 'package:flutter/material.dart';

import 'strings.dart';

/// « Sortir du mode démo » button. Disabled while [onPressed] is null.
class DemoExitButton extends StatelessWidget {
  const DemoExitButton({super.key, required this.onPressed, this.strings});

  final VoidCallback? onPressed;

  /// [DemoStrings.of] the context when null.
  final DemoStrings? strings;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.exit_to_app),
    label: Text((strings ?? DemoStrings.of(context)).exit),
  );
}
