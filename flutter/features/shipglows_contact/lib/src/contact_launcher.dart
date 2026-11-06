import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shipglows_feedback/shipglows_feedback.dart';
import 'package:url_launcher/url_launcher.dart';

import 'contact_channel.dart';
import 'strings.dart';

/// Opens a channel's [Uri]: `true` when another app took it. The default
/// opens it in the external application (mail client, WhatsApp, browser…).
/// Tests and apps inject their own.
typedef ContactLauncher = Future<bool> Function(Uri uri);

Future<bool> _defaultLauncher(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Opens [channel] with [launcher] (the external application by default).
///
/// When nothing opens (the launcher returns `false` or throws), copies
/// [ContactChannel.displayValue] to the clipboard and shows the failure
/// with `shipglows_feedback`, which needs a `ScaffoldMessenger` above
/// [context] (without one the value is still copied, silently). Never
/// throws.
Future<void> openContactChannel(
  BuildContext context,
  ContactChannel channel, {
  ContactLauncher? launcher,
}) async {
  try {
    // Read everything from the context before the await: the messages and
    // texts are kept, the context is not used again.
    final feedback = FeedbackMessenger.of(context);
    final strings = ShipglowsContactStrings.of(context);
    final label = channel.label ?? strings.labelOf(channel.kind);
    final value = channel.displayValue;

    var opened = false;
    try {
      opened = await (launcher ?? _defaultLauncher)(channel.uri);
    } on Object catch (error) {
      debugPrint('shipglows_contact: ${channel.uri} not opened: $error');
    }
    if (opened) return;

    var copied = true;
    try {
      await Clipboard.setData(ClipboardData(text: value));
    } on Object catch (error) {
      copied = false;
      debugPrint('shipglows_contact: clipboard not written: $error');
    }
    feedback.showError(
      strings.failureMessage(channel: label, value: value, copied: copied),
    );
  } on Object catch (error) {
    debugPrint('shipglows_contact: ${channel.uri} not handled: $error');
  }
}
