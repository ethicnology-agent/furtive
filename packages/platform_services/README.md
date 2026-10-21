# platform_services

What the application has to ask the host operating system for.

## When to use it

When something cannot be done in Dart: a platform channel, or a directory
whose meaning only the OS knows. Four facades, gathered because they share
that contract rather than because they are alike.

## Example

```dart
await BackupExclusionFacade().excludeFromBackup([databasePath, logPath]);
await LockScreenFacade().setShowWhenLocked(showOnLockScreen);
final exit = await ProcessExitFacade().lastExitReason();
await FileSystemFacade.purgeStaleTempFiles();
```

## Owned and borrowed

Owned: the temporary files it writes for an export or a share, and the purge
that removes yesterday's. Borrowed: everything else — the backup flag, the
lock-screen attribute and the exit reason all belong to the OS.

## Guarantees

**Each is a no-op where the question does not apply**, so a caller never has
to ask which platform it is on. Backup exclusion is iOS-only, because
Android opts the whole app out in its manifest and iOS has no equivalent —
without it a tracker that promises no cloud would still ship its GPS history
to iCloud. The lock-screen attribute is Android-only. Neither throws.

A share or an export hands a file to another application, which may still be
reading it when control returns, so the file it just wrote is never deleted
immediately — the purge removes the *previous* ones, and the share-card and
GPX prefixes are deliberately distinct so purging one cannot take the other
out from under a reader.

## Verification

`test/file_system_facade_test.dart` covers the temp-file purge against a
substituted directory, including that a location-bearing export is not left
behind and that the two prefixes do not purge each other.
