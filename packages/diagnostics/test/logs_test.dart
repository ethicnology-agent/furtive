import 'dart:io';

import 'package:diagnostics/diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('diagnostics_test');
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  Future<String> read(MyLogs subject) async {
    await subject.flush();
    return subject.logsFile.readAsString();
  }

  test('a fresh log opens with the header its owner supplies', () async {
    final subject = MyLogs.init(
      directory: directory,
      context: () => const ['Version: 1.2.3+4', 'Model: Pixel 6a'],
    );

    await subject.ensureLogsExist();

    final content = await read(subject);
    expect(content, contains('Version: 1.2.3+4'));
    expect(content, contains('Model: Pixel 6a'));
  });

  test('without a context the header is empty, not a default one', () async {
    final subject = MyLogs.init(directory: directory);

    await subject.ensureLogsExist();

    final content = await read(subject);
    expect(content, contains('Logs created'));
    expect(content, isNot(contains('Version:')));
    expect(content, isNot(contains('Model:')));
  });

  test('an existing log is not re-headed on the next launch', () async {
    final first = MyLogs.init(
      directory: directory,
      context: () => const ['Version: 1.2.3+4'],
    );
    await first.ensureLogsExist();
    await read(first);

    final second = MyLogs.init(
      directory: directory,
      context: () => const ['Version: 1.2.3+4'],
    );
    await second.ensureLogsExist();

    final content = await read(second);
    expect('Version: 1.2.3+4'.allMatches(content).length, 1);
  });

  test('an oversized log is trimmed to whole lines under the cap', () async {
    final subject = MyLogs.init(directory: directory);
    // One line per 100 bytes, comfortably past the 1 MB cap.
    final line = 'x' * 99;
    await subject.logsFile.writeAsString(
      List.filled(12000, line).join('\n'),
      mode: FileMode.append,
    );
    final before = await subject.logsFile.length();
    expect(before, greaterThan(1024 * 1024));

    await subject.ensureLogsExist();

    final content = await read(subject);
    expect(content.length, lessThan(before));
    expect(
      content.split('\n').where((l) => l.isNotEmpty),
      everyElement(hasLength(99)),
      reason: 'a trimmed file must not start mid-record',
    );
  });
}
