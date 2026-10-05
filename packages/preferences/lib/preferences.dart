/// The application's settings, and the database they live in.
///
/// Settings are read at startup and written when a user changes one. They
/// live in their own database rather than beside the recordings: a module
/// that owns data owns the schema it lives in, and a settings row sharing a
/// file with every GPS fix ever recorded means neither can be migrated,
/// cleared or excluded from a platform backup without reasoning about the
/// other.
library;

export 'src/preferences_entity.dart';
export 'src/preferences_repository.dart';
