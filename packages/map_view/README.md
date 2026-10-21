# map_view

Everything the application needs from a map, and nothing else.

## When to use it

A screen that shows a map builds one through `MapView` and never imports a
rendering library. `MapLibreMapView` is the implementation; the port exists
so a second one can be measured against it before either is deleted.

## Example

```dart
final view = MapLibreMapView();

view.build(
  styleUrl: styleUrl,           // null renders tile-less, on purpose
  track: track,                 // a MapTrack, or null
  initialCentre: position,
  initialZoom: 12,
  maxZoom: 18,
  showUserLocation: true,
  onUserGesture: () => stopFollowing(),
);
```

## It takes a route, not a recording

`MapTrack` is a list of styled segments and a list of numbered markers.
Turning a recording into one — segmenting points by what the recorder was
doing, spacing milestones by distance — belongs to whoever owns the
recording. Two features render this map, so it sits below both, and a shared
UI module may not reach a capability.

The conversion is small and lives in the application: see
`apps/app/lib/shell/map_track_view.dart`.

## Owned and borrowed

Owned: the port, the MapLibre implementation, the accuracy ring, the
milestone chip and the location puck. Borrowed: the theme, from `ui_kit`.

## Guarantees

A segment is drawn by its style: `active` solid, `paused` in the secondary
colour, `signalLost` dashed. A solid line across an outage would assert a
path that was never recorded, and leaving a gap reads as a rendering bug —
dashes say "unknown". A one-position segment draws nothing, which is common
rather than exotic: every segment is one position long for the first fix
after a resume.

The user's position is passed in, never fetched. The renderer's own location
component used to fetch it from a second location engine that bypassed the
quality filter, drawing a position the rest of the application had rejected.

The device heading and the course over ground are different things and are
drawn differently: a phone can point east while its owner walks north.

`onUserGesture` fires only for a hand on the screen, never for a
programmatic move, so a caller can drop follow-mode without fighting itself.

The attribution badge takes the corner the caller's controls do not. It is
legally required to stay visible, and it was covered once already.

## Verification

`test/maplibre_map_view_test.dart` covers the tile-less style, the camera
options, the attribution corner, that only a user gesture cancels following,
the three segment styles and their dashes, a milestone label, a track with
no milestones, and a one-position segment.
