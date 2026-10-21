# basemap

Which basemap style the map should load, in the reader's language, or none
at all.

## When to use it

Call it when the map needs a style, and render whatever comes back —
including null.

## Example

```dart
final styleUrl = await GetMapStyleUrlUseCase().call();
// null → draw the track on a blank canvas.
```

## Owned and borrowed

Owned: the style URL, the label language derived from the UI locale and
narrowed to what the tile host actually serves, and the reachability check.
Borrowed: the settings, read through `preferences`; the user's choice about
tiles is theirs, not this module's.

`package:basemap/testing.dart` exposes the remote datasource so a test can
answer for the tile host instead of reaching it.

## Guarantees

**Null is an answer, not a failure.** A build compiled without a tile key
renders a functional, tileless map — record an activity, see the track on a
blank canvas — and a user who has turned tiles off gets exactly the same
thing from a build that has a key. Every tile request discloses the viewport,
and therefore an approximation of where someone is and, through a recorded
activity, where they have been, to whoever serves it.

The style is fetched and validated in Dart before the map is handed it.
That is not caching: maplibre emits no style-load-failure event, so an
expired key or a captive portal would otherwise leave a blank map with
nothing able to tell it apart from the deliberate tileless one.

The map label language follows the UI locale. There is no second language
setting; two were redundant.

## Verification

`test/map_remote_data_source_test.dart` covers the tileless answers — no key
and tiles disabled — the five style flavours, the locale narrowing, and the
validation that refuses an unreachable style.
