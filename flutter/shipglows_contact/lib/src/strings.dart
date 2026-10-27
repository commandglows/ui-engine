import 'package:flutter/widgets.dart';

import 'contact_channel.dart';

/// Texts of the « Contact us » button, sheet and channels: the default name
/// of each [ContactChannelKind], and the message shown when a channel cannot
/// open. The app picks the language: [en], [fr], or its own values, once for
/// the app with [ShipglowsContactStringsScope].
///
/// [openFailed] and [openFailedNotCopied] are templates: `{channel}` is the
/// channel's name and `{value}` its [ContactChannel.displayValue].
@immutable
class ShipglowsContactStrings {
  const ShipglowsContactStrings({
    required this.title,
    required this.button,
    required this.whatsApp,
    required this.messenger,
    required this.instagram,
    required this.telegram,
    required this.email,
    required this.phone,
    required this.sms,
    required this.link,
    this.openFailed =
        "Couldn't open {channel}. {value} copied to the clipboard.",
    this.openFailedNotCopied = "Couldn't open {channel}: {value}.",
  });

  /// Sheet title, and the default for [ShipglowsContactConfig.title].
  final String title;

  /// Button label and tooltip.
  final String button;

  final String whatsApp;
  final String messenger;
  final String instagram;
  final String telegram;
  final String email;
  final String phone;
  final String sms;
  final String link;

  /// Shown when a channel cannot open; see the class doc for the placeholders.
  final String openFailed;

  /// [openFailed] when the clipboard could not be written either.
  final String openFailedNotCopied;

  static const en = ShipglowsContactStrings(
    title: 'Contact us',
    button: 'Contact us',
    whatsApp: 'WhatsApp',
    messenger: 'Messenger',
    instagram: 'Instagram',
    telegram: 'Telegram',
    email: 'Email',
    phone: 'Phone',
    sms: 'SMS',
    link: 'Link',
  );

  static const fr = ShipglowsContactStrings(
    title: 'Nous contacter',
    button: 'Nous contacter',
    whatsApp: 'WhatsApp',
    messenger: 'Messenger',
    instagram: 'Instagram',
    telegram: 'Telegram',
    email: 'E-mail',
    phone: 'Téléphone',
    sms: 'SMS',
    link: 'Lien',
    openFailed:
        "Impossible d'ouvrir {channel}. {value} copié dans le presse-papiers.",
    openFailedNotCopied: "Impossible d'ouvrir {channel} : {value}.",
  );

  /// The [ShipglowsContactStringsScope] above [context]; without one, [fr]
  /// when the app locale is French, [en] otherwise.
  static ShipglowsContactStrings of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ShipglowsContactStringsScope>()
          ?.strings ??
      (Localizations.maybeLocaleOf(context)?.languageCode == 'fr' ? fr : en);

  /// The name of [kind] when the channel has no label of its own.
  String labelOf(ContactChannelKind kind) => switch (kind) {
    ContactChannelKind.whatsApp => whatsApp,
    ContactChannelKind.messenger => messenger,
    ContactChannelKind.instagram => instagram,
    ContactChannelKind.telegram => telegram,
    ContactChannelKind.email => email,
    ContactChannelKind.phone => phone,
    ContactChannelKind.sms => sms,
    ContactChannelKind.link => link,
  };

  /// [openFailed] (or [openFailedNotCopied] when not [copied]) with
  /// [channel] and [value] filled in.
  String failureMessage({
    required String channel,
    required String value,
    bool copied = true,
  }) => (copied ? openFailed : openFailedNotCopied)
      .replaceAll('{channel}', channel)
      .replaceAll('{value}', value);

  ShipglowsContactStrings copyWith({
    String? title,
    String? button,
    String? whatsApp,
    String? messenger,
    String? instagram,
    String? telegram,
    String? email,
    String? phone,
    String? sms,
    String? link,
    String? openFailed,
    String? openFailedNotCopied,
  }) => ShipglowsContactStrings(
    title: title ?? this.title,
    button: button ?? this.button,
    whatsApp: whatsApp ?? this.whatsApp,
    messenger: messenger ?? this.messenger,
    instagram: instagram ?? this.instagram,
    telegram: telegram ?? this.telegram,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    sms: sms ?? this.sms,
    link: link ?? this.link,
    openFailed: openFailed ?? this.openFailed,
    openFailedNotCopied: openFailedNotCopied ?? this.openFailedNotCopied,
  );
}

/// The app's own [ShipglowsContactStrings] for every contact widget below
/// it, set once (in `MaterialApp.builder`, say) instead of per call.
class ShipglowsContactStringsScope extends InheritedWidget {
  const ShipglowsContactStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final ShipglowsContactStrings strings;

  @override
  bool updateShouldNotify(ShipglowsContactStringsScope oldWidget) =>
      strings != oldWidget.strings;
}
