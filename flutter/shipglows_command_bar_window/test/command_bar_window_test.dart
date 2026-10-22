import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_command_bar/shipglows_command_bar.dart';
import 'package:shipglows_command_bar_window/shipglows_command_bar_window.dart';
import 'package:shipglows_overlay_window/shipglows_overlay_window.dart';

/// Snapshot as the app's engine sends it: one entry opening an app screen,
/// one disabled entry with a secondary action, one invalid entry.
Map<String, Object?> _payload() => <String, Object?>{
  'locale': 'fr',
  'brightness': 'dark',
  'recentIds': <Object?>['screen:/feed', 42],
  'appWindowIds': <Object?>['screen:/feed'],
  'entries': <Object?>[
    <String, Object?>{
      'id': 'screen:/feed',
      'section': 'screen',
      'label': 'Flux',
    },
    <String, Object?>{
      'id': 'project:old',
      'section': 'project',
      'label': 'Ancien',
      'enabled': false,
      'hasSecondary': true,
      'secondaryLabel': 'Réactiver',
    },
    <String, Object?>{'id': 'broken', 'label': 'Invalide'},
  ],
};

/// Records what the bar asks of its window instead of calling the native
/// side.
class _FakeHost extends Fake implements ShipglowsOverlayHost {
  final messageController = StreamController<ShipglowsOverlayMessage>();
  final hides = <OverlayHideFocus>[];
  final sent = <Object?>[];

  @override
  bool closeOnEscape = true;

  @override
  FutureOr<void> Function(Object? data)? onShow;

  @override
  VoidCallback? onHide;

  @override
  int? get previousForeground => 7;

  @override
  Stream<ShipglowsOverlayMessage> get messages => messageController.stream;

  @override
  Future<void> hide({
    OverlayHideFocus focus = OverlayHideFocus.previous,
  }) async {
    hides.add(focus);
  }

  @override
  Future<void> send(String method, [Object? arguments]) async {
    sent.add(arguments);
  }
}

void main() {
  group('ShipglowsCommandBarSnapshot', () {
    test('keeps the valid entries and skips the invalid ones', () {
      final snapshot = ShipglowsCommandBarSnapshot.fromJson(_payload())!;
      expect(snapshot.entries.map((e) => e.id), [
        'screen:/feed',
        'project:old',
      ]);
      expect(snapshot.recentIds, ['screen:/feed']);
      expect(snapshot.locale?.languageCode, 'fr');
      expect(snapshot.brightness, Brightness.dark);
      expect(snapshot.appWindowIds, {'screen:/feed'});
    });

    test('survives a round trip through toJson', () {
      final snapshot = ShipglowsCommandBarSnapshot.fromJson(_payload())!;
      final copy = ShipglowsCommandBarSnapshot.fromJson(snapshot.toJson())!;
      expect(copy.entries, snapshot.entries);
      expect(copy.recentIds, snapshot.recentIds);
      expect(copy.locale, snapshot.locale);
      expect(copy.brightness, snapshot.brightness);
      expect(copy.appWindowIds, snapshot.appWindowIds);
    });

    test('is null when the payload is not a snapshot', () {
      expect(ShipglowsCommandBarSnapshot.fromJson('nope'), isNull);
    });
  });

  group('ShipglowsCommandBarOverlayController.choose', () {
    late _FakeHost host;
    late ShipglowsCommandBarOverlayController controller;

    setUp(() {
      host = _FakeHost();
      controller = ShipglowsCommandBarOverlayController(host: host);
      host.onShow!(_payload());
    });

    tearDown(() => controller.dispose());

    test('sends only the entries that can run', () async {
      await controller.choose(const CommandBarChoice(id: 'screen:/feed'));
      // A disabled row runs nothing with Enter, but its secondary action runs.
      await controller.choose(const CommandBarChoice(id: 'project:old'));
      await controller.choose(
        const CommandBarChoice(id: 'project:old', secondary: true),
      );
      await controller.choose(
        const CommandBarChoice(id: 'screen:/feed', secondary: true),
      );
      await controller.choose(const CommandBarChoice(id: 'unknown'));
      expect(host.sent, [
        {'id': 'screen:/feed', 'secondary': false, 'previousForeground': 7},
        {'id': 'project:old', 'secondary': true, 'previousForeground': 7},
      ]);
    });

    test('brings the app forward only for its own screens', () async {
      await controller.choose(const CommandBarChoice(id: 'screen:/feed'));
      await controller.choose(
        const CommandBarChoice(id: 'project:old', secondary: true),
      );
      expect(host.hides, [OverlayHideFocus.app, OverlayHideFocus.previous]);
    });
  });
}
