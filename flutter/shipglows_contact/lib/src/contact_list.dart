import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shipglows_icons/shipglows_icons.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'contact_channel.dart';
import 'contact_config.dart';
import 'contact_launcher.dart';
import 'strings.dart';

/// The channels of [config] as a column of rows (icon, label, value), each
/// a button of at least 44 px. Opens the channel on tap, or hands it to
/// [onSelected] instead (the « Contact us » sheet closes first that way).
///
/// Needs a [Material] ancestor (a `Scaffold`, a dialog, a bottom sheet):
/// the rows are `ListTile`s. Embeds in a settings or about page as is.
class ShipglowsContactList extends StatelessWidget {
  const ShipglowsContactList({
    super.key,
    required this.config,
    this.launcher,
    this.onSelected,
  });

  /// The channels, in display order.
  final ShipglowsContactConfig config;

  /// Opens the channels; the external application when omitted.
  final ContactLauncher? launcher;

  /// Called instead of opening a channel: the caller then opens it itself.
  final ValueChanged<ContactChannel>? onSelected;

  @override
  Widget build(BuildContext context) {
    final strings = ShipglowsContactStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final channel in config.channels)
          _ContactRow(
            channel: channel,
            label: channel.label ?? strings.labelOf(channel.kind),
            onTap: () => _select(context, channel),
          ),
      ],
    );
  }

  void _select(BuildContext context, ContactChannel channel) {
    final selected = onSelected;
    if (selected != null) {
      selected(channel);
      return;
    }
    unawaited(openContactChannel(context, channel, launcher: launcher));
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.channel,
    required this.label,
    required this.onTap,
  });

  final ContactChannel channel;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: label,
      value: channel.displayValue,
      onTap: onTap,
      child: ExcludeSemantics(
        child: ListTile(
          leading: Icon(
            _iconOf(channel.kind),
            size: ShipglowsScale.iconMd,
            color: theme.icon,
          ),
          title: Text(
            label,
            style: textTheme.bodyLarge?.copyWith(color: theme.text),
          ),
          subtitle: Text(
            channel.displayValue,
            style: textTheme.bodyMedium?.copyWith(color: theme.textMuted),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// The icon of each kind: the ShipGlows icons where they fit, Material
/// icons for the messengers (the base set has no brand icons).
IconData _iconOf(ContactChannelKind kind) => switch (kind) {
  ContactChannelKind.whatsApp => Icons.chat_outlined,
  ContactChannelKind.messenger => Icons.messenger_outline,
  ContactChannelKind.instagram => Icons.camera_alt_outlined,
  ContactChannelKind.telegram => Icons.send_outlined,
  ContactChannelKind.email => Icons.mail_outline,
  ContactChannelKind.phone => ShipglowsIcons.phone,
  ContactChannelKind.sms => Icons.sms_outlined,
  ContactChannelKind.link => ShipglowsIcons.link,
};
