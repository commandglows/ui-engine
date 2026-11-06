# shipglows_contact

« Contact us » without a backend: one button opening a list of channels
(WhatsApp, Messenger, Instagram, Telegram, email, phone, SMS, any link), each
launched through its deeplink. No inbox, no CRM, no network call. A channel
with no handler on the device (`tel:` or `sms:` on a desktop, say) copies its
value and says so through `shipglows_feedback`, which needs a
`ScaffoldMessenger`. Depends on `url_launcher`, `shipglows_feedback`,
`shipglows_icons` and `shipglows_theme`.

- `ContactChannel.whatsApp(phone, message:)`, `.messenger(page)`,
  `.instagram(username)`, `.telegram(username)`, `.email(address, subject:,
  body:)`, `.phone(number)`, `.sms(number, body:)`, `.link(url, label:)`:
  the `uri` is computed (`%20` for spaces, `@` stripped from handles, a
  pasted profile link reduced to its handle), `displayValue` is the
  address, number or handle shown under the label. WhatsApp needs an
  international number (`+33…` or `0033…`; asserted in debug).
- `ContactChannel.supportEmail(address, appName:, version:)`: the email
  for the app's support alias, meant to reach the email engine's « Service
  client » once the alias routes there (Mutant Mail → Gmail). The subject
  starts with `[App 1.4.2] ` and the body ends with a `-- ` signature
  followed by a line naming app, version, platform and language, so the
  support inbox can sort mail by app. No device id.
- `ShipglowsContactConfig(channels:, title:, intro:)`: the channels in
  display order.
- `ShipglowsContactButton(config:, extended:)`: a floating button for
  `Scaffold.floatingActionButton`; opens `showShipglowsContactSheet(context,
  config:)` (a bottom sheet on compact windows, a dialog otherwise).
- `ShipglowsContactList(config:, onSelected:)`: the rows alone, for a settings
  or about page.
- `openContactChannel(context, channel, launcher:)`: external application by
  default (`ContactLauncher`, injectable). Never throws.
- `ShipglowsContactStrings.fr` / `.en`, `ShipglowsContactStringsScope`.

```dart
ShipglowsContactButton(
  config: ShipglowsContactConfig(
    channels: [
      ContactChannel.whatsApp('+33 6 12 34 56 78'),
      ContactChannel.supportEmail(
        'support-commandglows@example.com',
        appName: 'CommandGlows',
        version: '1.4.2', // PackageInfo.fromPlatform() in the app
      ),
    ],
  ),
);
```
