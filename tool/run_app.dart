import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.isEmpty) throw ArgumentError('Expected an application directory.');
  final process = await Process.start(
    'flutter',
    [
      'run',
      if (args.length > 1) ...['-d', args[1]],
    ],
    workingDirectory: args.first,
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  exitCode = await process.exitCode;
}
