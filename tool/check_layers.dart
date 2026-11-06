// Checks the layers of flutter/: each package only depends on the layers its own
// layer may use, core stays free of Flutter, and every folder is a known layer.
//
//   dart tool/check_layers.dart
//
// Run by hand: exit code 1 lists the violations. Reads files only.
import 'dart:io';

const allowed = <String, Set<String>>{
  'foundation': {'foundation'},
  'core': {'core'},
  'services': {'foundation', 'core', 'services'},
  'components': {'foundation', 'core', 'components'},
  'features': {'foundation', 'core', 'services', 'components'},
  'desktop': {'foundation', 'core', 'services', 'components', 'desktop'},
};

final _dependencySection = RegExp(r'^dependencies:\s*$');
final _topLevelKey = RegExp(r'^\S');
final _dependencyName = RegExp(r'^  ([a-zA-Z_]\w*):');

void main() {
  final root = Directory.fromUri(
    Platform.script.resolve('../flutter/'),
  ).absolute.path;
  final problems = <String>[];
  final layerOf = <String, String>{};
  final pubspecs = <String, File>{};

  for (final entry in Directory(root).listSync()) {
    if (entry is! Directory) continue;
    final layer = entry.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    if (layer.startsWith('.')) continue;
    if (!allowed.containsKey(layer)) {
      problems.add('flutter/$layer is not a known layer');
      continue;
    }
    for (final package in entry.listSync().whereType<Directory>()) {
      final name = package.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      final pubspec = File('${package.path}/pubspec.yaml');
      if (!pubspec.existsSync()) continue;
      layerOf[name] = layer;
      pubspecs[name] = pubspec;
    }
  }

  pubspecs.forEach((name, pubspec) {
    final layer = layerOf[name]!;
    for (final dependency in _dependencies(pubspec)) {
      if (dependency == 'flutter' && layer == 'core') {
        problems.add('$name (core) declares Flutter');
      }
      final other = layerOf[dependency];
      if (other != null && !allowed[layer]!.contains(other)) {
        problems.add('$name ($layer) must not depend on $dependency ($other)');
      }
    }
    if (layer == 'core') {
      final lib = Directory('${pubspec.parent.path}/lib');
      for (final file in lib.listSync(recursive: true).whereType<File>()) {
        if (file.path.endsWith('.dart') &&
            file.readAsStringSync().contains('package:flutter/')) {
          problems.add('$name (core) imports Flutter in ${file.path}');
        }
      }
    }
  });

  if (problems.isEmpty) {
    stdout.writeln('${pubspecs.length} packages, layers respected.');
    return;
  }
  problems.forEach(stderr.writeln);
  exitCode = 1;
}

Iterable<String> _dependencies(File pubspec) sync* {
  var inside = false;
  for (final line in pubspec.readAsLinesSync()) {
    if (_dependencySection.hasMatch(line)) {
      inside = true;
    } else if (_topLevelKey.hasMatch(line)) {
      inside = false;
    } else if (inside) {
      final match = _dependencyName.firstMatch(line);
      if (match != null) yield match.group(1)!;
    }
  }
}
