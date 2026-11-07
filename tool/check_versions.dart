// Lists third-party dependencies declared with different constraints across the
// sibling repositories, so an upgrade reaches every package at once. Reads files
// only; exit code 1 lists the differences.
//
//   dart tool/check_versions.dart
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
  'tools',
  'ios',
  'android',
  'windows',
  'linux',
  'macos',
  'web',
};

/// Frozen repositories, kept out of the comparison.
const _ignoredRepositories = {'jarretelacoke', 'shipglows-window-engine'};

final _section = RegExp(r'^(dev_)?dependencies:\s*$');
final _topLevel = RegExp(r'^\S');
final _entry = RegExp(r'''^  ([a-z_0-9]+):\s*["']?([^"'\s#]+)''');

void main() {
  final workspace = Directory.fromUri(Platform.script.resolve('../../'));
  final constraints = <String, Map<String, List<String>>>{};
  for (final repository in workspace.listSync().whereType<Directory>()) {
    if (_ignoredRepositories.contains(_name(repository))) continue;
    if (!Directory('${repository.path}/.git').existsSync()) continue;
    _collect(repository, _name(repository), constraints);
  }
  final differing =
      constraints.entries.where((entry) => entry.value.length > 1).toList()
        ..sort((a, b) => a.key.compareTo(b.key));
  if (differing.isEmpty) {
    stdout.writeln('${constraints.length} dependencies, one constraint each.');
    return;
  }
  for (final dependency in differing) {
    stderr.writeln(dependency.key);
    dependency.value.forEach((constraint, users) {
      stderr.writeln('  $constraint: ${users.join(', ')}');
    });
  }
  exitCode = 1;
}

void _collect(
  Directory directory,
  String label,
  Map<String, Map<String, List<String>>> constraints,
) {
  final pubspec = File('${directory.path}/pubspec.yaml');
  if (pubspec.existsSync()) {
    var inside = false;
    for (final line in pubspec.readAsLinesSync()) {
      if (_section.hasMatch(line)) {
        inside = true;
      } else if (_topLevel.hasMatch(line)) {
        inside = false;
      } else if (inside) {
        final match = _entry.firstMatch(line);
        final constraint = match?.group(2);
        // Only caret ranges: an exact version is a deliberate pin.
        if (match != null && constraint != null && constraint.startsWith('^')) {
          constraints
              .putIfAbsent(match.group(1)!, () => {})
              .putIfAbsent(constraint, () => [])
              .add(label);
        }
      }
    }
  }
  for (final child in directory.listSync().whereType<Directory>()) {
    final name = _name(child);
    if (!_skipped.contains(name)) _collect(child, '$label/$name', constraints);
  }
}

String _name(Directory directory) =>
    directory.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
