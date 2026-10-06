import 'package:get_it/get_it.dart';
import 'package:furtive/features/activities/bloc/activities_bloc.dart';
import 'package:furtive/features/map/bloc/map_bloc.dart';
import 'package:furtive/features/permissions/bloc/permissions_bloc.dart';
import 'package:furtive/features/recording/bloc/recording_bloc.dart';
import 'package:furtive/features/share/live_share_cubit.dart';
import 'package:recording_session/recording_session.dart';

final getIt = GetIt.instance;

/// The single composition root.
///
/// `getIt` is deliberately confined to this file plus main.dart: everything else
/// takes its dependencies through its constructor (with real defaults, so
/// production call sites stay terse). Before this, datasources reached into the
/// locator from the bottom of the stack, which is what made the blocs
/// untestable — there was no seam anywhere between a bloc and SQLite.
class Locator {
  static void setup() {
    // Blocs are lazy singletons so cross-bloc wiring (MapBloc forwarding fixes
    // to RecordingBloc, a preferences change re-initing the map) reaches the
    // live instance rather than a fresh one.
    // The recording is a capability and the shell owns it: three things
    // watch it, so none of them may. The bloc is one of the three, not its
    // owner — it is the shape widgets rebuild from.
    getIt.registerLazySingleton<RecordingSession>(
      RecordingSession.new,
      dispose: (session) => session.close(),
    );
    getIt.registerLazySingleton<RecordingBloc>(
      () => RecordingBloc(session: getIt<RecordingSession>()),
    );
    getIt.registerLazySingleton<LiveShareCubit>(
      () => LiveShareCubit(recording: getIt<RecordingSession>()),
    );
    getIt.registerLazySingleton<MapBloc>(
      () => MapBloc(recording: getIt<RecordingSession>()),
    );
    getIt.registerLazySingleton<ActivitiesBloc>(ActivitiesBloc.new);
    getIt.registerLazySingleton<PermissionsBloc>(PermissionsBloc.new);
  }
}
