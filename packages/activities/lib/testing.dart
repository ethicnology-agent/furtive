/// The seam tests drive this module through.
///
/// Production code must not import this library: it exposes the database and
/// the row-level datasource, which exist so a test can seed a recording and
/// drive the windows measured in hours without waiting them out. What a
/// screen needs is in `package:activities/activities.dart`.
library;

export 'src/activities_table.dart';
export 'src/activity_local_data_source.dart';
export 'src/activity_model.dart';
export 'src/activity_points_table.dart';
export 'src/local_database.dart';
export 'src/preferences_table.dart';
