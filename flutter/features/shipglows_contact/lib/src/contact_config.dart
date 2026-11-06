import 'package:flutter/foundation.dart';

import 'contact_channel.dart';

/// What the « Contact us » sheet and list show: the [channels], in display
/// order, and the optional [title] and [intro] (the defaults come from
/// [ShipglowsContactStrings]). Holds no state and no backend.
@immutable
class ShipglowsContactConfig {
  const ShipglowsContactConfig({
    required this.channels,
    this.title,
    this.intro,
  });

  /// The channels, in the order they are shown.
  final List<ContactChannel> channels;

  /// Replaces the sheet's default title.
  final String? title;

  /// A short line shown under the title.
  final String? intro;
}
