import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_contact/shipglows_contact.dart';

void main() {
  group('deeplinks', () {
    test('WhatsApp keeps the digits only and encodes the text', () {
      final channel = ContactChannel.whatsApp(
        '+33 6 12-34.56(78)',
        message: 'Hello there',
      );
      expect(
        channel.uri.toString(),
        'https://wa.me/33612345678?text=Hello%20there',
      );
      expect(channel.displayValue, '+33 6 12-34.56(78)');
    });

    test('WhatsApp without a message has no query', () {
      expect(
        ContactChannel.whatsApp('+33 6 12 34 56 78').uri.toString(),
        'https://wa.me/33612345678',
      );
    });

    test('WhatsApp drops a leading 00', () {
      expect(
        ContactChannel.whatsApp('0033 6 12 34 56 78').uri.toString(),
        'https://wa.me/33612345678',
      );
    });

    test('a pasted profile link keeps its handle', () {
      expect(
        ContactChannel.telegram('https://t.me/shipglows/').uri.toString(),
        'https://t.me/shipglows',
      );
      expect(
        ContactChannel.messenger('https://m.me/shipglows').uri.toString(),
        'https://m.me/shipglows',
      );
    });

    test('email encodes spaces as %20, never +', () {
      final channel = ContactChannel.email(
        'hello@shipglows.com',
        subject: 'Hi there',
        body: 'A + B',
      );
      expect(
        channel.uri.toString(),
        'mailto:hello@shipglows.com?subject=Hi%20there&body=A%20%2B%20B',
      );
      expect(channel.uri.toString().contains('+'), isFalse);
    });

    test('support email tags the subject and signs the body', () {
      final channel = ContactChannel.supportEmail(
        'support@shipglows.com',
        appName: 'CommandGlows',
        version: '1.4.2',
        platform: 'Windows',
        locale: 'fr-FR',
      );
      expect(channel.kind, ContactChannelKind.email);
      expect(channel.displayValue, 'support@shipglows.com');
      expect(
        channel.uri.toString(),
        'mailto:support@shipglows.com'
        '?subject=%5BCommandGlows%201.4.2%5D%20'
        '&body=%0A%0A--%20%0ACommandGlows%201.4.2%20%C2%B7%20Windows'
        '%20%C2%B7%20fr-FR',
      );
    });

    test('support email without a version keeps the app name alone', () {
      final uri = ContactChannel.supportEmail(
        'support@shipglows.com',
        appName: 'BeatGlows',
        subject: 'Bug',
        platform: 'Android',
        locale: 'en',
      ).uri;
      expect(uri.queryParameters['subject'], '[BeatGlows] Bug');
    });

    test('Instagram and Telegram strip one leading @', () {
      final instagram = ContactChannel.instagram('@shipglows');
      expect(instagram.uri.toString(), 'https://ig.me/m/shipglows');
      expect(instagram.displayValue, '@shipglows');

      expect(
        ContactChannel.telegram('@shipglows').uri.toString(),
        'https://t.me/shipglows',
      );
      expect(
        ContactChannel.telegram('shipglows').uri.toString(),
        'https://t.me/shipglows',
      );
    });

    test('Messenger opens the page', () {
      expect(
        ContactChannel.messenger('shipglows').uri.toString(),
        'https://m.me/shipglows',
      );
    });

    test('phone keeps the leading + and drops the spaces', () {
      final channel = ContactChannel.phone('+33 6 12 34 56 78');
      expect(channel.uri.toString(), 'tel:+33612345678');
      expect(channel.displayValue, '+33 6 12 34 56 78');
    });

    test('SMS encodes the body', () {
      expect(
        ContactChannel.sms('+33612345678', body: 'Hi there').uri.toString(),
        'sms:+33612345678?body=Hi%20there',
      );
    });

    test('a link keeps its URL and label', () {
      final channel = ContactChannel.link(
        Uri.parse('https://example.com/help'),
        label: 'Help',
      );
      expect(channel.kind, ContactChannelKind.link);
      expect(channel.label, 'Help');
      expect(channel.displayValue, 'https://example.com/help');
    });

    test('channels compare by value', () {
      expect(
        ContactChannel.telegram('@shipglows'),
        ContactChannel.telegram('shipglows'),
      );
    });
  });

  group('opening a channel', () {
    testWidgets('tapping a row calls the launcher with its deeplink', (
      tester,
    ) async {
      final opened = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShipglowsContactList(
              config: ShipglowsContactConfig(
                channels: [
                  ContactChannel.email(
                    'hello@shipglows.com',
                    subject: 'Hi there',
                  ),
                ],
              ),
              launcher: (uri) async {
                opened.add(uri);
                return true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Email'));
      await tester.pumpAndSettle();

      expect(
        opened.single.toString(),
        'mailto:hello@shipglows.com?subject=Hi%20there',
      );
    });

    testWidgets('a launcher returning false copies the value', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShipglowsContactList(
              config: ShipglowsContactConfig(
                channels: [ContactChannel.phone('+33 6 12 34 56 78')],
              ),
              launcher: (uri) async => false,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Phone'));
      await tester.pump();
      await tester.pump();

      expect(copied, '+33 6 12 34 56 78');
      expect(find.textContaining("Couldn't open Phone"), findsOneWidget);

      // Let the error snack bar expire so no timer outlives the test.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
    });
  });
}
