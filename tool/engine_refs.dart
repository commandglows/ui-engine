// Pins the shared engines an app builds with, in the `engine-refs` file that
// provide-engines.sh reads on a single-repository host. A local checkout always
// uses the sibling folders, whatever is pinned.
//
//   dart tool/engine_refs.dart status [app-dir]   Compares pins with the engines
//   dart tool/engine_refs.dart update [app-dir]   Pins each engine's local HEAD
//
// app-dir holds the pubspec.yaml (default: current directory). A pinned commit
// must reach GitHub before the app does, or the host's clone fails: `status`
// exits 1 for a commit not pushed yet, a missing pin or a pin behind HEAD.
import 'dart:io';

const _repositories = {
  'shipglows-app-engine': 'app-engine',
  'shipglows-audio-engine': 'audio-engine',
  'shipglows-email-engine': 'email-engine',
  'shipglows-analytics-engine': 'analytics-engine',
};

final _pathDependency = RegExp(
  r'''^\s+path:\s*["']?(\.\.?/[^"'\s#]+)''',
  multiLine: true,
);
final _space = RegExp(r'\s+');

void main(List<String> args) {
  final command = args.isEmpty ? 'status' : args.first;
  if (command != 'status' && command != 'update') {
    stderr.writeln('Usage: engine_refs.dart status|update [app-dir]');
    exitCode = 2;
    return;
  }
  final app = Directory(args.length > 1 ? args[1] : '.').absolute;
  final engines = _enginesOf(app);
  final file = File('${app.path}/engine-refs');

  if (command == 'update') {
    final lines = [
      for (final entry in engines.entries) '${entry.key} ${_head(entry.value)}',
    ]..sort();
    file.writeAsStringSync(lines.isEmpty ? '' : '${lines.join('\n')}\n');
  }

  final pins = <String, String>{};
  if (file.existsSync()) {
    for (final line in file.readAsLinesSync()) {
      final parts = line.trim().split(_space);
      if (parts.length == 2) pins[parts.first] = parts.last;
    }
  }

  var problems = 0;
  engines.forEach((repository, checkout) {
    final pin = pins[repository];
    final head = _head(checkout);
    final String state;
    if (pin == null) {
      state = 'not pinned';
      problems++;
    } else if (!_pushed(checkout, pin)) {
      state = '${pin.substring(0, 8)} not pushed yet';
      problems++;
    } else if (pin != head) {
      state = '${pin.substring(0, 8)} behind HEAD ${head.substring(0, 8)}';
      problems++;
    } else {
      state = '${pin.substring(0, 8)} current';
    }
    stdout.writeln('$repository: $state');
  });
  if (engines.isEmpty) stdout.writeln('No engine dependency.');
  if (command == 'status' && problems > 0) exitCode = 1;
}

/// Engine checkouts reached by the path dependencies of [app], transitively.
Map<String, Directory> _enginesOf(Directory app) {
  final engines = <String, Directory>{};
  final seen = <String>{};
  final queue = [app.resolveSymbolicLinksSync()];
  while (queue.isNotEmpty) {
    final directory = queue.removeLast();
    if (!seen.add(directory)) continue;
    final pubspec = File('$directory/pubspec.yaml');
    if (!pubspec.existsSync()) continue;
    final text = pubspec.readAsStringSync();
    for (final match in _pathDependency.allMatches(text)) {
      final target = Directory('$directory/${match.group(1)!}');
      if (!target.existsSync()) continue;
      final resolved = target.resolveSymbolicLinksSync();
      queue.add(resolved);
      final segments = resolved.replaceAll('\\', '/').split('/');
      for (var i = 0; i < segments.length; i++) {
        final repository = _repositories[segments[i]];
        if (repository != null) {
          engines[repository] = Directory(segments.take(i + 1).join('/'));
        }
      }
    }
  }
  return engines;
}

String _head(Directory checkout) => _git(checkout, ['rev-parse', 'HEAD']);

bool _pushed(Directory checkout, String commit) =>
    _git(checkout, ['branch', '-r', '--contains', commit]).isNotEmpty;

String _git(Directory checkout, List<String> args) {
  final result = Process.runSync('git', ['-C', checkout.path, ...args]);
  return result.exitCode == 0 ? (result.stdout as String).trim() : '';
}
