import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_view/map_view.dart';
import 'package:geo/geo.dart';
import 'package:maplibre/maplibre.dart' as ml;
import 'package:ui_kit/ui_kit.dart';

void main() {
  final position = PositionEntity(
    latitude: 45,
    longitude: -72,
    elevation: 100,
    accuracy: 8,
    speed: 3,
    heading: 90,
    headingAccuracy: 5,
  );
  late MapLibreMapView view;
  setUp(() => view = MapLibreMapView());
  tearDown(() => view.dispose());

  ml.MapLibreMap build({
    MapTrack? track,
    bool showUserLocation = false,
    PositionEntity? user,
    String? style,
    bool left = false,
    VoidCallback? gesture,
  }) =>
      view.build(
            styleUrl: style,
            track: track,
            initialCentre: position,
            initialZoom: 12,
            maxZoom: 18,
            showUserLocation: showUserLocation,
            userPosition: user,
            deviceHeading: 180,
            controlsOnLeft: left,
            onUserGesture: gesture ?? () {},
          )
          as ml.MapLibreMap;

  test('tileless historical maps never display the current position', () {
    final map = build(user: position);
    expect(map.options.initStyle, '');
    expect(map.options.initZoom, 12);
    expect(map.options.maxZoom, 18);
    expect(map.options.initCenter!.lat, 45);
    expect(map.layers, isEmpty);
    expect(map.children, isEmpty);
    expect(view.name, 'maplibre');
    expect(view.currentZoom, isNull);
    view.moveTo(position, 14);
    view.moveTo(
      PositionEntity(latitude: double.nan, longitude: 0, elevation: 0),
      14,
    );
  });

  test('accepted location supplies both the accuracy disc and travel puck', () {
    final map = build(showUserLocation: true, user: position);
    expect(map.layers.single, isA<ml.PolygonLayer>());
    final marker = (map.children.single as ml.WidgetLayer).markers.single;
    expect(marker.point.lat, 45);
    expect(marker.point.lon, -72);
    expect(marker.rotate, isTrue);
    final puck = marker.child as UserLocationPuck;
    expect(puck.headingDegrees, 90);
    expect(puck.deviceHeading, 180);
    for (final accuracy in <double?>[null, -1, double.nan]) {
      final uncertain = build(
        showUserLocation: true,
        user: PositionEntity(
          latitude: 45,
          longitude: -72,
          elevation: 0,
          accuracy: accuracy,
        ),
      );
      expect(uncertain.layers, isEmpty);
      expect(uncertain.children, hasLength(1));
    }
  });

  test('attribution stays opposite the recording controls', () {
    for (final left in [false, true]) {
      final map = build(style: 'https://example.com/style.json', left: left);
      expect(map.options.initStyle, 'https://example.com/style.json');
      expect(
        (map.children.single as ml.SourceAttribution).alignment,
        left ? Alignment.bottomRight : Alignment.bottomLeft,
      );
    }
  });

  test('only user camera movement cancels following', () {
    var gestures = 0;
    final map = build(gesture: () => gestures++);
    for (final reason in ml.CameraChangeReason.values) {
      map.onEvent!(ml.MapEventStartMoveCamera(reason: reason));
    }
    expect(gestures, 1);
  });

  test('each recorded style gets its own line, drawn its own way', () {
    // Three segments in, three polylines out: solid for what was recorded as
    // movement, the secondary colour for a deliberate pause, dashed for an
    // outage — a solid line across one would assert a path nobody travelled.
    MapTrackSegment segment(MapTrackStyle style, int index) => MapTrackSegment(
      style: style,
      positions: [
        for (var i = 0; i < 2; i++)
          PositionEntity(
            latitude: 45 + (index * 2 + i) * .02,
            longitude: -72,
            elevation: 100,
          ),
      ],
    );
    final track = MapTrack(
      segments: [
        segment(MapTrackStyle.active, 0),
        segment(MapTrackStyle.paused, 1),
        segment(MapTrackStyle.signalLost, 2),
      ],
      milestones: [
        MapMilestone(
          position: PositionEntity(latitude: 45, longitude: -72, elevation: 0),
          label: '1',
        ),
      ],
    );

    final lines = build(track: track).layers.cast<ml.PolylineLayer>().toList();

    expect(lines, hasLength(3));
    expect(lines[0].color, AppColors.primary.background);
    expect(lines[1].color, AppColors.secondary.background);
    expect(lines[0].dashArray, isNull);
    expect(lines[1].dashArray, isNull);
    expect(lines[2].dashArray, [2, 3]);
    expect(lines.every((line) => line.width == 4), isTrue);

    final markers =
        (build(track: track).children.single as ml.WidgetLayer).markers;
    expect((markers.single.child as KmMilestoneChip).label, '1');
  });

  test('a track with no milestones draws no marker layer', () {
    // Zero is a setting a user picks: the route and nothing else.
    final track = MapTrack(
      segments: [
        MapTrackSegment(
          style: MapTrackStyle.active,
          positions: [
            PositionEntity(latitude: 45, longitude: -72, elevation: 0),
            PositionEntity(latitude: 45.1, longitude: -72, elevation: 0),
          ],
        ),
      ],
    );

    expect(build(track: track).children, isEmpty);
  });

  test('a one-position segment has no line to draw', () {
    // Common rather than exotic: every segment is one position long for the
    // first fix after a resume.
    final track = MapTrack(
      segments: [
        MapTrackSegment(
          style: MapTrackStyle.active,
          positions: [
            PositionEntity(latitude: 45, longitude: -72, elevation: 0),
          ],
        ),
      ],
    );

    expect(build(track: track).layers, isEmpty);
  });
}
