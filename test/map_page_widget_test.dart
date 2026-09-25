import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtive/core/entities/activity_entity.dart';
import 'package:furtive/core/entities/activity_profile.dart';
import 'package:furtive/core/entities/position_entity.dart';
import 'package:furtive/core/global.dart';
import 'package:furtive/core/map/map_view.dart';
import 'package:furtive/core/widgets/hold_to_confirm_button.dart';
import 'package:furtive/features/activities/bloc/activities_bloc.dart';
import 'package:furtive/features/activities/bloc/activities_event.dart';
import 'package:furtive/features/activities/bloc/activities_state.dart';
import 'package:furtive/features/map/bloc/map_bloc.dart';
import 'package:furtive/features/map/bloc/map_event.dart';
import 'package:furtive/features/map/bloc/map_state.dart';
import 'package:furtive/features/map/pages/map_page.dart';
import 'package:furtive/features/recording/bloc/recording_bloc.dart';
import 'package:furtive/features/recording/bloc/recording_event.dart';
import 'package:furtive/features/recording/bloc/recording_state.dart';
import 'package:furtive/features/share/live_share_cubit.dart';
import 'package:furtive/l10n/app_localizations.dart';

class _Map extends Cubit<MapState> implements MapBloc {
  _Map(super.initialState);
  final events = <MapEvent>[];
  void update(MapState value) => emit(value);
  @override
  void add(MapEvent event) => events.add(event);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Recording extends Cubit<RecordingState> implements RecordingBloc {
  _Recording() : super(const RecordingState());
  final events = <RecordingEvent>[];
  void update(RecordingState value) => emit(value);
  @override
  void add(RecordingEvent event) => events.add(event);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Activities extends Cubit<ActivitiesState> implements ActivitiesBloc {
  _Activities() : super(const ActivitiesState());
  final events = <ActivitiesEvent>[];
  @override
  void add(ActivitiesEvent event) => events.add(event);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sharing extends Cubit<LiveShareState> implements LiveShareCubit {
  _Sharing() : super(const LiveShareState());
  var stopped = 0;
  var cleared = 0;
  void update(LiveShareState value) => emit(value);
  @override
  bool get isConfigured => true;
  @override
  Future<void> stop() async {
    stopped++;
    emit(const LiveShareState());
  }

  @override
  void clearError() => cleared++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Renderer implements MapView {
  final moves = <(PositionEntity, double)>[];
  var builds = 0;
  var disposed = false;
  PositionEntity? centre;
  ActivityEntity? track;
  int? milestoneInterval;
  late VoidCallback gesture;
  @override
  String get name => 'test';
  @override
  double? get currentZoom => 12;
  @override
  void moveTo(PositionEntity centre, double zoom) => moves.add((centre, zoom));
  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  Widget build({
    required String? styleUrl,
    required ActivityEntity? track,
    required PositionEntity? initialCentre,
    required double initialZoom,
    required double maxZoom,
    required bool showUserLocation,
    required VoidCallback onUserGesture,
    bool controlsOnLeft = false,
    int milestoneIntervalKm = 1,
    bool fitTrackBounds = false,
    PositionEntity? userPosition,
    double? deviceHeading,
  }) {
    builds++;
    centre = initialCentre;
    this.track = track;
    milestoneInterval = milestoneIntervalKm;
    gesture = onUserGesture;
    return const SizedBox.expand(key: ValueKey('map-surface'));
  }
}

void main() {
  late _Map map;
  late _Recording recording;
  late _Activities activities;
  late _Sharing sharing;
  late _Renderer renderer;
  final position = PositionEntity(latitude: 45, longitude: -72, elevation: 100);
  final started = DateTime.utc(2026, 9, 4);
  ActivityEntity activity({bool points = false}) => ActivityEntity(
    id: 'run',
    name: 'Morning run',
    description: '',
    createdAt: started,
    startedAt: started,
    stoppedAt: null,
    points: points
        ? [
            ActivityPointEntity(
              position: position,
              time: started,
              status: ActivityPointStatusEntity.active,
            ),
          ]
        : [],
  );

  setUp(() {
    map = _Map(MapState(styleUrl: 'test-style', userLocation: position));
    recording = _Recording();
    activities = _Activities();
    sharing = _Sharing();
    renderer = _Renderer();
  });
  tearDown(() async {
    await map.close();
    await recording.close();
    await activities.close();
    await sharing.close();
  });

  Future<void> mount(WidgetTester tester, {ValueNotifier<int>? tab}) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<MapBloc>.value(value: map),
          BlocProvider<RecordingBloc>.value(value: recording),
          BlocProvider<ActivitiesBloc>.value(value: activities),
          BlocProvider<LiveShareCubit>.value(value: sharing),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MapPage(mapView: renderer, selectedTab: tab),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'initialization waits for configuration then shows a tileless map',
    (tester) async {
      map.update(const MapState(loadingStatus: LoadingStatus.loadingMap));
      await mount(tester);
      expect(map.events.whereType<InitMap>(), hasLength(1));
      expect(find.text('Loading map…'), findsOneWidget);
      expect(find.byKey(const ValueKey('map-surface')), findsNothing);
      map.update(const MapState());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('map-surface')), findsOneWidget);
      expect(find.text('Waiting for GPS'), findsOneWidget);
      expect(renderer.centre, isNull);
      await tester.pumpWidget(const SizedBox());
      expect(renderer.disposed, isTrue);
    },
  );

  testWidgets(
    'Follow centres on the accepted fix and gestures cancel following',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Follow'));
      expect(renderer.moves.single, (position, Global.maxZoom));
      expect(map.events.last, isA<ToggleFollowUser>());
      map.update(map.state.copyWith(isFollowingUser: true));
      await tester.pumpAndSettle();
      expect(find.text('Following'), findsOneWidget);
      renderer.gesture();
      expect(map.events.last, isA<StopFollowingUser>());
      final next = PositionEntity(
        latitude: 45.001,
        longitude: -72,
        elevation: 100,
      );
      map.update(map.state.copyWith(userLocation: next));
      await tester.pump();
      expect(renderer.moves.last, (next, 12));
    },
  );

