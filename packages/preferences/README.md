# preferences

The application's settings, and the database they live in.

## When to use it

Read settings at startup and whenever a screen shows or changes one. Do not
cache them elsewhere: the store is the single answer to what a user chose.

## Example

```dart
final preferences = PreferencesRepository();
final settings = await preferences.fetch();

await preferences.store(settings.copyWith(mapTilesEnabled: false));
```

## Owned and borrowed

Owned: `preferences.sqlite` in the documents directory, its single row, and
the defaults a never-written store reports. Nothing is borrowed.

The production constructor shares one connection per process: settings are
read from several places at startup and the file is tiny, so a connection
per caller would buy no isolation anyone wants. `PreferencesRepository.
inMemory()` gives a test its own, and `close()` releases it.

## Why its own database

Until furtive 1.4 the settings were a row in the recording database, beside
every GPS fix. A module that owns data owns the schema it lives in, and that
arrangement meant neither could be migrated, cleared or excluded from a
platform backup without reasoning about the other.

The schema therefore starts at version 1 even though the settings are older.
Rows that predate it are carried over once by the application, which is the
only component allowed to know both stores.

## Guarantees and failures

Reading never writes. A store that has never been written reports the
defaults and stays empty, which is what lets the application tell a fresh
install from one whose settings arrived with an upgrade.

`adoptIfEmpty` is refusable by design: it takes settings over only when
nothing has ever been stored, and returns whether it did. Running it twice,
or after a user has changed anything, cannot roll their choice back.

Nothing here swallows a storage error — a failed write throws, because a
setting that silently did not land is a setting the screen will keep
displaying as if it had.

## Verification

`test/preferences_test.dart` covers the defaults of an untouched store, that
reading does not write, a full round trip of every field, and the three
`adoptIfEmpty` cases: an empty store, one a user has written, and a second
run after a handover.
