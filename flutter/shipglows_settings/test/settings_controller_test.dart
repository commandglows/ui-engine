import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_settings/shipglows_settings.dart';

final theme = SettingKey.choice(
  'themeMode',
  values: ThemeMode.values,
  defaultValue: ThemeMode.system,
);
final sounds = SettingKey.boolean('sounds', defaultValue: true);
final windowWidth = SettingKey.integer(
  'windowWidth',
  defaultValue: 800,
  scope: SettingScope.device,
);
final schema = SettingsSchema(keys: [theme, sounds, windowWidth]);

SettingsController controllerFor(
  SettingsStorage storage, {
  DateTime Function()? clock,
}) => SettingsController(
  schema: schema,
  storage: storage,
  observeAppLifecycle: false,
  clock: clock,
);

void main() {
  test('reads defaults, saves on the device and reloads', () async {
    final storage = MemorySettingsStorage();
    final first = controllerFor(storage);
    await first.open();
    expect(first.get(theme), ThemeMode.system);

    await first.set(theme, ThemeMode.dark);
    await first.set(windowWidth, 1200);

    final second = controllerFor(storage);
    await second.open();
    expect(second.get(theme), ThemeMode.dark);
    expect(second.get(windowWidth), 1200);
  });

  test('bad stored data falls back to the default', () async {
    final storage = MemorySettingsStorage({
      SettingsController.localAccountBucket: {
        'v': 1,
        'values': {'themeMode': 'purple', 'sounds': 'false'},
      },
    });
    final controller = controllerFor(storage);
    await controller.open();
    expect(controller.get(theme), ThemeMode.system);
    expect(controller.get(sounds), isFalse);
  });

  test('imports legacy values once, on a fresh device', () async {
    final storage = MemorySettingsStorage();
    var calls = 0;
    Future<Map<String, Object?>> legacy() async {
      calls++;
      return {'themeMode': 'light', 'windowWidth': '640'};
    }

    final first = controllerFor(storage);
    await first.open(importLegacy: legacy);
    expect(first.get(theme), ThemeMode.light);
    expect(first.get(windowWidth), 640);

    final second = controllerFor(storage);
    await second.open(importLegacy: legacy);
    expect(calls, 1);
  });

  test('pushes only the changed field', () async {
    final remote = MemorySettingsRemote(initial: {'sounds': false});
    final controller = controllerFor(MemorySettingsStorage());
    await controller.open();
    await controller.setAccount(SettingsAccount(id: 'u1', remote: remote));
    await controller.sync();
    expect(controller.get(sounds), isFalse);

    await controller.set(theme, ThemeMode.dark);
    await controller.sync();
    expect(remote.pushes.last, {'themeMode': 'dark'});
    expect(remote.values, {'sounds': false, 'themeMode': 'dark'});
    expect(controller.status.health, SyncHealth.synced);
  });

  test('a failed push keeps the device value and stays pending', () async {
    final remote = MemorySettingsRemote()..failWith = StateError('offline');
    final storage = MemorySettingsStorage();
    final controller = controllerFor(storage);
    await controller.open();
    await controller.setAccount(SettingsAccount(id: 'u1', remote: remote));
    await controller.set(theme, ThemeMode.dark);
    await controller.sync();
    expect(controller.get(theme), ThemeMode.dark);
    // Never read on this device: the account is unreachable, not just behind.
    expect(controller.status.health, SyncHealth.unreachable);

    // Relaunch while still offline: the pending field survives.
    final relaunched = controllerFor(storage);
    await relaunched.open();
    await relaunched.setAccount(SettingsAccount(id: 'u1', remote: remote));
    await relaunched.sync();
    expect(relaunched.get(theme), ThemeMode.dark);

    remote.failWith = null;
    await relaunched.sync();
    expect(remote.values, {'themeMode': 'dark'});
    expect(relaunched.status.health, SyncHealth.synced);
    controller.dispose();
    relaunched.dispose();
  });

  test('a pending field is not overwritten by a pull', () async {
    final remote = MemorySettingsRemote(initial: {'themeMode': 'light'});
    final controller = controllerFor(MemorySettingsStorage());
    await controller.open();
    await controller.setAccount(SettingsAccount(id: 'u1', remote: remote));
    await controller.sync();
    remote.failWith = StateError('offline');
    await controller.set(theme, ThemeMode.dark);
    await controller.sync();
    remote.failWith = null;
    await remote.push({'sounds': false}); // another device
    await controller.sync();
    expect(controller.get(theme), ThemeMode.dark);
    expect(controller.get(sounds), isFalse);
    expect(remote.values!['themeMode'], 'dark');
    controller.dispose();
  });

  test('two devices editing different fields keep both', () async {
    final remote = MemorySettingsRemote();
    final a = controllerFor(MemorySettingsStorage());
    final b = controllerFor(MemorySettingsStorage());
    for (final device in [a, b]) {
      await device.open();
      await device.setAccount(SettingsAccount(id: 'u1', remote: remote));
    }
    await a.set(theme, ThemeMode.dark);
    await b.set(sounds, false);
    await a.sync();
    await b.sync();
    await a.sync();
    expect(a.get(sounds), isFalse);
    expect(b.get(theme), ThemeMode.dark);
  });

  test('accounts never see each other, signed-out values seed a new one', () async {
    final storage = MemorySettingsStorage();
    final remote1 = MemorySettingsRemote();
    final remote2 = MemorySettingsRemote(initial: {'themeMode': 'light'});
    final controller = controllerFor(storage);
    await controller.open();
    await controller.set(theme, ThemeMode.dark); // signed out

    await controller.setAccount(SettingsAccount(id: 'u1', remote: remote1));
    await controller.sync();
    expect(controller.get(theme), ThemeMode.dark);
    expect(remote1.values, {'themeMode': 'dark'});

    // Both sides set the theme differently: nothing moves until chosen.
    await controller.setAccount(SettingsAccount(id: 'u2', remote: remote2));
    await controller.sync();
    expect(controller.status.health, SyncHealth.needsReview);
    expect(controller.get(theme), ThemeMode.dark);
    expect(remote2.pushes, isEmpty);
    expect(
      await controller.resolveReview({'fields/themeMode': SyncSide.account}),
      isTrue,
    );
    await controller.sync();
    expect(controller.get(theme), ThemeMode.light);
    expect(remote2.pushes, isEmpty);
    expect(controller.recovery?.device.fields['themeMode'], 'dark');

    await controller.set(sounds, false);
    await controller.setAccount(SettingsAccount(id: 'u1', remote: remote1));
    expect(controller.get(sounds), isTrue);
    controller.dispose();
  });

  test('an auth refusal stops retrying until the account changes', () async {
    final remote = MemorySettingsRemote()
      ..failWith = const SettingsRemoteAuthException();
    final controller = controllerFor(MemorySettingsStorage());
    await controller.open();
    await controller.setAccount(SettingsAccount(id: 'u1', remote: remote));
    await controller.sync();
    expect(controller.status.health, SyncHealth.failed);
    expect(controller.status.issue?.retryable, isFalse);
    controller.dispose();
  });

  test('migrates stored values to the schema version', () async {
    final renamed = SettingKey.boolean('playSounds', defaultValue: true);
    final v2 = SettingsSchema(
      version: 2,
      keys: [renamed],
      migrations: {
        2: (values) => {...values, 'playSounds': values.remove('sounds')},
      },
    );
    final storage = MemorySettingsStorage({
      SettingsController.localAccountBucket: {
        'v': 1,
        'values': {'sounds': false},
      },
    });
    final controller = SettingsController(
      schema: v2,
      storage: storage,
      observeAppLifecycle: false,
    );
    await controller.open();
    expect(controller.get(renamed), isFalse);
    expect(storage.buckets[SettingsController.localAccountBucket]!['v'], 2);
  });

  test('listenable notifies only when its own setting changes', () async {
    final controller = controllerFor(MemorySettingsStorage());
    await controller.open();
    var calls = 0;
    controller.listenable(theme).addListener(() => calls++);
    await controller.set(sounds, false);
    await controller.set(theme, ThemeMode.dark);
    await controller.set(theme, ThemeMode.dark);
    expect(calls, 1);
  });

  group('nested map fields', () {
    final robot = SettingKey.map('robotSettings');
    final mapSchema = SettingsSchema(keys: [robot]);
    SettingsController mapController() => SettingsController(
      schema: mapSchema,
      storage: MemorySettingsStorage(),
      observeAppLifecycle: false,
    );

    test('pushes only the nested field that changed', () async {
      final remote = MemorySettingsRemote(
        initial: {
          'robotSettings': {
            'ideaPoolEnabled': false,
            'contentFrequency': {'linkedin': 2, 'x': 5},
          },
        },
      );
      final controller = mapController();
      await controller.open();
      await controller.setAccount(SettingsAccount(id: 'u1', remote: remote));
      await controller.sync();

      await controller.setField(robot, ['contentFrequency', 'linkedin'], 4);
      await controller.sync();
      expect(remote.pushes.last, {
        'robotSettings': {
          'contentFrequency': {'linkedin': 4},
        },
      });
      expect(remote.values!['robotSettings'], {
        'ideaPoolEnabled': false,
        'contentFrequency': {'linkedin': 4, 'x': 5},
      });
      controller.dispose();
    });

    test('a pull keeps the pending nested field and takes the others', () async {
      final remote = MemorySettingsRemote(
        initial: {
          'robotSettings': {'ideaPoolEnabled': false, 'aiRuntime': 'byok'},
        },
      );
      final controller = mapController();
      await controller.open();
      await controller.setAccount(SettingsAccount(id: 'u1', remote: remote));
      await controller.sync();
      remote.failWith = StateError('offline');
      await controller.setField(robot, ['ideaPoolEnabled'], true);
      await controller.sync();

      // Another device changes a sibling field.
      remote.failWith = null;
      await remote.push({
        'robotSettings': {'aiRuntime': 'platform'},
      });
      await controller.sync();
      expect(controller.get(robot), {
        'ideaPoolEnabled': true,
        'aiRuntime': 'platform',
      });
      expect(remote.values!['robotSettings'], {
        'ideaPoolEnabled': true,
        'aiRuntime': 'platform',
      });
      controller.dispose();
    });
  });

  group('records created offline', () {
    final project = SettingKey<String?>(
      'defaultProjectId',
      defaultValue: null,
      codec: SettingCodec.string.nullable(),
    );
    final idSchema = SettingsSchema(keys: [project, sounds]);

    test('a field holding a temporary id waits for the server id', () async {
      final remote = MemorySettingsRemote();
      final controller = SettingsController(
        schema: idSchema,
        storage: MemorySettingsStorage(),
        observeAppLifecycle: false,
        isTemporaryId: (id) => id.startsWith('offline-'),
      );
      await controller.open();
      await controller.setAccount(SettingsAccount(id: 'u1', remote: remote));
      await controller.sync();

      await controller.edit(
        (e) => e
          ..set(project, 'offline-1')
          ..set(sounds, false),
      );
      await controller.sync();
      // The other field goes; the project waits, shown on the device.
      expect(remote.values, {'sounds': false});
      expect(controller.get(project), 'offline-1');
      expect(controller.status.health, SyncHealth.pending);

      await controller.rewriteIds({'offline-1': 'proj_42'});
      await controller.sync();
      expect(controller.get(project), 'proj_42');
      expect(remote.values, {'sounds': false, 'defaultProjectId': 'proj_42'});
      expect(controller.status.health, SyncHealth.synced);
      controller.dispose();
    });
  });
}
