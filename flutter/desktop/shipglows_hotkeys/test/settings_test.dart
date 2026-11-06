import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_hotkeys/shipglows_hotkeys.dart';

void main() {
  group('ShipglowsHotkeySettings', () {
    test('defaults: on, nothing excluded', () {
      const settings = ShipglowsHotkeySettings();
      expect(settings.enabled, isTrue);
      expect(settings.excludedProcesses, isEmpty);
      expect(settings.filterOf('anything').isEmpty, isTrue);
    });

    test('JSON round trip', () {
      final settings = const ShipglowsHotkeySettings().copyWith(
        enabled: false,
        excludedProcesses: {'Code.EXE', ' game.exe '},
      ).withFilter(
        'close',
        const ShipglowsBindingFilter(
          excluded: {'vim.exe'},
          only: {'Notepad.exe'},
        ),
      );
      final read = ShipglowsHotkeySettings.fromJson(settings.toJson());
      expect(read, settings);
      expect(read.enabled, isFalse);
      expect(read.excludedProcesses, {'code.exe', 'game.exe'});
      expect(read.filterOf('close').only, {'notepad.exe'});
    });

    test('process names are compared in lower case', () {
      expect(shipglowsProcessName('  Code.EXE '), 'code.exe');
    });

    test('an empty filter is forgotten', () {
      final settings = const ShipglowsHotkeySettings()
          .withFilter(
            'a',
            const ShipglowsBindingFilter(excluded: {'x.exe'}),
          )
          .withFilter('a', const ShipglowsBindingFilter());
      expect(settings.filters, isEmpty);
    });

    test('garbage reads as the defaults', () {
      expect(
        ShipglowsHotkeySettings.fromJson('nope'),
        const ShipglowsHotkeySettings(),
      );
      final read = ShipglowsHotkeySettings.fromJson({
        'enabled': 3,
        'excluded': [1, 'a.exe', null],
        'bindings': {'x': 'bad', 4: {}},
      });
      expect(read.enabled, isTrue);
      expect(read.excludedProcesses, {'a.exe'});
      expect(read.filterOf('x').isEmpty, isTrue);
    });

    test('equality ignores the order of the lists', () {
      expect(
        const ShipglowsHotkeySettings(excludedProcesses: {'a.exe', 'b.exe'}),
        const ShipglowsHotkeySettings(excludedProcesses: {'b.exe', 'a.exe'}),
      );
    });
  });

  group('ShipglowsHotkeyMemoryStore', () {
    test('keeps choices and settings', () async {
      final store = ShipglowsHotkeyMemoryStore();
      expect(await store.load(), isEmpty);
      expect((await store.loadSettings()).enabled, isTrue);

      await store.save({'a': const ShipglowsDoubleKeyTrigger(0x1B), 'b': null});
      await store.saveSettings(
        const ShipglowsHotkeySettings(excludedProcesses: {'x.exe'}),
      );

      final choices = await store.load();
      expect(choices.keys, containsAll(['a', 'b']));
      expect(choices['b'], isNull);
      expect((await store.loadSettings()).excludedProcesses, {'x.exe'});
    });
  });
}
