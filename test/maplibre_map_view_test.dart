import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtive/core/entities/activity_entity.dart';
import 'package:furtive/core/entities/position_entity.dart';
import 'package:furtive/core/map/maplibre_map_view.dart';
import 'package:furtive/core/theme.dart';
import 'package:furtive/core/widgets/km_milestone_chip.dart';
import 'package:furtive/core/widgets/user_location_puck.dart';
import 'package:maplibre/maplibre.dart' as ml;

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
    ActivityEntity? track,
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

  test(
    'active, paused and unknown paths keep distinct styles and milestones',
    () {
      final start = DateTime.utc(2026, 9, 4);
      final points = <ActivityPointEntity>[];
      for (final status in ActivityPointStatusEntity.values) {
        for (var i = 0; i < 2; i++) {
          points.add(
            ActivityPointEntity(
              position: PositionEntity(
                latitude: 45 + points.length * .02,
                longitude: -72,
                elevation: 100,
              ),
              time: start.add(Duration(minutes: points.length * 10)),
              status: status,
            ),
          );
        }
      }
      final track = ActivityEntity(
        id: 'route',
        name: 'Route',
        description: '',
        createdAt: start,
        startedAt: start,
        stoppedAt: null,
        points: points,
      );
      final map = build(track: track);
      final lines = map.layers.cast<ml.PolylineLayer>().toList();
      expect(lines, hasLength(3));
      expect(lines[0].color, AppColors.primary.background);
      expect(lines[1].color, AppColors.secondary.background);
      expect(lines[0].dashArray, isNull);
      expect(lines[1].dashArray, isNull);
      expect(lines[2].dashArray, [2, 3]);
      expect(lines.every((line) => line.width == 4), isTrue);
      final markers = (map.children.single as ml.WidgetLayer).markers;
      expect(markers, isNotEmpty);
      expect((markers.first.child as KmMilestoneChip).label, '1');
      expect(
        build(track: track.copyWith(points: [points.first])).layers,
        isEmpty,
      );
    },
  );
}