  testWidgets(
    'activity picker dispatches the selected type and Start uses current selection',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Walk'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Run'));
      await tester.pumpAndSettle();
      expect(
        (map.events.last as SelectActivityType).activityType,
        ActivityTypeEntity.run,
      );
      map.update(
        map.state.copyWith(selectedActivityType: ActivityTypeEntity.run),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      expect(
        (recording.events.last as StartRecording).activityType,
        ActivityTypeEntity.run,
      );
    },
  );

  testWidgets(
    'recording actions toggle pause and require a sustained hold to stop',
    (tester) async {
      recording.update(RecordingState(activity: activity()));
      await mount(tester);
      await tester.tap(find.text('Pause'));
      expect(recording.events.last, isA<PauseRecording>());
      recording.update(recording.state.copyWith(isPaused: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume'));
      expect(recording.events.whereType<PauseRecording>(), hasLength(2));
      final hold = find.byType(HoldToConfirmButton);
      await tester.tap(hold);
      await tester.pump();
      expect(recording.events.whereType<StopRecording>(), isEmpty);
      final gesture = await tester.startGesture(tester.getCenter(hold));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(recording.events.whereType<StopRecording>(), hasLength(1));
    },
  );

  testWidgets(
    'elapsed ticks do not rebuild the map and first recorded point centres it',
    (tester) async {
      recording.update(RecordingState(activity: activity()));
      await mount(tester);
      final builds = renderer.builds;
      recording.update(
        recording.state.copyWith(elapsedTime: const Duration(seconds: 7)),
      );
      await tester.pump();
      expect(renderer.builds, builds);
      recording.update(
        recording.state.copyWith(activity: activity(points: true)),
      );
      await tester.pump();
      expect(renderer.track!.points, hasLength(1));
      expect(renderer.moves.last, (position, Global.maxZoom));
    },
  );

  testWidgets('recording failure remains visible until explicitly dismissed', (
    tester,
  ) async {
    await mount(tester);
    recording.update(
      const RecordingState(error: AppError('database unavailable')),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No activity is currently recording.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(MaterialBanner), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    expect(recording.events.last, isA<ClearRecordingError>());
  });

  testWidgets('map errors and tracking gaps are shown and acknowledged once', (
    tester,
  ) async {
    await mount(tester);
    map.update(
      map.state.copyWith(error: const AppError('Location unavailable')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Location unavailable'), findsOneWidget);
    expect(map.events.last, isA<ClearError>());
    recording.update(const RecordingState(trackingGap: Duration(seconds: 45)));
    await tester.pumpAndSettle();
    expect(recording.events.last, isA<ClearTrackingGap>());
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets(
    'live share password can be revealed and cancelling does not start sharing',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
      await tester.enterText(find.byType(TextField), 'test password');
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isFalse,
      );
      await tester.tap(find.byTooltip('Hide password'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(sharing.state.isActive, isFalse);
    },
  );

  testWidgets(
    'live share distinguishes preparation, disconnection and connection and can stop',
    (tester) async {
      await mount(tester);
      sharing.update(const LiveShareState(status: LiveShareStatus.starting));
      await tester.pump();
      await tester.pump();
      final preparing = find.widgetWithText(FloatingActionButton, 'Preparing…');
      expect(tester.widget<FloatingActionButton>(preparing).onPressed, isNull);
      sharing.update(const LiveShareState(status: LiveShareStatus.active));
      await tester.pumpAndSettle();
      expect(find.text('Reconnecting…'), findsOneWidget);
      sharing.update(
        const LiveShareState(
          status: LiveShareStatus.active,
          connectedRelays: 1,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Live connected'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();
      expect(sharing.stopped, 1);
      expect(find.text('Share'), findsOneWidget);
    },
  );

  testWidgets(
    'stopping from another tab refreshes activities without stealing navigation',
    (tester) async {
      final tab = ValueNotifier(1);
      addTearDown(tab.dispose);
      recording.update(RecordingState(activity: activity()));
      await mount(tester, tab: tab);
      recording.update(const RecordingState());
      await tester.pumpAndSettle();
      expect(activities.events.whereType<FetchActivities>(), hasLength(1));
      expect(find.text('Start'), findsOneWidget);
      expect(find.byType(MapPage), findsOneWidget);
    },
  );
}
