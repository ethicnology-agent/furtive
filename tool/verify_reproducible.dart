import 'dart:io';

import 'build_release.dart' show sha256;

/// Builds the release artefact twice from identical inputs and compares the
/// digests. Passing means the two runs produced the same bytes; it does not
/// mean a third party rebuilding from a different package mirror would, which
/// is a separate claim the README is careful about.
Future<void> main(List<String> args) async {
  final environment = Platform.environment;
  final mode = environment['MODE']?.trim();
  final format = environment['FORMAT']?.trim();
  final output =
      './app-${mode?.isNotEmpty == true ? mode : 'release'}.'
      '${format?.isNotEmpty == true ? format : 'apk'}';

  stdout.writeln('🔁 Reproducibility check: building twice and comparing');
  final digests = <String>[];
  for (final run in const ['run1', 'run2']) {
    final result = await Process.start(Platform.resolvedExecutable, [
      'run',
      'tool/build_release.dart',
    ], mode: ProcessStartMode.inheritStdio);
    final status = await result.exitCode;
    if (status != 0) {
      exitCode = status;
      return;
    }
    final digest = await sha256(output);
    stdout.writeln('$run: $digest');
    digests.add(digest.split(RegExp(r'\s+')).first);
    File(output).renameSync('$output.$run');
  }

  if (digests[0] == digests[1]) {
    File('$output.run2').deleteSync();
    File('$output.run1').renameSync(output);
    stdout.writeln('✅ Bit-identical');
    return;
  }
  stderr.writeln(
    '❌ Differs. Investigate with: diffoscope $output.run1 $output.run2',
  );
  exitCode = 1;
}
