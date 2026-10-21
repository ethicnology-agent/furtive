# diagnostics

Persistent, sanitized diagnostic logging. One rotating TSV file is the only
diagnostic surface, so a session can be reconstructed from the in-app Logs
page without a computer attached.

## When to use it

Call it from anywhere that needs to record what happened. Do not build a
second logging path: a record written elsewhere does not reach the Logs page
and does not get sanitized or trimmed.

## Example

```dart
logs = MyLogs.init(directory: appDir, context: Global.diagnosticContext);
await logs.ensureLogsExist();

logs.info('Recording started');
logs.severe('Export failed', error: error, trace: trace);
```

## Owned and borrowed

Owned: the log file inside the directory given at construction, its 1 MB cap,
the trimming that keeps the most recent ~75% of it, and the serialization of
every mutation so concurrent appends cannot tear a record.

Borrowed: the directory. The caller chooses it and owns its lifetime.
`Directory.current` is the default, which is what a test gets.

## The environment header

`context` supplies the lines written at the top of a fresh log file and again
after it is cleared. This module does not read build or device facts itself:
doing so would make it depend on platform plugins, and would move the
decision of what is safe to record away from whoever knows what each field
contains. The default supplies nothing.

**Keep personal data out of what you pass.** The application deliberately
omits the user-assigned iOS device name for this reason.

Logging is fire-and-forget. `flush()` resolves once every record logged
before the call has reached the file, which is what a test — or an export —
needs before reading it back.

## Guarantees and failures

No method throws on a failed write. Each queued operation swallows its own
error so one failed append cannot poison the chain and silently drop every
later line. `readLogs` is the exception: it logs and rethrows, because a
caller displaying logs needs to know it has nothing to display.

Every field of every record passes through the logger's sanitizer before it
reaches disk. In debug builds, level and message are also mirrored to the
console; the file is written in every build.

## Verification

`test/logs_test.dart` covers the header contract in both directions, that an
existing log is not re-headed, and that an oversized file is trimmed to whole
records. The Logs page that reads the file is tested in the
application, in `test/logs_page_test.dart`.
