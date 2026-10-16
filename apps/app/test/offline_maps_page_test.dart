import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtive/features/offline_maps/offline_ledger.dart';
import 'package:furtive/features/offline_maps/offline_maps_cubit.dart';
import 'package:furtive/features/offline_maps/offline_maps_page.dart';
import 'package:furtive/l10n/app_localizations.dart';
import 'package:geo/geo.dart';
import 'package:map_view/map_view.dart';
import 'package:ui_kit/ui_kit.dart';

/// The screen owns none of the work, so the cubit is the whole seam: every
/// test here drives the page by the state it is handed and reads back what
/// it asked the cubit to do.
class _FakeCubit extends OfflineMapsCubit {
  final calls = <String>[];
  final downloads = <Map<String, Object?>>[];
  Set<int> busyRegions = const {};

  void show(OfflineMapsState value) => emit(value);

  @override
  Future<void> open() async => calls.add('open');

  @override
  Future<void> refresh() async => calls.add('refresh');

  @override
  Future<void> download({
    required String styleUrl,
    required GeoBounds bounds,
    required double minZoom,
    required double maxZoom,
    required String name,
    required String key,
  }) async {
    downloads.add({
      'styleUrl': styleUrl,
      'bounds': bounds,
      'minZoom': minZoom,
      'maxZoom': maxZoom,
      'name': name,
      'key': key,
    });
  }

  @override
  Future<void> clearCache() async => calls.add('clearCache');

  @override
  Future<void> deleteArea(List<int> regionIds) async =>
      calls.add('delete:${regionIds.join(",")}');

  @override
  bool isDownloadingInto(int id) => busyRegions.contains(id);

  @override
  void failureReported() {
    calls.add('failureReported');
    super.failureReported();
  }
}

OfflineProgress _progress({
  int done = 10,
  int total = 100,
  int bytes = 2 * 1024 * 1024,
  bool estimate = false,
  bool complete = false,
  int? regionId,
}) => OfflineProgress(
  tilesDone: done,
  tilesTotal: total,
  bytes: bytes,
  isEstimate: estimate,
  isComplete: complete,
  regionId: regionId,
);

