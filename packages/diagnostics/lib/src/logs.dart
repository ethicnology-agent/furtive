import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging_colorful/logging_colorful.dart' as dep;
export 'package:logging_colorful/logging_colorful.dart';

MyLogs logs = MyLogs.init();

/// Supplies the environment header written at the top of a fresh log file.
typedef DiagnosticContext = List<String> Function();

List<String> _noContext() => const [];

class MyLogs {
  final Directory dir;
  final dep.LoggerColorful logger;
  final DiagnosticContext context;
  static const _logFilename = 'logs.tsv';

  /// Hard cap for the log file. Every level, including INFO, is persisted
  /// (see the listener below) so a session can be fully reconstructed from
  /// the in-app Logs page without a computer/adb attached. With no rotation
  /// a long-lived install would still accumulate indefinitely — bad for disk
  /// usage AND privacy (older session data sitting on disk forever).
  /// Trimmed on startup from `ensureLogsExist`.
  static const _maxLogBytes = 1024 * 1024; // 1 MB
  File get logsFile => File('${dir.path}/$_logFilename');

  Future<void>? _currentWrite;

  // B25: a single listener subscribes to Logger.root. The top-level
  // `logs = MyLogs.init()` runs before main reassigns to the real instance.
  // Without this guard, both instances would subscribe and every log line
  // would be written twice — to two different files.
  static StreamSubscription<dep.LogRecord>? _rootSubscription;

  MyLogs._(this.dir, this.logger, this.context) {
    dep.Logger.root.level = dep.Level.ALL;

    _rootSubscription?.cancel();
    _rootSubscription = dep.Logger.root.onRecord.listen((record) {
      final time = record.time.toIso8601String();
      final content = [time, record.level.name, record.message];

      final (:String error, :String trace) = record.stringifyErrorAndTrace();
      content.addAll([error, trace]);

      final sanitizedContent = content.map(logger.sanitize).toList();
      final tsvLine = sanitizedContent.join('\t');

      _queueWrite(tsvLine);

      if (kDebugMode) {
        final debug = content.sublist(1, 3);
        debugPrint(debug.join('\t'));
      }
    });
  }

  /// Serialise every mutation of the log file (appends, trim, delete) on a
  /// single chain so they can't interleave and tear a record. Each step
  /// swallows its own error so one failed write doesn't poison the chain and
  /// silently drop all later log lines.
  Future<void> _enqueue(Future<void> Function() op) {
    final next = () async {
      try {
        await _currentWrite;
      } catch (_) {}
      try {
        await op();
      } catch (_) {}
    }();
    _currentWrite = next;
    return next;
  }

  void _queueWrite(String log) {
    _enqueue(() => logsFile.writeAsString('$log\n', mode: FileMode.append));
  }

  /// Resolves once every record logged before this call has reached the file.
  ///
  /// Logging is fire-and-forget by design, which leaves a caller that has
  /// just logged unable to read the record back: the record first crosses
  /// `Logger.root`'s stream, which delivers on a microtask, and only then
  /// joins the write chain. Yielding to the event queue clears the first
  /// hop, and a no-op queued behind everything pending clears the second.
  Future<void> flush() async {
    await Future<void>.delayed(Duration.zero);
    await _enqueue(() async {});
  }

  MyLogs.init({
    String name = 'MyLogs',
    Directory? directory,
    DiagnosticContext context = _noContext,
  }) : this._(
         directory ?? Directory.current,
         // iOS emulator doesn't support colors –> https://github.com/flutter/flutter/issues/20663
         // We don't want colors in release mode either
         dep.LoggerColorful(
           name,
           disabledColors: Platform.isIOS || kReleaseMode,
         ),
         context,
       );

  Future<void> ensureLogsExist() async {
    try {
      if (await logsFile.exists()) {
        await _trimIfOversized();
        return;
      }

      await logsFile.create(recursive: true);
      fine('Logs created');
      addContextInfos();
    } catch (e) {
      severe('Logs existence: $e');
    }
  }

