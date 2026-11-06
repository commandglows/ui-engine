import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// The kinds of contact channel. Each has its own default label and icon.
enum ContactChannelKind {
  whatsApp,
  messenger,
  instagram,
  telegram,
  email,
  phone,
  sms,
  link,
}

/// One way to contact the app's team: a deeplink ([uri]) and the value
/// shown under its label ([displayValue]: the address, number or handle,
/// also copied when the channel cannot open).
///
/// Build one with a named constructor; the URI is computed from the inputs
/// (not const, since it is parsed and encoded).
@immutable
class ContactChannel {
  const ContactChannel._({
    required this.kind,
    required this.uri,
    required this.displayValue,
    this.label,
  });

  /// WhatsApp chat with [phone] in international format (`+33 6…` or
  /// `0033 6…`; spaces, dashes, dots and parentheses are dropped), with an
  /// optional prefilled [message]. A national number (`06…`) opens a chat
  /// that WhatsApp cannot find.
  factory ContactChannel.whatsApp(String phone, {String? message}) {
    assert(
      RegExp(r'^\s*(\+|00)').hasMatch(phone),
      'WhatsApp needs an international number: $phone',
    );
    final digits = phone
        .trim()
        .replaceFirst(RegExp(r'^00'), '')
        .replaceAll(RegExp(r'\D'), '');
    return ContactChannel._(
      kind: ContactChannelKind.whatsApp,
      uri: Uri(
        scheme: 'https',
        host: 'wa.me',
        path: '/$digits',
        query: _query({'text': message}),
      ),
      displayValue: phone.trim(),
    );
  }

  /// Messenger conversation with the Facebook [page] (its name or id, or a
  /// pasted `m.me/…` or `facebook.com/…` link).
  factory ContactChannel.messenger(String page) {
    final name = _handle(page);
    return ContactChannel._(
      kind: ContactChannelKind.messenger,
      uri: Uri(scheme: 'https', host: 'm.me', path: '/$name'),
      displayValue: name,
    );
  }

  /// Instagram direct message to [username]; a leading `@` is optional.
  factory ContactChannel.instagram(String username) {
    final handle = _handle(username);
    return ContactChannel._(
      kind: ContactChannelKind.instagram,
      uri: Uri(scheme: 'https', host: 'ig.me', path: '/m/$handle'),
      displayValue: '@$handle',
    );
  }

  /// Telegram chat with [username]; a leading `@` is optional.
  factory ContactChannel.telegram(String username) {
    final handle = _handle(username);
    return ContactChannel._(
      kind: ContactChannelKind.telegram,
      uri: Uri(scheme: 'https', host: 't.me', path: '/$handle'),
      displayValue: '@$handle',
    );
  }

  /// Email to [address], with an optional [subject] and [body]. Spaces are
  /// `%20`, never `+`, which mail clients show literally.
  factory ContactChannel.email(
    String address, {
    String? subject,
    String? body,
  }) {
    final mail = address.trim();
    return ContactChannel._(
      kind: ContactChannelKind.email,
      uri: Uri(
        scheme: 'mailto',
        path: mail,
        query: _query({'subject': subject, 'body': body}),
      ),
      displayValue: mail,
    );
  }

  /// Email to the app's support [address], tagged so the support inbox
  /// (the email engine's « Service client ») sorts it by app: the subject
  /// starts with `[appName version] ` (the trailing space leaves the cursor
  /// ready when [subject] is not given) and the body ends with a signature
  /// line naming the app, version, [platform] and [locale] (detected when
  /// not given). No device id, no account.
  factory ContactChannel.supportEmail(
    String address, {
    required String appName,
    String? version,
    String? subject,
    String? body,
    String? platform,
    String? locale,
  }) {
    final app = [
      appName,
      ?version,
    ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(' ');
    final footer = [
      app,
      platform ?? _platformName(),
      locale ?? ui.PlatformDispatcher.instance.locale.toLanguageTag(),
    ].join(' · ');
    return ContactChannel.email(
      address,
      subject: '[$app] ${subject ?? ''}',
      body: '${body ?? ''}\n\n-- \n$footer',
    );
  }

  /// Phone call to [number]; spaces are removed, a leading `+` is kept.
  factory ContactChannel.phone(String number) {
    final dialed = number.trim();
    return ContactChannel._(
      kind: ContactChannelKind.phone,
      uri: Uri(scheme: 'tel', path: dialed.replaceAll(RegExp(r'\s'), '')),
      displayValue: dialed,
    );
  }

  /// Text message to [number], with an optional prefilled [body].
  factory ContactChannel.sms(String number, {String? body}) {
    final dialed = number.trim();
    return ContactChannel._(
      kind: ContactChannelKind.sms,
      uri: Uri(
        scheme: 'sms',
        path: dialed.replaceAll(RegExp(r'\s'), ''),
        query: _query({'body': body}),
      ),
      displayValue: dialed,
    );
  }

  /// Any other [url] (a form, a help center, a community page). [label] is
  /// required: there is no default name for a link.
  factory ContactChannel.link(Uri url, {required String label}) =>
      ContactChannel._(
        kind: ContactChannelKind.link,
        uri: url,
        displayValue: url.toString(),
        label: label,
      );

  /// What kind of channel this is; picks the default label and icon.
  final ContactChannelKind kind;

  /// Shown instead of the kind's default label when set.
  final String? label;

  /// The deeplink opened when the channel is tapped.
  final Uri uri;

  /// The address, number or handle shown under the label, and copied to the
  /// clipboard when the channel cannot open.
  final String displayValue;

  @override
  bool operator ==(Object other) =>
      other is ContactChannel &&
      other.kind == kind &&
      other.label == label &&
      other.uri == uri &&
      other.displayValue == displayValue;

  @override
  int get hashCode => Object.hash(kind, label, uri, displayValue);

  /// `key=value&…` with each value percent-encoded; null when none is set.
  static String? _query(Map<String, String?> parameters) {
    final pairs = [
      for (final entry in parameters.entries)
        if (entry.value != null)
          '${entry.key}=${Uri.encodeComponent(entry.value!)}',
    ];
    return pairs.isEmpty ? null : pairs.join('&');
  }

  /// The running platform, as the support signature names it.
  static String _platformName() {
    if (kIsWeb) return 'Web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
  }

  /// [username] without surrounding spaces and a leading `@`; from a pasted
  /// profile link (`https://t.me/name/`), its last path segment.
  static String _handle(String username) {
    final segments = username
        .trim()
        .split('/')
        .where((segment) => segment.isNotEmpty);
    final last = segments.isEmpty ? '' : segments.last;
    return last.replaceFirst(RegExp(r'^@'), '');
  }
}
