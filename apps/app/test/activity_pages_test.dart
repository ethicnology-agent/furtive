import 'dart:async';

import 'package:diagnostics/diagnostics.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:activities/testing.dart';
import 'package:activities/activities.dart';
import 'package:platform_services/platform_services.dart';
import 'package:furtive/app/locator.dart';
import 'package:map_view/map_view.dart';
import 'package:furtive/features/activities/bloc/activities_bloc.dart';
import 'package:furtive/features/activities/bloc/activities_event.dart';
import 'package:furtive/features/activities/bloc/activities_state.dart';
import 'package:furtive/features/activities/pages/activities_list_page.dart';
import 'package:furtive/features/activities/pages/activity_detail_page.dart';
import 'package:furtive/l10n/app_localizations.dart';
import 'package:geo/geo.dart';
import 'package:ui_kit/ui_kit.dart';

import 'support/fakes.dart';

class _PageBloc extends ActivitiesBloc {
  final events = <ActivitiesEvent>[];
  Object? mutationError;

  void show(ActivitiesState value) => emit(value);

  @override
  void add(ActivitiesEvent event) {
    events.add(event);
    final completion = switch (event) {
      UpdateActivityName(:final completion) => completion,
      DeleteActivity(:final completion) => completion,
      _ => null,
    };
    if (completion != null) {
      if (mutationError != null) {
        completion.completeError(mutationError!);
      } else {
        completion.complete();
      }
    }
  }
}

class _UnavailableActivityRepository extends ActivityRepository {
  @override
  Future<ActivityEntity> fetchSingle(String activityId) async {
    throw StateError('Activity unavailable');
  }
}

class _RecordingMapView implements MapView {
  MapTrack? track;
  PositionEntity? centre;
  bool? fitBounds;
  bool? showLocation;
  bool disposed = false;
  @override
  String get name => 'test map';
  @override
  double? get currentZoom => null;
  @override
  void moveTo(PositionEntity centre, double zoom) {}
  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  Widget build({
    required String? styleUrl,
    required MapTrack? track,
    required PositionEntity? initialCentre,
    required double initialZoom,
    required double maxZoom,
    required bool showUserLocation,
    required VoidCallback onUserGesture,
    bool controlsOnLeft = false,
    bool fitTrackBounds = false,
    PositionEntity? userPosition,
    double? deviceHeading,
    VoidCallback? onStyleLoaded,
  }) {
    this.track = track;
    centre = initialCentre;
    fitBounds = fitTrackBounds;
    showLocation = showUserLocation;
    return const SizedBox.expand(key: Key('recorded-map'));
  }
}

