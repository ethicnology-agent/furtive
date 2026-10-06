# Furtive

The Android and iOS application: the shell that composes the journeys into
something a user opens.

Building and releasing are documented at the repository root. This file is
about what lives where inside `lib/`, because the answer stopped being
obvious once the capabilities moved out to `packages/`.

## What a shell owns

Wiring, and nothing a module could own instead. If something here could be
stated without reference to this application — a distance, a schema, a
widget with no domain in it — it belongs in a module, and the boundary
checker will not catch that for you.

Roles and allowed dependencies are declared in `module.yaml` and enforced by
`melos run boundaries`.

## Layout

```
lib/
  app/        composition: what the application opens on, how it is wired
  features/   the journeys, one directory each
  views/      the seam between a module's domain type and a UI module
  labels/     a module's values, in the reader's language
  l10n/       the ARB files and their generated localisations
  main.dart
```

**`features/` is flat and the directories do not see each other.** There is
no feature-to-feature import in this application and there should not be a
first one. When two journeys need the same thing, the thing is not a
feature: it is a view, a label, a module, or a slot the shell fills.

**A slot is how a journey shows something it does not own.** The map takes a
`shareControlBuilder`; the onboarding wizard takes a `permissionsStep` and
an `onFinished`. In each case the page keeps its layout and the shell
decides what goes in it, which is why neither page imports the other's
feature.

**`views/` exists because a UI module may not reach a business one.**
`ui_kit` knows four numbers and eight strings; `map_view` knows polylines
and numbered markers. Turning an `ActivityEntity` into either is this
application's job, and the extensions that do it live here.

**`labels/` is where a module's value meets the reader's language.** Modules
hold no strings — the theme names, the stats panel's labels and the UI
language list are the application's wording for someone else's values.
Wording used by one journey stays in that journey.

## Where the exceptions are, and why

`Global` is read by two features for the build version. The recording
adapter is read by one for the bloc that renders a session. Both are
application-wide by nature and neither has a module to go to; they are the
only two places a feature points back at `app/`.

`legacy_preferences.dart` is the one-time handover out of the pre-1.4
storage layout. It goes with the table it reads, in the release after 1.4 —
dropping that table is destructive and belongs to a later release than the
one that stopped writing to it.

## Verification

`melos run verify` runs everything; from this directory, `fvm flutter test`
runs this application's suite alone. The golden tests under
`test/share_card_golden_test.dart` are generated on Linux and the CI is
their oracle — they fail on macOS for font rendering, and that is expected
rather than a regression to chase locally.
