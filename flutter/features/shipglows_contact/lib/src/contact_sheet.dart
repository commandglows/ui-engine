import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'contact_channel.dart';
import 'contact_config.dart';
import 'contact_launcher.dart';
import 'contact_list.dart';
import 'strings.dart';

/// Opens the « Contact us » sheet: a bottom sheet on compact windows, a
/// dialog on larger ones. Tapping a channel closes the sheet, then opens the
/// channel ([launcher] is the external application by default).
Future<void> showShipglowsContactSheet(
  BuildContext context, {
  required ShipglowsContactConfig config,
  ContactLauncher? launcher,
}) {
  final strings = ShipglowsContactStrings.of(context);
  Widget sheet(BuildContext sheetContext) => _ContactSheet(
    title: config.title ?? strings.title,
    intro: config.intro,
    config: config,
    onSelected: (channel) {
      Navigator.of(sheetContext).pop();
      if (context.mounted) {
        unawaited(openContactChannel(context, channel, launcher: launcher));
      }
    },
  );

  if (MediaQuery.sizeOf(context).width < ShipglowsScale.breakpointCompact) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: sheet,
    );
  }
  return showDialog<void>(
    context: context,
    builder: (sheetContext) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: sheet(sheetContext),
      ),
    ),
  );
}

class _ContactSheet extends StatelessWidget {
  const _ContactSheet({
    required this.title,
    required this.intro,
    required this.config,
    required this.onSelected,
  });

  final String title;
  final String? intro;
  final ShipglowsContactConfig config;
  final ValueChanged<ContactChannel> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final intro = this.intro;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        theme.spaceXl,
        theme.spaceLg,
        theme.spaceXl,
        theme.spaceXl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: textTheme.titleLarge?.copyWith(color: theme.text),
            ),
          ),
          if (intro != null) ...[
            SizedBox(height: theme.spaceXs),
            Text(
              intro,
              style: textTheme.bodyMedium?.copyWith(color: theme.textMuted),
            ),
          ],
          SizedBox(height: theme.spaceLg),
          ShipglowsContactList(config: config, onSelected: onSelected),
        ],
      ),
    );
  }
}
