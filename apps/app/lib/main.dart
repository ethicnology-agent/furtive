import 'dart:async';
import 'package:diagnostics/diagnostics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:platform_services/platform_services.dart';
import 'package:furtive/app/global.dart';
import 'package:furtive/app/legacy_preferences.dart';
import 'package:furtive/app/locale_cubit.dart';
import 'package:furtive/features/map/bloc/map_bloc.dart';
import 'package:furtive/features/activities/bloc/activities_bloc.dart';
import 'package:furtive/features/permissions/bloc/permissions_bloc.dart';
import 'package:furtive/app/startup_gate.dart';
import 'package:furtive/app/recording_bloc.dart';
import 'package:furtive/features/share/live_share_cubit.dart';
import 'package:furtive/l10n/app_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:preferences/preferences.dart';
import 'package:ui_kit/ui_kit.dart';
import 'app/locator.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // Load intl date-format symbols for every locale we ship. Without this,
      // DateFormat.yMd('zh').format(...) throws LocaleDataException for any
      // non-en locale.
      await initializeDateFormatting();
      await Global.init();

      final appDir = await getApplicationDocumentsDirectory();
      logs = MyLogs.init(directory: appDir, context: Global.diagnosticContext);
      await logs.ensureLogsExist();

      // Diagnostic-only: log why the previous process instance disappeared
      // (see docs/AUDIT-2026-07.md §1.2 [P2-e]). Cannot recover a lost recording,
      // but turns "my run died for no reason" reports into something
      // diagnosable — a genuine OS/OEM kill (LOW_MEMORY, SIGNALED, FREEZER,
      // ANR) is persisted as a WARNING; anything else (user-initiated exit,
      // clean shutdown) is left as routine INFO, unrecorded on disk.
      unawaited(
        ProcessExitFacade().lastExitReason().then((exit) {
          if (exit == null) return;
          if (exit.isUnexpectedKill) {
            logs.warning('Previous process exit: $exit');
          } else {
            logs.info('Previous process exit: $exit');
          }
        }),
      );

      // Best-effort: purge any share-card PNG / GPX export left over from a
      // previous session so a one-off sharer doesn't keep a location-bearing
      // temp file sitting around indefinitely (each call site also purges
      // its own leftovers, but only on its NEXT invocation — see
      // FileSystemFacade.purgeStaleTempFiles).
      unawaited(FileSystemFacade.purgeStaleTempFiles());

      // Register DB + blocs. LocaleCubit is registered separately below
      // because its initial state requires a DB read first.
      Locator.setup();

      // One-time handover: until 1.4 the settings lived in the recording
      // database, beside every GPS fix. They have their own store now, and
      // this is the only place that knows both.
      //
      // Offered, not forced: adoptIfEmpty refuses once anything has been
      // stored, so a second launch — or a user who has since changed a
      // setting — cannot be overwritten by a stale row. Failure is
      // survivable rather than silent: the new store falls back to its
      // defaults, so the worst case is the onboarding wizard showing again,
      // not a lost recording.
      try {
        final carried = await const LegacyPreferences().read();
        if (carried != null &&
            await PreferencesRepository().adoptIfEmpty(carried)) {
          logs.config('Preferences carried over from the recording database');
        }
      } catch (e, st) {
        logs.severe('Preferences handover failed', error: e, trace: st);
      }

      // Read the stored locale override so LocaleCubit is correct on frame 1.
      // On first launch the row doesn't exist yet (beforeOpen runs lazily on
      // first query), so fetch() may throw — fall back to system locale.
      Locale? storedLocale;
      var showOnLockScreen = true;
      try {
        final prefs = await PreferencesRepository().fetch();
        if (prefs.uiLocale != null) {
          storedLocale = parseLocaleTag(prefs.uiLocale!);
        }
        showOnLockScreen = prefs.showOnLockScreen;
      } catch (e, st) {
        logs.warning('Failed to read locale preference', error: e, trace: st);
      }
      getIt.registerSingleton<LocaleCubit>(LocaleCubit(storedLocale));

      // Android only (no-op elsewhere): apply the stored lock-screen
      // visibility preference. The manifest's showWhenLocked="true" is only
      // the cold-start default, matching this preference's own true
      // default — this call only has an observable effect once the user has
      // actually turned the preference off. See docs/AUDIT-2026-07.md §5.
      unawaited(LockScreenFacade().setShowWhenLocked(showOnLockScreen));

      // iOS only (no-op elsewhere): exclude the SQLite DB and the log file
      // from the iCloud/iTunes backup, matching Android's manifest-level
      // opt-out. Placed after the GetPreferencesUseCase() call above, which
      // just forced LazyDatabase to open/create app.sqlite — excluding a
      // path before the file exists would silently no-op and never be
      // retried. See docs/AUDIT-2026-07.md §5 and BackupExclusionFacade.
      unawaited(
        BackupExclusionFacade().excludeFromBackup([
          p.join(appDir.path, 'app.sqlite'),
          p.join(appDir.path, 'app.sqlite-wal'),
          p.join(appDir.path, 'app.sqlite-shm'),
          p.join(appDir.path, 'app.sqlite-journal'),
          // The settings database is small and holds no location, but it
          // does hold what a user chose; the same "no cloud" posture that
          // excludes the recordings excludes it.
          p.join(appDir.path, 'preferences.sqlite'),
          p.join(appDir.path, 'preferences.sqlite-wal'),
          p.join(appDir.path, 'preferences.sqlite-shm'),
          p.join(appDir.path, 'preferences.sqlite-journal'),
          logs.logsFile.path,
        ]),
      );

      FlutterError.onError = (FlutterErrorDetails details) {
        logs.severe(
          'Flutter error',
          error: details.exception,
          trace: details.stack,
        );
      };

      runApp(const MyApp());
    },
    (error, stack) {
      // logs is assigned partway through startup; if something before that
      // throws, calling logs here would raise LateInitializationError and mask
      // the real error. Fall back to debugPrint.
      try {
        logs.severe(error.toString(), error: error, trace: stack);
      } catch (_) {
        debugPrint('Unhandled startup error: $error\n$stack');
      }
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // .value because the locator owns the bloc lifetimes — BlocProvider
        // must not close them on widget disposal.
        BlocProvider<LocaleCubit>.value(value: getIt<LocaleCubit>()),
        BlocProvider<RecordingBloc>.value(value: getIt<RecordingBloc>()),
        BlocProvider<LiveShareCubit>.value(value: getIt<LiveShareCubit>()),
        BlocProvider<MapBloc>.value(value: getIt<MapBloc>()),
        BlocProvider<ActivitiesBloc>.value(value: getIt<ActivitiesBloc>()),
        BlocProvider<PermissionsBloc>.value(value: getIt<PermissionsBloc>()),
      ],
      child: BlocBuilder<LocaleCubit, Locale?>(
        builder: (context, locale) => MaterialApp(
          // onGenerateTitle ensures the title in the OS task switcher is
          // localised every time the locale changes.
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          theme: appTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: const StartupGate(),
        ),
      ),
    );
  }
}
