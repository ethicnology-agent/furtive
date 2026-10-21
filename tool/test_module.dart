import 'dart:convert';
import 'dart:io';

/// A zero exit code alone does not establish that a test run completed.
///
/// The JSON reporter splits a failure across two events: `testDone` carries
/// the verdict, while what actually went wrong — the expectation, the diff,
/// anything the test printed — arrives as `error` and `print` events keyed by
/// test id. Forwarding only the verdict leaves a CI log that says a test
/// failed and nothing about why, which is how a golden failure reached a
/// reviewer as four words.
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
  // Failures name their test by id, which only `testStart` spells out.
  final names = <Object?, String>{};
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
      switch (event['type']) {
        case 'error':
          stderr.writeln(names[event['testID']] ?? '');
          stderr.writeln(event['error']);
          final trace = event['stackTrace'];
          if (trace is String && trace.trim().isNotEmpty) stderr.writeln(trace);
        case 'print':
          stdout.writeln(event['message']);
        case 'testStart':
          final test = event['test'] as Map<String, dynamic>;
          names[test['id']] = test['name'] as String;
          stdout.writeln(test['name']);
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
