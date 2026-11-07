import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shipglows_test_kit/shipglows_test_kit.dart';

void main() {
  testWidgets('reducedMotionBuilder disables animations', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: reducedMotionBuilder,
        home: Builder(
          builder: (context) => Text(
            MediaQuery.disableAnimationsOf(context) ? 'still' : 'moving',
          ),
        ),
      ),
    );
    expect(find.text('still'), findsOneWidget);
  });

  group('useTemporaryAppFolders', () {
    late Directory kept;

    test('points path_provider at the folder', () async {
      kept = useTemporaryAppFolders();
      expect(
        await PathProviderPlatform.instance.getApplicationDocumentsPath(),
        kept.path,
      );
    });

    test('removes the folder after the test', () {
      expect(kept.existsSync(), isFalse);
    });
  });

  test('useMemoryPreferences starts from the given values', () async {
    final prefs = await useMemoryPreferences({'a': 1});
    expect(prefs.getInt('a'), 1);
    final clean = await useMemoryPreferences();
    expect(clean.getInt('a'), isNull);
  });
}
