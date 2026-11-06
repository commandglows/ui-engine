import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shipglows_icons/shipglows_icons.dart';

import 'contact_config.dart';
import 'contact_launcher.dart';
import 'contact_sheet.dart';
import 'strings.dart';

/// A floating « Contact us » button opening [showShipglowsContactSheet];
/// use it as `Scaffold.floatingActionButton`. [extended] shows its label
/// beside the icon.
class ShipglowsContactButton extends StatelessWidget {
  const ShipglowsContactButton({
    super.key,
    required this.config,
    this.launcher,
    this.extended = false,
  });

  /// The channels the sheet lists.
  final ShipglowsContactConfig config;

  /// Opens the channels; the external application when omitted.
  final ContactLauncher? launcher;

  /// Shows the label next to the icon.
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final strings = ShipglowsContactStrings.of(context);
    void open() => unawaited(
      showShipglowsContactSheet(context, config: config, launcher: launcher),
    );
    final icon = Icon(ShipglowsIcons.feedback);
    if (extended) {
      return FloatingActionButton.extended(
        onPressed: open,
        tooltip: strings.button,
        icon: icon,
        label: Text(strings.button),
      );
    }
    return FloatingActionButton(
      onPressed: open,
      tooltip: strings.button,
      child: icon,
    );
  }
}
