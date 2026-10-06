import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Checks formatting across every workspace member, derived rather than listed.
///
/// The paths were enumerated in the melos script before this, which made the
/// workspace's shape something written down twice: adding a module and
/// forgetting the second copy left it unformatted with a green check. Reading
/// the member list means the only way to escape this is to not be a member,
/// and tool/check_architecture.dart already refuses that.
///
/// Generated output is skipped by naming the source directories instead of the
/// member root: `build/` is not hidden, so formatting a member wholesale would
/// walk whatever the last test run left behind.
const _sourceDirectories = ['lib', 'test', 'web', 'example'];

Future<void> main(List<String> args) async {
  final root = Directory.current;
  final manifest =
      loadYaml(File(p.join(root.path, 'pubspec.yaml')).readAsStringSync())
          as YamlMap;
  final members = (manifest['workspace'] as YamlList? ?? YamlList())
      .cast<String>();

  final targets = <String>[
    for (final member in members)
      for (final directory in _sourceDirectories)
        if (Directory(p.join(root.path, member, directory)).existsSync())
          p.join(member, directory),
    // The workspace root is not a member, and its tools are source too.
    'tool',
  ];

  stdout.writeln(
    'Checking ${targets.length} directories across '
    '${members.length} members.',
  );
  final result = await Process.start('dart', [
    'format',
    '--output=none',
    '--set-exit-if-changed',
    ...targets,
  ], mode: ProcessStartMode.inheritStdio);
  exitCode = await result.exitCode;
}
