// One command to know whether a repository still holds: analyzes and tests its
// Dart packages, in sequence, and never builds. Run it by hand from anywhere:
//
//   dart <app-engine>/tool/verify.dart [dir] [--no-tests]
//
// dir is a repository or a package (default: current directory). A workspace is
// analyzed once from its root. Experiments and vendored code are skipped: see
// _skipped. In the app engine it also runs the layer and version checks. Exit
// code 1 lists what failed. It runs `--no-pub`: run `flutter pub get` first.
import 'dart:io';

const _skipped = {
  '.dart_tool',
  '.git',
  'build',
  'node_modules',
  'third_party',
  'spikes',
  'fixtures',
  'example',
  'demo',
  'ios',
  'android',
  'windows',
  'linux',
  'macos',
  'web',
};

Future<void> main(List<String> args) async {
  final withTests = !args.contains('--no-tests');
  final paths = args.where((a) => !a.startsWith('--')).toList();
  final target = Directory(paths.isEmpty ? '.' : paths.first).absolute;
  if (!target.existsSync()) {
    stderr.writeln('${target.path} does not exist');
    exitCode = 2;
    return;
  }

  final tools = File.fromUri(Platform.script).parent.path;
  final failures = <String>[];
  Future<void> step(
    String label,
    String command,
    List<String> arguments,
    String directory,
  ) async {
    stdout.writeln('--- $label');
    final result = await Process.run(
      command,
      arguments,
      workingDirectory: directory,
      runInShell: true,
    );
    if (result.exitCode == 0) {
      stdout.writeln('ok');
      return;
    }
    failures.add(label);
    final output = '${result.stdout}\n${result.stderr}'.trim().split('\n');
    final start = output.length > 40 ? output.length - 40 : 0;
    stdout.writeln(output.sublist(start).join('\n'));
  }

  final packages = _packages(target).toList();
  if (packages.isEmpty) stdout.writeln('No Dart package in ${target.path}.');

  if (_normal(target.path) == _normal(Directory(tools).parent.path)) {
    await step('layers', 'dart', ['$tools/check_layers.dart'], target.path);
    await step('versions', 'dart', ['$tools/check_versions.dart'], target.path);
  }

  final analyzed = <String>{};
  for (final package in packages) {
    final root = _workspaceRootOf(package) ?? package;
    if (analyzed.add(root.path)) {
      await step(
        'analyze ${_relative(root.path, target.path)}',
        'flutter',
        ['analyze', '--no-pub', '--no-fatal-infos'],
        root.path,
      );
    }
    if (withTests && _hasTests(package)) {
      await step(
        'test ${_relative(package.path, target.path)}',
        'flutter',
        ['test', '--no-pub', '--reporter=compact'],
        package.path,
      );
    }
  }

  if (failures.isEmpty) {
    stdout.writeln('\nVerified.');
    return;
  }
  stdout.writeln('\nFailed:');
  for (final failure in failures) {
    stdout.writeln('  $failure');
  }
  exitCode = 1;
}

Iterable<Directory> _packages(Directory directory) sync* {
  final pubspec = File('${directory.path}/pubspec.yaml');
  if (pubspec.existsSync() && !_declaresWorkspace(pubspec)) yield directory;
  final children = directory.listSync().whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final child in children) {
    final name = child.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    if (!_skipped.contains(name)) yield* _packages(child);
  }
}

bool _hasTests(Directory package) {
  final tests = Directory('${package.path}/test');
  return tests.existsSync() &&
      tests
          .listSync(recursive: true)
          .any((entry) => entry is File && entry.path.endsWith('_test.dart'));
}

Directory? _workspaceRootOf(Directory package) {
  final text = File('${package.path}/pubspec.yaml').readAsStringSync();
  if (!text.contains('resolution: workspace')) return null;
  var current = package.parent;
  while (current.parent.path != current.path) {
    final pubspec = File('${current.path}/pubspec.yaml');
    if (pubspec.existsSync() && _declaresWorkspace(pubspec)) return current;
    current = current.parent;
  }
  return null;
}

bool _declaresWorkspace(File pubspec) =>
    RegExp(r'^workspace:', multiLine: true).hasMatch(pubspec.readAsStringSync());

String _normal(String path) => path
    .replaceAll('\\', '/')
    .replaceAll(RegExp(r'(/\.)?/*$'), '')
    .toLowerCase();

String _relative(String path, String base) {
  final clean = _normal(path);
  final prefix = _normal(base).length;
  return clean.length > prefix ? path.substring(prefix + 1) : '.';
}
