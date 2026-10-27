/// « Contact us » for ShipGlows Flutter apps, backend-free: one button that
/// opens a list of contact channels, each launched through a deeplink.
/// No inbox, no CRM, no network call.
///
/// - [ContactChannel]: one channel and its deeplink (`whatsApp`, `messenger`,
///   `instagram`, `telegram`, `email`, `phone`, `sms`, `link`), with
///   [ContactChannel.displayValue] shown under its label.
/// - [ShipglowsContactConfig]: the channels in display order, an optional
///   title and intro.
/// - [ShipglowsContactButton]: a floating button opening the sheet
///   (`Scaffold.floatingActionButton`).
/// - [showShipglowsContactSheet]: the sheet, a bottom sheet on compact
///   windows and a dialog otherwise.
/// - [ShipglowsContactList]: the channels alone, for a settings or about page.
/// - [openContactChannel] / [ContactLauncher]: open one channel; when nothing
///   opens, copy its value and show the failure ([shipglows_feedback]).
/// - [ShipglowsContactStrings] and [ShipglowsContactStringsScope]: the texts.
library;

export 'src/contact_button.dart';
export 'src/contact_channel.dart';
export 'src/contact_config.dart';
export 'src/contact_launcher.dart';
export 'src/contact_list.dart';
export 'src/contact_sheet.dart';
export 'src/strings.dart';