  /// Trim the log file by dropping the oldest lines if it has grown past
  /// [_maxLogBytes]. Keeps roughly the most recent 75% of the cap so we
  /// don't trim again on the very next launch.
  Future<void> _trimIfOversized() async {
    // Run on the write queue so a concurrent append can't interleave with the
    // truncate and lose or tear a line.
    await _enqueue(() async {
      final length = await logsFile.length();
      if (length <= _maxLogBytes) return;

      // Read the tail, find the first complete line within it, write back.
      final keepBytes = (_maxLogBytes * 0.75).round();
      final raf = await logsFile.open();
      try {
        await raf.setPosition(length - keepBytes);
        final tail = await raf.read(keepBytes);
        // Drop the leading partial line so we don't keep a half-record.
        final firstNl = tail.indexOf(0x0A); // '\n'
        final keep = firstNl >= 0 ? tail.sublist(firstNl + 1) : tail;
        await logsFile.writeAsBytes(keep);
      } finally {
        await raf.close();
      }
    });
  }

  /// Writes the environment header supplied by [context] at the top of a
  /// fresh log file, and again after the file is cleared.
  ///
  /// What belongs in that header — build version, device model, OS release —
  /// is the owner's knowledge, not this module's: reading it here would make
  /// diagnostics depend on the platform plugins that answer those questions,
  /// and would put the decision of what is safe to record in the wrong place.
  /// Whoever supplies the lines is responsible for keeping personal data out
  /// of them.
  void addContextInfos() {
    for (final line in context()) {
      config(line);
    }
  }

  Future<List<String>> readLogs() async {
    try {
      final logs = await logsFile.readAsString();
      return logs.split('\n').where((e) => e.isNotEmpty).toList();
    } catch (e) {
      severe('Failed to read logs: $e');
      rethrow;
    }
  }

  /// Logs information messages that are part of the normal operation of the app.
  /// These messages are typically written to file only and not kept in memory.
  /// Use for recording general app flow and user actions.
  void info(Object? message, {Object? error, StackTrace? trace}) {
    logger.info(message, error, trace);
  }

  /// Logs static configuration information at startup or during major configuration changes.
  /// Use for logging app settings, environment details, or significant state changes.
  void config(Object? message, {Object? error, StackTrace? trace}) {
    logger.config(message, error, trace);
  }

  /// Logs basic tracing information for debugging.
  /// Use for high-level flow tracking during development and troubleshooting.
  void fine(Object? message, {Object? error, StackTrace? trace}) {
    logger.fine(message, error, trace);
  }

  /// Logs detailed tracing information.
  /// Use for more granular debugging information than fine(), such as loop iterations or method entry/exit.
  void finer(Object? message, {Object? error, StackTrace? trace}) {
    logger.finer(message, error, trace);
  }

  /// Logs highly detailed tracing information.
  /// Use for the most detailed level of debugging, such as variable values within loops.
  void finest(Object? message, {Object? error, StackTrace? trace}) {
    logger.finest(message, error, trace);
  }

  /// Logs potentially harmful situations that don't prevent the app from working.
  /// Use for recoverable errors or unexpected but handled conditions.
  void warning(Object? message, {Object? error, StackTrace? trace}) {
    logger.warning(message, error, trace);
  }

  /// Logs serious errors that may prevent parts of the app from working correctly.
  /// Use for unrecoverable errors that require immediate attention.
  void severe(Object? message, {Object? error, StackTrace? trace}) {
    logger.severe(message, error, trace);
  }

  /// Logs critical errors that could crash the app or make it unusable.
  /// Use for the most severe errors that require immediate intervention.
  void shout(Object? message, {Object? error, StackTrace? trace}) {
    logger.shout(message, error, trace);
  }

  Future<void> deleteLogs() async {
    // Clear on the write queue so a queued append can't land between the
    // truncate and the context re-write below.
    await _enqueue(() => logsFile.writeAsString(''));
    logs.shout('Logs deleted');
    addContextInfos();
  }
}
