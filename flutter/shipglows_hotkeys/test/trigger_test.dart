import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_hotkeys/shipglows_hotkeys.dart';

void main() {
  group('ShipglowsTrigger JSON', () {
    final triggers = <ShipglowsTrigger>[
      ShipglowsTrigger.key(
        ShipglowsHotkey(ShipglowsKey.space, control: true, alt: true),
      ),
      const ShipglowsDoubleKeyTrigger(ShipglowsKey.escape),
      const ShipglowsMouseTrigger.wheelDown(zone: ShipglowsZone.titleBar),
      const ShipglowsMouseTrigger.wheelUp(zone: ShipglowsZone.taskbar),
      const ShipglowsMouseTrigger.click(
        ShipglowsMouseButton.middle,
        zone: ShipglowsZone.titleBar,
      ),
      const ShipglowsMouseTrigger.hold(
        ShipglowsMouseButton.left,
        zone: ShipglowsZone.titleBar,
      ),
      const ShipglowsMouseTrigger.drag(
        ShipglowsMouseButton.left,
        zone: ShipglowsZone.maximizeButton,
      ),
      const ShipglowsMouseTrigger.touch(ShipglowsZone.cornerTopLeft),
      const ShipglowsMouseTrigger.wheelUp(control: true),
    ];

    for (final trigger in triggers) {
      test('round trip: ${trigger.label()}', () {
        expect(ShipglowsTrigger.fromJson(trigger.toJson()), trigger);
      });
    }

    test('a map without type is a key combination from version 0.1', () {
      final hotkey = ShipglowsHotkey(
        ShipglowsKey.space,
        control: true,
        alt: true,
      );
      expect(
        ShipglowsTrigger.fromJson(hotkey.toJson()),
        ShipglowsKeyTrigger(hotkey),
      );
    });

    test('unreadable values are null', () {
      expect(ShipglowsTrigger.fromJson(null), isNull);
      expect(ShipglowsTrigger.fromJson('x'), isNull);
      expect(ShipglowsTrigger.fromJson({'type': 'telepathy'}), isNull);
      expect(ShipglowsTrigger.fromJson({'type': 'doubleKey'}), isNull);
    });
  });

  group('ShipglowsTrigger.isValid', () {
    test('a plain left click is never a trigger', () {
      expect(
        const ShipglowsMouseTrigger.click(
          ShipglowsMouseButton.left,
          zone: ShipglowsZone.titleBar,
        ).isValid,
        isFalse,
      );
      expect(
        const ShipglowsMouseTrigger.click(
          ShipglowsMouseButton.left,
          zone: ShipglowsZone.titleBar,
          control: true,
        ).isValid,
        isTrue,
      );
    });

    test('anywhere needs a modifier', () {
      expect(const ShipglowsMouseTrigger.wheelDown().isValid, isFalse);
      expect(
        const ShipglowsMouseTrigger.wheelDown(shift: true).isValid,
        isTrue,
      );
    });

    test('corners go with touch only', () {
      expect(
        const ShipglowsMouseTrigger.touch(ShipglowsZone.cornerTopLeft).isValid,
        isTrue,
      );
      expect(
        const ShipglowsMouseTrigger.wheelDown(
          zone: ShipglowsZone.cornerTopLeft,
        ).isValid,
        isFalse,
      );
    });

    test('a double key is a plain key', () {
      expect(
        const ShipglowsDoubleKeyTrigger(ShipglowsKey.escape).isValid,
        isTrue,
      );
      expect(const ShipglowsDoubleKeyTrigger(0x11).isValid, isFalse);
      expect(
        const ShipglowsDoubleKeyTrigger(
          ShipglowsKey.escape,
          withinMs: 50,
        ).isValid,
        isFalse,
      );
    });
  });

  test('labels mention the gesture and the zone', () {
    final label = const ShipglowsMouseTrigger.wheelDown(
      zone: ShipglowsZone.taskbar,
    ).label(ShipglowsTriggerLabels.fr);
    expect(label, contains('Molette vers le bas'));
    expect(label, contains('barre des tâches'));
    expect(
      const ShipglowsDoubleKeyTrigger(ShipglowsKey.escape).label(),
      contains('×2'),
    );
  });
}