void main() {
  late LocalDatabase db;
  late _PageBloc bloc;
  final start = DateTime.utc(2026, 9, 1, 10);
  final activity = ActivityEntity(
    id: 'run',
    name: 'Morning run',
    description: '',
    createdAt: start,
    startedAt: start,
    stoppedAt: null,
  );

  setUp(() {
    db = inMemoryDatabase();
    LocalDatabase.installSharedForTesting(db);
    bloc = _PageBloc();
  });
  tearDown(() async {
    await bloc.close();
    await getIt.reset();
    await db.close();
  });

  Future<void> pump(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      BlocProvider<ActivitiesBloc>.value(
        value: bloc,
        child: MaterialApp(
          theme: appTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ActivityDetailPage detail({
    Future<String?> Function()? style,
    Future<void> Function(String)? export,
    Future<void> Function(BuildContext, ActivityEntity)? share,
  }) => ActivityDetailPage(
    activity: activity,
    loadMapStyle: style ?? () async => null,
    // Settings have their own database now; without this seam the page would
    // reach for the real file through path_provider, which a widget test has
    // no plugin for.
    loadMilestoneInterval: () async => 1,
    exportActivity: export ?? (_) async {},
    shareActivity: share ?? (_, _) async {},
  );

  /// Rename, export and delete sit behind the overflow menu, so driving one
  /// means opening it first. Share is still an icon of its own.
  Future<void> menuAction(WidgetTester tester, String label) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  /// Whether those three actions are offered at all. False covers both ways
  /// they can be withheld: the menu disabled while a share runs, and the menu
  /// replaced by its own progress while an export runs.
  bool menuOffered(WidgetTester tester) {
    final finder = find.byWidgetPredicate((w) => w is PopupMenuButton);
    if (finder.evaluate().isEmpty) return false;
    return tester.widget<PopupMenuButton<dynamic>>(finder).enabled;
  }

  Future<void> rename(
    WidgetTester tester,
    String name, {
    bool cancel = false,
  }) async {
    await menuAction(tester, 'Rename activity');
    await tester.enterText(find.byType(TextField), name);
    await tester.tap(
      find.widgetWithText(TextButton, cancel ? 'Cancel' : 'Rename'),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty activity offers statistics without an unrelated map', (
    tester,
  ) async {
    await pump(tester, detail());
    expect(find.text('No recorded route'), findsOneWidget);
    await tester.tap(find.text('View Statistics'));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityStatsWidget), findsOneWidget);
    expect(find.text('00m00s'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'recorded route fits all points without requesting live location',
    (tester) async {
      final map = _RecordingMapView();
      final first = PositionEntity(
        latitude: 45,
        longitude: -72,
        elevation: 100,
      );
      final track = activity.copyWith(
        points: [
          ActivityPointEntity(
            position: PositionEntity(
              latitude: double.nan,
              longitude: 0,
              elevation: 0,
            ),
            time: start,
            status: ActivityPointStatusEntity.active,
          ),
          ActivityPointEntity(
            position: first,
            time: start.add(const Duration(seconds: 1)),
            status: ActivityPointStatusEntity.active,
          ),
        ],
      );
      await pump(
        tester,
        ActivityDetailPage(
          activity: track,
          mapView: map,
          loadMapStyle: () async => null,
          loadMilestoneInterval: () async => 50,
        ),
      );
      expect(find.byKey(const Key('recorded-map')), findsOneWidget);
      // The NaN fix above never reaches the renderer: segmenting drops a
      // non-finite coordinate, so the map is handed only what it can draw
      // rather than having to defend itself against the rest.
      expect(map.track!.positions, [first]);
      expect(map.centre, same(first));
      expect(map.fitBounds, isTrue);
      expect(map.showLocation, isFalse);
      // The interval the page loaded is applied before the renderer sees
      // it: at 50 km a track this short earns no marker at all, which is
      // exactly what passing 1 would not have produced.
      expect(map.track!.milestones, isEmpty);
      await tester.pumpWidget(const SizedBox());
      expect(map.disposed, isTrue);
    },
  );

  testWidgets(
    'late style completion after leaving detail does not update disposed state',
    (tester) async {
      final style = Completer<String?>();
      await tester.pumpWidget(
        MaterialApp(
          home: detail(style: () => style.future),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      style.complete(null);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rename cancellation and blank names leave the activity unchanged',
    (tester) async {
      await pump(tester, detail());
      await rename(tester, 'Discarded name', cancel: true);
      await rename(tester, '   ');
      await rename(tester, 'Morning run');
      expect(bloc.events.whereType<UpdateActivityName>(), isEmpty);
      expect(find.text('Morning run'), findsOneWidget);
    },
  );

  testWidgets(
    'successful rename trims the name and shares the updated entity',
    (tester) async {
      ActivityEntity? shared;
      await pump(
        tester,
        detail(
          share: (_, value) async {
            shared = value;
          },
        ),
      );
      await rename(tester, '  Lakeside run  ');
      expect(
        bloc.events.whereType<UpdateActivityName>().single.newName,
        'Lakeside run',
      );
      expect(find.text('Lakeside run'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.share_rounded));
      await tester.pumpAndSettle();
      expect(shared!.name, 'Lakeside run');
      expect(shared!.id, activity.id);
      expect(activity.name, 'Morning run');
    },
  );

  testWidgets('failed rename keeps the old name and shows the failure', (
    tester,
  ) async {
    bloc.mutationError = StateError('Rename rejected');
    await pump(tester, detail());
    await rename(tester, 'New name');
    expect(find.text('Morning run'), findsOneWidget);
    expect(find.textContaining('Rename rejected'), findsOneWidget);
  });

  testWidgets(
    'delete cancellation keeps detail and a failed delete stays retryable',
    (tester) async {
      await pump(tester, detail());
      await menuAction(tester, 'Delete activity');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(bloc.events.whereType<DeleteActivity>(), isEmpty);
      bloc.mutationError = StateError('Delete rejected');
      await menuAction(tester, 'Delete activity');
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityDetailPage), findsOneWidget);
      expect(find.textContaining('Delete rejected'), findsOneWidget);
      expect(bloc.events.whereType<DeleteActivity>().single.activityId, 'run');
    },
  );

  testWidgets('successful delete returns to the list with confirmation', (
    tester,
  ) async {
    await pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => detail())),
            child: const Text('Open activity'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open activity'));
    await tester.pumpAndSettle();
    await menuAction(tester, 'Delete activity');
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityDetailPage), findsNothing);
    expect(find.text('Open activity'), findsOneWidget);
    expect(find.text('Activity deleted successfully'), findsOneWidget);
  });

  testWidgets('deleting offers an undo that puts the activity back', (
    tester,
  ) async {
    // Pushed from a host page, like the one that proves the delete returns
    // to the list: the snackbar is shown after the detail route pops, so it
    // needs a Scaffold underneath to land on.
    await pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => detail())),
            child: const Text('Open activity'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open activity'));
    await tester.pumpAndSettle();
    await menuAction(tester, 'Delete activity');
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(bloc.events.whereType<DeleteActivity>(), hasLength(1));
    expect(find.byType(SnackBarAction), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    // The whole entity, not an id: the rows are gone by now, so an id would
    // have nothing left to look up.
    final restored = bloc.events.whereType<RestoreActivity>().single;
    expect(restored.activity.id, activity.id);
    expect(restored.activity.name, activity.name);
  });

  testWidgets(
    'export excludes concurrent sharing and restores actions on success',
    (tester) async {
      final pending = Completer<void>();
      String? exported;
      await pump(
        tester,
        detail(
          export: (id) {
            exported = id;
            return pending.future;
          },
        ),
      );
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export GPX'));
      // Not pumpAndSettle: the export is still pending, so the progress
      // indicator never settles. Pump far enough for the menu route to
      // finish popping and no further.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(exported, 'run');
      // The menu is gone while the export runs — its own progress stands in
      // its place, so a slow export still shows in the bar.
      expect(menuOffered(tester), isFalse);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.share_rounded),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('No recorded route'), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(menuOffered(tester), isTrue);
      expect(find.byType(SnackBar), findsOneWidget);
    },
  );

  testWidgets(
    'cancelled export is silent while failures are visible and retryable',
    (tester) async {
      var cancelled = true;
      await pump(
        tester,
        detail(
          export: (_) async {
            if (cancelled) throw const FileSaveCancelled();
            throw StateError('Storage unavailable');
          },
        ),
      );
      await menuAction(tester, 'Export GPX');
      expect(find.byType(SnackBar), findsNothing);
      cancelled = false;
      await menuAction(tester, 'Export GPX');
      expect(find.textContaining('Storage unavailable'), findsOneWidget);
      expect(menuOffered(tester), isTrue);
    },
  );

  testWidgets('failed sharing restores export without hiding the activity', (
    tester,
  ) async {
    await pump(
      tester,
      detail(
        share: (_, _) async {
          throw StateError('Share unavailable');
        },
      ),
    );
    await tester.tap(find.byIcon(Icons.share_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('Share unavailable'), findsOneWidget);
    expect(menuOffered(tester), isTrue);
  });

  testWidgets('failed map style still exposes empty route and statistics', (
    tester,
  ) async {
    await pump(
      tester,
      detail(
        style: () async {
          throw StateError('Offline');
        },
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('No recorded route'), findsOneWidget);
    expect(find.text('View Statistics'), findsOneWidget);
  });

  testWidgets(
    'list initial loading, fetch failure and retry have distinct states',
    (tester) async {
      await pump(tester, const ActivitiesListPage());
      expect(bloc.events.whereType<FetchActivities>(), hasLength(1));
      expect(find.text('Retry'), findsOneWidget);
      bloc.show(const ActivitiesState(isLoading: true));
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      bloc.show(ActivitiesState(error: AppError('Database unavailable')));
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Database unavailable'), findsWidgets);
      await tester.tap(find.text('Retry'));
      expect(bloc.events.whereType<FetchActivities>(), hasLength(2));
      expect(bloc.events.whereType<ClearActivitiesFeedback>(), hasLength(1));
    },
  );

  testWidgets(
    'list import displays progress, disables duplicate imports and reports success',
    (tester) async {
      bloc.show(const ActivitiesState(activities: []));
      await pump(
        tester,
        ActivitiesListPage(pickGpx: () async => XFile('/tmp/track.gpx')),
      );
      await tester.tap(find.byIcon(Icons.file_upload_outlined));
      await tester.pumpAndSettle();
      expect(
        bloc.events.whereType<ImportActivityFromGpx>().single.filePath,
        '/tmp/track.gpx',
      );
      bloc.show(
        const ActivitiesState(
          activities: [],
          importStatus: ActivityImportStatus.inProgress,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Importing GPX…'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.file_upload_outlined),
            )
            .onPressed,
        isNull,
      );
      bloc.show(
        const ActivitiesState(
          activities: [],
          importStatus: ActivityImportStatus.success,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Importing GPX…'), findsNothing);
      expect(bloc.events.whereType<ClearActivitiesFeedback>(), hasLength(1));
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.file_upload_outlined),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('cancelled or failed file picker never queues an import', (
    tester,
  ) async {
    bloc.show(const ActivitiesState(activities: []));
    var fail = false;
    await pump(
      tester,
      ActivitiesListPage(
        pickGpx: () async {
          if (fail) throw StateError('Picker unavailable');
          return null;
        },
      ),
    );
    await tester.tap(find.byIcon(Icons.file_upload_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    fail = true;
    await tester.tap(find.byIcon(Icons.file_upload_outlined));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not open the GPX file picker. Try again.'),
      findsOneWidget,
    );
    expect(bloc.events.whereType<ImportActivityFromGpx>(), isEmpty);
  });

  testWidgets(
    'list renders summary statistics and reports an unavailable detail',
    (tester) async {
      bloc.show(
        ActivitiesState(
          activities: [
            ActivitySummary(
              id: 'run',
              name: 'Morning run',
              startedAt: start,
              activeDistanceMeters: 5000,
              activeDuration: const Duration(minutes: 30),
            ),
          ],
        ),
      );
      await pump(
        tester,
        ActivitiesListPage(activities: _UnavailableActivityRepository()),
      );
      expect(find.text('Morning run'), findsOneWidget);
      expect(find.text('5.00 km'), findsOneWidget);
      expect(find.text('30m00s'), findsOneWidget);
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityDetailPage), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    },
  );

  testWidgets('a named activity still says when it happened', (tester) async {
    bloc.show(
      ActivitiesState(
        activities: [
          ActivitySummary(
            id: 'named',
            name: 'Lakeside run',
            startedAt: start,
            activeDistanceMeters: 5000,
            activeDuration: const Duration(minutes: 30),
          ),
          ActivitySummary(
            id: 'unnamed',
            name: 'Track',
            startedAt: start,
            activeDistanceMeters: 5000,
            activeDuration: const Duration(minutes: 30),
          ),
        ],
      ),
    );
    await pump(tester, const ActivitiesListPage());
    final named = find.ancestor(
      of: find.text('Lakeside run'),
      matching: find.byType(ListTile),
    );
    expect(named, findsOneWidget);
    // The name titles the card and the date sits under it. Before, the name
    // replaced the date outright and two identically named activities — a
    // recording and the GPX it was re-imported as — were indistinguishable.
    expect(
      find.descendant(of: named, matching: find.textContaining('Sep 1, 2026')),
      findsOneWidget,
    );
    // The unnamed one is titled by its date and must not print it twice.
    final unnamed = find.byType(ListTile).last;
    expect(
      find.descendant(
        of: unnamed,
        matching: find.textContaining('Sep 1, 2026'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'scrolling near the end requests the next page only when available',
    (tester) async {
      final summaries = List.generate(
        20,
        (index) => ActivitySummary(
          id: '$index',
          name: index == 0 ? 'Track' : 'Run $index',
          startedAt: start,
          activeDistanceMeters: 1000,
          activeDuration: const Duration(minutes: 6),
        ),
      );
      bloc.show(ActivitiesState(activities: summaries));
      await pump(tester, const ActivitiesListPage());
      expect(find.text('Track'), findsNothing);
      // Index 0 carries the sentinel name, so its card is titled by its
      // date. Every other card now shows its date too, under its name, so
      // the date is no longer unique on the screen — assert where it is
      // rather than how often it appears.
      expect(
        find.descendant(
          of: find.byType(ListTile).first,
          matching: find.textContaining('Sep 1, 2026'),
        ),
        findsOneWidget,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(bloc.events.whereType<FetchMoreActivities>(), isNotEmpty);
      final count = bloc.events.whereType<FetchMoreActivities>().length;
      bloc.show(ActivitiesState(activities: summaries, isLoadingMore: true));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      expect(bloc.events.whereType<FetchMoreActivities>(), hasLength(count));
      bloc.show(ActivitiesState(activities: summaries, hasMore: false));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(bloc.events.whereType<FetchMoreActivities>(), hasLength(count));
    },
  );
}
