import 'dart:convert';
import 'dart:io';

/// A zero exit code alone does not establish that a test run completed.
class TestReport {
  bool completed = false;
  bool failed = false;
  int passed = 0;

  void add(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'error':
        failed = true;
      case 'testDone':
        if (event['result'] != 'success') failed = true;
        if (event['result'] == 'success' &&
            event['hidden'] != true &&
            event['skipped'] != true) {
          passed++;
        }
      case 'done':
        completed = event['success'] == true;
    }
  }

  bool get succeeded => completed && !failed && passed > 0;
}

Future<void> main(List<String> args) async {
  final flutter = args.firstOrNull == 'flutter';
  final process = await Process.start(
    flutter ? 'flutter' : Platform.resolvedExecutable,
    ['test', if (flutter) '--no-pub', '--reporter=json', ...args.skip(1)],
    runInShell: Platform.isWindows,
  );
  final report = TestReport();
  // Forward child stderr without binding this sink: reporter writes must
  // stay possible while the child is still running.
  final errors = process.stderr.listen(stderr.add).asFuture<void>();
  await for (final line
      in process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
    try {
      final event = jsonDecode(line) as Map<String, dynamic>;
      report.add(event);
      if (event['type'] == 'error') stderr.writeln(event['error']);
      if (event['type'] == 'testStart') {
        stdout.writeln((event['test'] as Map<String, dynamic>)['name']);
      }
    } on FormatException {
      stdout.writeln(line);
    }
  }
  await errors;
  final status = await process.exitCode;
  if (status != 0 || !report.succeeded) {
    stderr.writeln('Test run failed or incomplete (${report.passed} passed).');
    exitCode = 1;
  } else {
    stdout.writeln('${report.passed} tests passed; completion verified.');
  }
}