void main() {
  late _FakeCubit cubit;

  setUp(() => cubit = _FakeCubit());
  tearDown(() => cubit.close());

  Future<void> pump(
    WidgetTester tester, {
    Future<String?> Function()? style,
    PositionEntity? Function()? position,
  }) async {
    // Tall enough for the whole screen to lay out: it is a list of five
    // sections, and the last of them is the one that says what is kept.
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      BlocProvider<OfflineMapsCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: appTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OfflineMapsPage(
            styleUrl: style ?? () async => 'https://tiles.example/style.json',
            currentPosition: position ?? () => null,
          ),
        ),
      ),
    );
    // Not pumpAndSettle: the page opens on its loading state, whose spinner
    // never settles. Each test settles once it has handed over a state.
    await tester.pump();
  }

  const idle = OfflineMapsState(loading: false, storageBytes: 1048576);

  testWidgets('the store is opened once, and a spinner stands in until it is', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(cubit.calls, ['open']);
  });

  testWidgets('a device without offline support says so instead of offering', (
    tester,
  ) async {
    await pump(tester);
    cubit.show(const OfflineMapsState(loading: false, supported: false));
    await tester.pumpAndSettle();
    expect(
      find.text('Offline areas are not available on this device'),
      findsOneWidget,
    );
    // None of the controls exist to be pressed.
    expect(find.widgetWithText(ElevatedButton, 'Download'), findsNothing);
  });

  testWidgets('an empty store offers both ways in and keeps nothing', (
    tester,
  ) async {
    await pump(tester);
    cubit.show(idle);
    await tester.pumpAndSettle();
    expect(find.text('Keep the area around me'), findsOneWidget);
    expect(find.text('Keep a country'), findsOneWidget);
    expect(find.text('Radius: 10 km'), findsOneWidget);
    expect(find.text('No areas kept yet'), findsOneWidget);
    expect(find.text('Map storage'), findsOneWidget);
    expect(find.text('1.0 MB on this device'), findsOneWidget);
  });

  testWidgets('asking without a fix reports it rather than downloading', (
    tester,
  ) async {
    await pump(tester);
    cubit.show(idle);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Download').first);
    await tester.pumpAndSettle();
    expect(find.text('No position yet — wait for GPS'), findsOneWidget);
    expect(cubit.downloads, isEmpty);
  });

  testWidgets('a radius download carries the rectangle, name and identity', (
    tester,
  ) async {
    await pump(
      tester,
      position: () =>
          PositionEntity(latitude: 45.5, longitude: -73.6, elevation: 20),
    );
    cubit.show(idle);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Download').first);
    await tester.pumpAndSettle();
    final sent = cubit.downloads.single;
    expect(sent['name'], '10 km');
    expect(sent['minZoom'], 10.0);
    expect(sent['maxZoom'], 15.0);
    final bounds = sent['bounds']! as GeoBounds;
    expect(bounds.north, greaterThan(bounds.south));
    expect(bounds.east, greaterThan(bounds.west));
    // Rounded so that asking again produces the same string: that is what
    // lets a second attempt be recognised as the same area.
    expect(sent['key'], startsWith('45.500,-73.600@10/10.0-15.0@'));
    // The style is part of the identity but never written down in full —
    // the URL carries the API key.
    expect(sent['key'], isNot(contains('tiles.example')));
  });

  testWidgets('a build with tiles off has nothing to keep', (tester) async {
    await pump(
      tester,
      style: () async => null,
      position: () =>
          PositionEntity(latitude: 45.5, longitude: -73.6, elevation: 20),
    );
    cubit.show(idle);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Download').first);
    await tester.pumpAndSettle();
    expect(
      find.text('Tiles are off, so there is nothing to keep'),
      findsOneWidget,
    );
    expect(cubit.downloads, isEmpty);
  });

  testWidgets('a style that cannot be resolved is a failed download', (
    tester,
  ) async {
    await pump(
      tester,
      style: () async => throw StateError('offline'),
      position: () =>
          PositionEntity(latitude: 45.5, longitude: -73.6, elevation: 20),
    );
    cubit.show(idle);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Download').first);
    await tester.pumpAndSettle();
    expect(find.text('Download failed'), findsOneWidget);
    expect(cubit.downloads, isEmpty);
  });

  testWidgets('a running download is named once, above both cards', (
    tester,
  ) async {
    await pump(tester);
    cubit.show(
      idle.copyWith(
        download: OfflineDownload(name: 'France', progress: _progress()),
      ),
    );
    await tester.pumpAndSettle();
    // Its own card, not inside the radius card — which would have labelled a
    // country download "keep the area around me".
    expect(find.text('France'), findsOneWidget);
    expect(find.text('10 of 100 tiles · 2.0 MB'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      closeTo(0.1, 1e-9),
    );
  });

  testWidgets('nothing else can be asked for while one download runs', (
    tester,
  ) async {
    await pump(tester);
    cubit.show(
      idle.copyWith(
        download: OfflineDownload(name: '10 km', progress: _progress()),
      ),
    );
    await tester.pumpAndSettle();
    for (final button in tester.widgetList<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Download'),
    )) {
      expect(button.onPressed, isNull);
    }
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Clear cache'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('clearing the cache leaves the kept areas alone', (tester) async {
    await pump(tester);
    cubit.show(idle);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Clear cache'));
    await tester.pumpAndSettle();
    expect(cubit.calls, contains('clearCache'));
  });

  testWidgets('a kept area reports what it cost and can be deleted', (
    tester,
  ) async {
    await pump(tester);
    cubit.show(
      idle.copyWith(
        areas: const [OfflineArea(id: 7, name: '10 km', key: 'a')],
        costs: const {
          'a': OfflineAreaCost(tiles: 1213, bytes: 8 * 1024 * 1024),
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('10 km'), findsOneWidget);
    expect(find.text('8.0 MB · 1213 tiles'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(cubit.calls, contains('delete:7'));
  });

  testWidgets('an unfinished area says how far it got', (tester) async {
    await pump(tester);
    cubit.show(
      idle.copyWith(
        areas: const [OfflineArea(id: 1, name: '50 km', key: 'b')],
        costs: const {
          'b': OfflineAreaCost(
            tiles: 1940,
            bytes: 17 * 1024 * 1024,
            expected: 18935,
            complete: false,
          ),
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('10% · 17.0 MB · 1940 tiles'), findsOneWidget);
  });

  testWidgets('an unfinished area whose total was never known says only that', (
    tester,
  ) async {
    await pump(tester);
    cubit.show(
      idle.copyWith(
        areas: const [OfflineArea(id: 1, name: '50 km', key: 'b')],
        costs: const {
          'b': OfflineAreaCost(
            tiles: 500,
            bytes: 4 * 1024 * 1024,
            complete: false,
          ),
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('4.0 MB · 500 tiles · unfinished'), findsOneWidget);
  });

  testWidgets('an area kept by a build that recorded nothing shows no cost', (
    tester,
  ) async {
    await pump(tester);
    cubit.show(
      idle.copyWith(
        areas: const [OfflineArea(id: 4, name: '', key: '')],
      ),
    );
    await tester.pumpAndSettle();
    // No name either: the id stands in rather than an empty row.
    expect(find.text('#4'), findsOneWidget);
    expect(find.textContaining('MB ·'), findsNothing);
  });

  testWidgets('the region being written into cannot be deleted', (
    tester,
  ) async {
    await pump(tester);
    cubit.busyRegions = const {9};
    cubit.show(
      idle.copyWith(
        areas: const [OfflineArea(id: 9, name: '10 km', key: 'c')],
        download: OfflineDownload(
          name: '10 km',
          progress: _progress(regionId: 9),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.delete_outline_rounded),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('several attempts at one area are a single row', (tester) async {
    await pump(tester);
    cubit.show(
      idle.copyWith(
        areas: const [
          OfflineArea(id: 1, name: '50 km', key: 'same'),
          OfflineArea(id: 2, name: '50 km', key: 'same'),
        ],
        costs: const {'same': OfflineAreaCost(tiles: 10, bytes: 1024)},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('50 km'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    // Deleting the row removes every region holding it, not just one.
    expect(cubit.calls, contains('delete:1,2'));
  });

  testWidgets('a failure is reported once and then cleared', (tester) async {
    await pump(tester);
    cubit.show(idle);
    await tester.pumpAndSettle();
    cubit.show(idle.copyWith(failed: true));
    await tester.pumpAndSettle();
    expect(find.text('Download failed'), findsOneWidget);
    expect(cubit.calls, contains('failureReported'));
  });

  testWidgets('the radius moves in tens', (tester) async {
    await pump(tester);
    cubit.show(idle);
    await tester.pumpAndSettle();
    final slider = tester.getRect(find.byType(Slider));
    await tester.tapAt(Offset(slider.right - 1, slider.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('Radius: 50 km'), findsOneWidget);
  });

  testWidgets('choosing a country states its exact cost before downloading', (
    tester,
  ) async {
    await pump(tester);
    cubit.show(idle);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Choose a country'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Luxem');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Luxembourg').last);
    await tester.pumpAndSettle();
    expect(find.text('Luxembourg'), findsOneWidget);
    // Exact, not an estimate: the count is geometry, so it is the same
    // number every time and the same one the device reported.
    expect(find.text('7217 tiles'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Download').last);
    await tester.pumpAndSettle();
    final sent = cubit.downloads.single;
    expect(sent['name'], 'Luxembourg');
    expect(sent['key'], startsWith('country:LU/10.0-15.0@'));
  });
}
